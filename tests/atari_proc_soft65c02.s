; fn_proc.s under soft65c02: what the library does with the PROC interrupt, with the hardware stood in for
; by RAM (PACTL, PORTA) and the OS IRQ routine by the test pushing the frame it would and jumping through
; VPRCED. This checks the vector, the enable bit, the count, the pending flag and the chain to the
; previous handler. It cannot show that the PIA raises the interrupt: that is the PROCTEST program on the
; Atari with `sio.proc pulse` on the FujiNet.
        .export _test_func, _test_result, _fn_atari_proc_notify
        .import _fn_atari_proc_enable, _fn_atari_proc_disable, _fn_atari_proc_pending, _fn_atari_proc_count
        .import proc_isr

PACTL = $D302
VPRCED = $0202

        .segment "BSS"
_test_result: .res 32
old_calls: .res 1
notify_calls: .res 1
a_back: .res 1
        .segment "CODE"

_fn_atari_proc_notify:
        inc notify_calls
        rts

; The handler that was installed before: ends with PLA, RTI as the OS default does, and shows A came back.
fake_old:
        inc old_calls
        pla
        sta a_back
        rti

; What the OS IRQ routine does for a PROCEED interrupt: the interrupt frame, then A, then the vector.
fire:
        lda #>@back
        pha
        lda #<@back
        pha
        php
        lda #$5A
        pha
        jmp (VPRCED)
@back:  rts

_test_func:
        lda #<fake_old
        sta VPRCED
        lda #>fake_old
        sta VPRCED+1
        lda #$34                ; the OS value: command line and motor control bits set, interrupt off
        sta PACTL
        lda #0
        sta old_calls
        sta notify_calls

        jsr _fn_atari_proc_enable
        sta _test_result+0                      ; 0: FN_OK
        lda VPRCED
        cmp #<proc_isr
        bne @notours
        lda VPRCED+1
        cmp #>proc_isr
        bne @notours
        lda #1
        bne @isours
@notours:
        lda #0
@isours:
        sta _test_result+1                      ; 1: our handler is installed
        lda PACTL
        and #$01
        sta _test_result+2                      ; 1: the interrupt is enabled
        lda PACTL
        and #$FE
        sta _test_result+3                      ; $34: nothing else in PACTL changed
        jsr _fn_atari_proc_pending
        sta _test_result+4                      ; 0: nothing yet
        jsr _fn_atari_proc_count
        sta _test_result+5                      ; 0
        stx _test_result+6                      ; 0

        jsr fire
        jsr _fn_atari_proc_pending
        sta _test_result+7                      ; 1: pending after an interrupt
        jsr _fn_atari_proc_pending
        sta _test_result+8                      ; 0: reading it cleared it
        lda old_calls
        sta _test_result+9                      ; 1: the previous handler was chained to
        lda a_back
        sta _test_result+10                     ; $5A: A came back to it as the OS saved it
        lda notify_calls
        sta _test_result+11                     ; 1: the library's own latch was set
        jsr _fn_atari_proc_count
        sta _test_result+12                     ; 1

        jsr fire
        jsr fire
        jsr _fn_atari_proc_count
        sta _test_result+13                     ; 3
        stx _test_result+14                     ; 0
        lda old_calls
        sta _test_result+15                     ; 3

        ; Enabling again changes nothing: it must not chain to itself or reset the count.
        jsr _fn_atari_proc_enable
        jsr _fn_atari_proc_count
        sta _test_result+16                     ; still 3

        ; Disable: interrupt off, the old handler back.
        jsr _fn_atari_proc_disable
        lda PACTL
        sta _test_result+17                     ; $34
        lda VPRCED
        cmp #<fake_old
        bne @notold
        lda VPRCED+1
        cmp #>fake_old
        bne @notold
        lda #1
        bne @isold
@notold:
        lda #0
@isold:
        sta _test_result+18                     ; 1
        jsr _fn_atari_proc_disable              ; again: harmless
        lda VPRCED
        cmp #<fake_old
        bne @notold2
        lda VPRCED+1
        cmp #>fake_old
        bne @notold2
        lda #1
        bne @isold2
@notold2:
        lda #0
@isold2:
        sta _test_result+19                     ; 1: still the old handler

        ; Enable after disable starts a fresh count.
        jsr _fn_atari_proc_enable
        jsr _fn_atari_proc_count
        sta _test_result+20                     ; 0
        jsr _fn_atari_proc_disable
        rts
