; fn_hsio.s - high-speed SIO for the native 0x7f endpoint (Atari)
;
; Derived from the high-speed SIO routine of Matthias Reichl (hipatch 1.30, the HISIO driver of
; MyPicoDOS), which is
;
;   Copyright (c) 2003-2010 by Matthias Reichl <hias@horus.com>
;
; and is licensed under the GNU General Public License, version 2 or (at your option) any later
; version. This port is distributed under the GPL as well (this repository is GPL-3.0).
;
; What changed from the original, so the two can be compared:
;  - ported from his atasm/MAC65 source to ca65, with the code split and ordered differently;
;  - reduced to the "ultra speed" case: the device answers the Happy/Speedy 3F query with a POKEY
;    divisor and every frame, command included, goes at that speed. The 1050 Turbo, XF551 and Happy
;    warp modes, the speed table by unit and the drive probing are gone: the other end here is the
;    FujiNet native endpoint, and fn_atari_hsio_enable does the 3F query;
;  - the fast VBI timeout variant only (no SETVBV timers), with the RTCLOK catch-up, no diagnostics;
;  - entered in place of the OS SIOV by fn_transport.s (DCB in, DSTATS and Y out);
;  - the relocation table and the relocatable-code labels are gone, the code is linked normally.
;
; The original warns that the receive loop (hs_getlp to its closing bne) should not cross a page
; boundary, or overruns are more likely at 126 kbit/s (POKEY divisor 0). It is about 60 cycles a byte
; against 143 at that rate and more at the slower indexes, so this port does not force the alignment:
; that would make every Atari program's whole code segment page-aligned (the linker warns otherwise).
; Index 0 is the case to watch on real hardware; indexes 1 and up have room to spare.
;
; Nothing here links into a program unless it calls fn_atari_hsio_enable.

        .export _fn_atari_hsio_enable, _fn_atari_hsio_disable, _fn_atari_hsio_index
        .export _fn_atari_hsio_error_count, hs_vec
        .import fn_sio_call, fn_sio_vec, fn_sio_default, fn_sio_reply_length
        .import _fn_atari_query_capabilities

FN_OK = $00
FN_ERR_UNSUPPORTED = $08

; Highest index offered: a speed byte of $0A is read by drivers as a Happy 1050.
HSIO_MAX_INDEX = 9

; Zero page and OS locations the OS SIO routine itself uses while it runs; free for the duration.
POKMSK = $10
RTCLOK = $12
STATUS = $30
CHKSUM = $31
BUFRLO = $32
BUFRHI = $33
BFENLO = $34
BFENHI = $35
CRETRY = $38            ; command frame retries
DRETRY = $39            ; data frame retries
MYSPEED = $3A           ; speed used by this command (standard for the second round of retries)
MYTIM1 = $3B            ; fast VBI timeout, two bytes
SOUNDR = $41
CRITIC = $42
STACKP = $318
VVBLKI = $222
CDEVIC = $23A
CCOMND = $23B
CAUX1 = $23C
CAUX2 = $23D
DDEVIC = $300
DUNIT = $301
DCOMND = $302
DSTATS = $303
DBUFLO = $304
DBUFHI = $305
DTIMLO = $306
DBYTLO = $308
DBYTHI = $309
DAUX1 = $30A
DAUX2 = $30B

AUDF3 = $D204
AUDF4 = $D206
AUDC4 = $D207
AUDCTL = $D208
SKREST = $D20A
SERIN = $D20D
SEROUT = $D20D
IRQEN = $D20E
IRQST = $D20E
SKCTL = $D20F
SKSTAT = $D20F
PBCTL = $D303
WSYNC = $D40A

; IRQEN/IRQST masks
IMRECV = $20            ; byte received
IMSEND = $10            ; ready to send the next byte
IMSCPL = $08            ; transmission complete
RMBRK = $7F
RMRECV = $DF
RMSEND = $EF
MSKRECV = $A0           ; break + receive
MSKSEND = $90           ; break + send
SKSEND = $23            ; SKCTL: transmit (synchronous)
SKRECV = $13            ; SKCTL: receive (asynchronous)

ERRBRK = $80
ERRTO = $8A
ERRNAK = $8B
ERRFRM = $8C
ERROVR = $8E
ERRCHK = $8F
ERRDEV = $90

DEFCRETRY = $0E         ; command frame retries
STDSPD = $28            ; standard speed: POKEY divisor 40, 19200 baud

        .bss
hs_speed:       .res 1  ; the POKEY divisor to use (the index the device gave)
hs_active:      .res 1
hs_reply:       .res 1
hs_errcount:    .res 6  ; errors seen by the driver, by code: $8A..$8F (retried ones included), saturating

        .data
; The SIO entry enabling installs (the engine, entered by RTS so one less than its address). A variable
; only so that a test can put a fixture in its place: the engine drives POKEY.
hs_vec: .word hs_engine-1

        .code

; uint8_t fn_atari_hsio_enable(void)
; Asks the native endpoint for its high-speed index (the 3F query, at standard speed, through the
; OS SIO) and, if it offers one from 0 to 9, makes every native call from here on use it. Call it
; after fn_init. Returns FN_OK, or FN_ERR_UNSUPPORTED if the firmware has no index set (it NAKs 3F)
; or the answer is not usable; nothing changes then.
_fn_atari_hsio_enable:
        lda #1
        sta fn_sio_reply_length
        lda #0
        sta fn_sio_reply_length+1
        lda #$40
        sta DSTATS
        ldx #<hs_reply
        ldy #>hs_reply
        lda #$3F
        jsr fn_sio_call
        bne @unsupported
        lda hs_reply
        cmp #HSIO_MAX_INDEX+1
        bcs @unsupported
        sta hs_speed
        ldx #5                  ; a fresh count
        lda #0
@clear: sta hs_errcount,x
        dex
        bpl @clear
        lda #1
        sta hs_active
        lda hs_vec
        sta fn_sio_vec
        lda hs_vec+1
        sta fn_sio_vec+1
        ; Ask what else the firmware offers, now through the driver (the FujiNet is at the high speed).
        ; This is how a call can skip the poll when the firmware allows it; failure just leaves it off.
        jsr _fn_atari_query_capabilities
        lda #FN_OK
        ldx #0
        rts
@unsupported:
        lda #FN_ERR_UNSUPPORTED
        ldx #0
        rts

; void fn_atari_hsio_disable(void): native calls use the OS SIO again.
_fn_atari_hsio_disable:
        lda #0
        sta hs_active
        jmp fn_sio_default

; uint8_t fn_atari_hsio_index(void): the index in use, or $FF when high speed is off.
_fn_atari_hsio_index:
        ldx #0
        lda hs_active
        beq @off
        lda hs_speed
        rts
@off:   lda #$FF
        rts

; uint8_t fn_atari_hsio_error_count(uint8_t code)
; How many times the driver met this error since fn_atari_hsio_enable (saturating at 255), counting the
; ones it retried: $8A timeout, $8B NAK or no ACK, $8C framing, $8E overrun, $8F checksum. Zero for any
; other code. An error after the command's ACK makes the driver retry the whole command at standard
; speed, so these say why a high-speed run fell back.
_fn_atari_hsio_error_count:
        sec
        sbc #ERRTO
        cmp #6
        bcs @none
        tax
        lda hs_errcount,x
        ldx #0
        rts
@none:  lda #0
        tax
        rts

; ---------------------------------------------------------------------------------------------
; Receive.
; Carry clear: receive the block described by BUFR/BFEN and check its checksum; carry set: one byte.

hs_getblk:
        ldy #$00
        sty CHKSUM
hs_getlp:
        clc                     ; C=0 means receive block, C=1 receive single byte
hs_getbyt:
        lda #IMRECV
hs_getby2:
        bit IRQST
        bpl hs_errbrk           ; break key pressed?
        bne hs_getby2
        ldx SERIN
        lda #RMRECV             ; reset data-receive IRQ bit
        sta IRQEN
        lda #MSKRECV            ; enable data-receive IRQ
        sta IRQEN
        lda #$20
        bit SKSTAT
        bpl hs_errfrm           ; framing error
        beq hs_errovr           ; data input overrun
        txa
        bcs hs_dorts
        sta (BUFRLO),y
        clc
        adc CHKSUM
        adc #$00
        sta CHKSUM
        iny
        bne hs_get1
        inc BUFRHI
        dec BFENHI
hs_get1:
        cpy BFENLO
        bne hs_getlp
        lda BFENHI
        bne hs_getlp
        sec
        jsr hs_getbyt
        cmp CHKSUM
        beq hs_dorts
        lda #ERRCHK
        jmp hs_err
hs_dorts:
        rts

; ---------------------------------------------------------------------------------------------
; Errors: the code in A ends up in STATUS, the stack is unwound and the command is cleaned up and
; retried or finished.

hs_errnak:
        lda #ERRNAK             ; NAK or any other error
        .byte $2C               ; BIT abs: skip the next two bytes
hs_errfrm:
        lda #ERRFRM             ; framing error
        .byte $2C
hs_errovr:
        lda #ERROVR             ; data input overrun
        .byte $2C
hs_errto:
        lda #ERRTO              ; timeout
hs_err:
        sta STATUS
        sec                     ; count it, by code: ERRTO..ERRCHK are $8A..$8F
        sbc #ERRTO
        cmp #6
        bcs hs_nocount
        tax
        lda hs_errcount,x
        cmp #$FF
        beq hs_nocount
        inc hs_errcount,x
hs_nocount:
        ldx STACKP
        txs
        jmp hs_sioend

; Break key.
hs_errbrk:
        lda #RMBRK              ; reset break interrupt flag
        sta IRQEN
        lda POKMSK              ; set the default pokey interrupt mask
        sta IRQEN
        ldx STACKP
        txs
        jsr hs_cleanup
        ldy #ERRBRK
        sty STATUS
        jmp hs_endcmd           ; end the command without retrying

; ---------------------------------------------------------------------------------------------
; Status checks.

; Receive the command frame's ACK within the timeout.
hs_chkst:
        ldy #2
        ldx #1
        jsr hs_smytout
        lda #MSKRECV
        sta IRQEN
        jsr hs_rdack
        bne hs_errnak           ; ERROR is handled like NAK
hs_rdok:
        rts

; Set the command timeout (DTIMLO in 64 frame units) and wait for COMPLETE.
hs_waitcpl:
        lda DTIMLO
        ror a
        ror a
        tay
        and #$3F
        tax
        tya
        ror a
        and #$C0
        tay
        inx                     ; the high value must be incremented
        jsr hs_smytout

; Receive ACK/NAK or COMPLETE/ERROR.
hs_rdack:
        lda #SKRECV             ; set pokey to receive async mode
        sta SKCTL
        sta SKREST
        lda #$3C                ; clear the command line
        sta PBCTL
        sec
        jsr hs_getbyt
        cmp #'A'                ; ACK
        beq hs_rdok
        cmp #'C'                ; COMPLETE
        beq hs_rdok
        cmp #'E'                ; command ERROR
        beq hs_rderr
        jmp hs_errnak
hs_rderr:
        lda #ERRDEV
        sta STATUS
        rts

; ---------------------------------------------------------------------------------------------
; Cleanup, the fast timer and the VBI code.

hs_cleanup:
        lda #$A0                ; reset pokey
        sta AUDC4
        lda #$3C                ; clear the command line
        sta PBCTL
hs_clrtim1:
        lda #$FF
        sta MYTIM1+1
        rts

; Set the timeout: X=hi, Y=lo.
hs_smytout:
        jsr hs_wtvbi
        sty MYTIM1
        stx MYTIM1+1
        rts

; Like SETVBV: waste 22 cpu cycles after WSYNC so the VBI code can run.
hs_wtvbi:
        sta WSYNC
        bit STACKP              ; 4 cycles
        bit STACKP
        bit STACKP
        bit STACKP
        rts                     ; 6 cycles

; The fast immediate VBI handler: the system clock, and a timer that jumps to the timeout error
; when it reaches 0. MYTIM1+1 set to $FF means it will run long enough before that.
hs_vbicode:
        inc RTCLOK+2
        bne hs_noc1
        inc RTCLOK+1
hs_noc1:
        dec MYTIM1
        bne hs_notout
        dec MYTIM1+1
        beq hs_runtim           ; the timer reached 0
hs_notout:
        pla                     ; what XITVBV does, without the jump
        tay
        pla
        tax
        pla
        rti
hs_runtim:
        jmp hs_errto

; ---------------------------------------------------------------------------------------------
; Send a byte or a block. No break key check while sending: it confuses several drives.

hs_sendbyt:
        tax
        lda #IMSEND
hs_wput:
        bit IRQST
        bne hs_wput
        lda #RMSEND
        sta IRQEN
        lda #MSKSEND
        sta IRQEN
        txa
        sta SEROUT
        clc                     ; add it to the checksum
        adc CHKSUM
        adc #$00
        sta CHKSUM
        rts

hs_sendblk:
        ldy #$00                ; a short delay before sending
hs_wt1:
        iny
        bne hs_wt1
        lda #SKSEND             ; set pokey to transmit mode
        sta SKCTL
        sta SKREST
        lda #MSKSEND
        sta IRQEN
        lda (BUFRLO),y          ; start the transmission with the first byte
        sta CHKSUM
        sta SEROUT
        iny
        bne hs_snd2             ; always
hs_snd1:
        lda (BUFRLO),y
        jsr hs_sendbyt
        iny
        bne hs_snd2
        inc BUFRHI
        dec BFENHI
        ldx #$E0                ; wait a little after a full page, some drives need it
hs_wt2:
        inx
        bne hs_wt2
hs_snd2:
        cpy BFENLO
        bne hs_snd1
        lda BFENHI
        bne hs_snd1
        lda CHKSUM
        jsr hs_sendbyt
        lda #IMSCPL
hs_wtsnd:
        bit IRQST               ; wait until the transmission is complete
        bne hs_wtsnd
        rts

; ---------------------------------------------------------------------------------------------
; The SIO routine proper: the DCB in, DSTATS (1 for success, else the error) and Y out.
; Entered by RTS from fn_transport.s's dispatch, so the final RTS returns to its caller.

hs_engine:
        lda #$02                ; two rounds: the second at standard speed
        ldx #DEFCRETRY
        sta DRETRY
        stx CRETRY
        sei
        lda #$01
        sta CRITIC
        clc
        lda DDEVIC              ; the command frame's device byte: device + unit - 1
        adc DUNIT
        adc #$FF
        sta CDEVIC
        jsr hs_clrtim1
        lda VVBLKI              ; save the old immediate VBI handler
        pha
        lda VVBLKI+1
        pha
        ldy #<hs_vbicode        ; install the fast one
        ldx #>hs_vbicode
        jsr hs_wtvbi
        sty VVBLKI
        stx VVBLKI+1
        lda RTCLOK+1            ; for the catch-up at the end
        pha
        tsx
        stx STACKP
        lda hs_speed
        sta MYSPEED

hs_dretlp:
        lda DAUX1
        sta CAUX1
        lda DAUX2
        sta CAUX2
        lda DCOMND
        sta CCOMND

hs_cretlp:
        lda MYSPEED
        sta AUDF3
        lda #$34                ; set the command line
        sta PBCTL
        lda #$00
        sta STATUS
        sta BFENHI
        sta AUDF4
        lda #<CDEVIC
        sta BUFRLO
        lda #>CDEVIC
        sta BUFRHI
        asl a
        sta BFENLO              ; the four command frame bytes ($02 << 1 = 4)

        lda #$28                ; set up pokey
        sta AUDCTL
        ldx #$A0
        lda SOUNDR
        beq hs_nosnd
        ldx #$A8
hs_nosnd:
        stx AUDC4

        jsr hs_sendblk          ; the command frame
        jsr hs_chkst            ; its ACK/NAK
        jsr hs_clrtim1          ; got the ACK, clear the timer

        lda #1
        sta CRETRY              ; no more command frame retries
        lda DBUFLO
        sta BUFRLO
        lda DBUFHI
        sta BUFRHI
        lda DBYTLO
        sta BFENLO
        lda DBYTHI
        sta BFENHI
        lda DSTATS
        bpl hs_nosend
        jsr hs_sendblk          ; the data frame (a write)
        jsr hs_chkst            ; its ACK/NAK
hs_nosend:
        jsr hs_waitcpl          ; set the timeout and wait for COMPLETE
        bit DSTATS
        bvc hs_sioend
        jsr hs_getblk           ; receive the data frame (a read)

hs_sioend:
        jsr hs_cleanup          ; reset the timers and pokey
        ldy STATUS              ; was the command successful?
        beq hs_endcmd           ; yes
        dec CRETRY              ; retry the command frame?
        beq hs_chkdr            ; no, already tried enough
        jmp hs_cretlp
hs_chkdr:
        dec DRETRY              ; another round of command retries?
        beq hs_endcmd           ; no
        cpy #ERRDEV
        beq hs_godr             ; do not fall back on a command error
        lda #STDSPD             ; try it at standard speed this time
        sta MYSPEED
hs_godr:
        lda #DEFCRETRY
        sta CRETRY
        jmp hs_dretlp

hs_endcmd:
        pla
        sta CHKSUM              ; the saved RTCLOK middle byte
        pla
        tax
        pla
        tay
        jsr hs_wtvbi            ; restore the old immediate VBI handler
        sty VVBLKI
        stx VVBLKI+1
        lda RTCLOK+1            ; the handler kept RTCLOK going; if the middle byte wrapped, carry into
        cmp CHKSUM              ; the high byte (smaller than before means it wrapped)
        bcs hs_nowrap
        inc RTCLOK
hs_nowrap:
        lda #0
        sta CRITIC
        lda POKMSK
        sta IRQEN
        ldy STATUS
        bne hs_errcmd
        iny
hs_errcmd:
        sty DSTATS
        cli
        rts
