; fn_proc.s - the PROC (proceed) interrupt for the native 0x7f endpoint (Atari)
;
; The FujiNet drives the open-drain PROC line to the Atari's PIA (CA1); a falling edge sets the PIA's
; CA1 flag, and with the interrupt enabled (PACTL bit 0) the OS IRQ routine calls the handler at VPRCED
; ($0202). This module installs a handler that counts the interrupt, latches a "pending" flag the
; application can test and clear, and chains to whatever handler was there before.
;
; Opt-in, and nothing links into a program that does not call fn_atari_proc_enable. The library's
; normal exchange does not need it: it polls with P, which stays correct with or without PROC.
;
; The handler runs from the OS IRQ routine, which has pushed A and nothing else: only A is used, and
; the handler leaves through the previous VPRCED handler (the OS default ends with PLA, RTI).
; The OS SIO routine writes PACTL to switch the cassette motor, which clears the interrupt enable: a
; program that uses the cassette must call fn_atari_proc_enable again afterwards.

        .export _fn_atari_proc_enable, _fn_atari_proc_disable
        .export _fn_atari_proc_pending, _fn_atari_proc_count
        .export proc_isr
        .import _fn_atari_proc_notify

FN_OK = $00

PORTA  = $D300          ; reading it clears the PIA's CA1 flag
PACTL  = $D302          ; bit 0: CA1 (PROC) interrupt enable, bit 1: edge (0 = falling), bit 7: CA1 flag
VPRCED = $0202          ; the OS vector for the PROCEED interrupt

        .bss
proc_active:    .res 1
proc_pending:   .res 1
proc_count:     .res 2
proc_old:       .res 2          ; the vector as it was
proc_chain:     .res 2          ; the same, less one, for the RTS that jumps to it

        .code

; uint8_t fn_atari_proc_enable(void)
; Installs the handler and enables the interrupt. Safe to call again. Returns FN_OK.
_fn_atari_proc_enable:
        lda proc_active
        bne @done
        php
        sei
        lda VPRCED
        sta proc_old
        sec
        sbc #1
        sta proc_chain
        lda VPRCED+1
        sta proc_old+1
        sbc #0
        sta proc_chain+1
        lda #0
        sta proc_pending
        sta proc_count
        sta proc_count+1
        lda #<proc_isr
        sta VPRCED
        lda #>proc_isr
        sta VPRCED+1
        lda #1
        sta proc_active
        lda PORTA               ; a flag left over from before is not an event
        lda PACTL
        ora #$01
        sta PACTL
        plp
@done:  lda #FN_OK
        ldx #0
        rts

; void fn_atari_proc_disable(void): interrupt off, the previous handler back.
_fn_atari_proc_disable:
        lda proc_active
        beq @done
        php
        sei
        lda PACTL
        and #$FE
        sta PACTL
        lda proc_old
        sta VPRCED
        lda proc_old+1
        sta VPRCED+1
        lda #0
        sta proc_active
        plp
@done:  rts

; uint8_t fn_atari_proc_pending(void): 1 if a PROC interrupt came since the last call (or since enable),
; and clears that, 0 if not.
_fn_atari_proc_pending:
        php
        sei
        lda proc_pending
        ldy #0
        sty proc_pending
        plp
        ldx #0
        rts

; uint16_t fn_atari_proc_count(void): PROC interrupts since enable (wraps at 65536).
_fn_atari_proc_count:
        php
        sei
        lda proc_count
        ldx proc_count+1
        plp
        rts

; The handler at VPRCED. A is on the stack, as the OS IRQ routine left it.
proc_isr:
        lda PORTA               ; clear the PIA flag, or the interrupt comes straight back
        inc proc_count
        bne @counted
        inc proc_count+1
@counted:
        lda #1
        sta proc_pending
        jsr _fn_atari_proc_notify ; the library's own readiness latch as well
        lda proc_chain+1        ; on to the previous handler, which ends with PLA, RTI
        pha
        lda proc_chain
        pha
        rts
