; Production fn_transport.s under a fixture-controlled SIOV peer.
        .export _test_func, _test_result, __fn_transport_ctx
        .importzp ptr1, ptr2
        .segment "BSS"
__fn_transport_ctx: .res 10
request: .res 4
response: .res 8
step: .res 1
mode: .res 1
failure: .res 1
expected_dstats: .res 1
saved_ptr1: .res 2
_test_result: .res 18
        .segment "CODE"
_test_func:
        lda #$fc
        sta request
        lda #$01
        sta request+1
        lda #$04
        sta request+2
        lda #$ff
        sta request+3
        lda #<request
        sta __fn_transport_ctx
        lda #>request
        sta __fn_transport_ctx+1
        lda #<response
        sta __fn_transport_ctx+2
        lda #>response
        sta __fn_transport_ctx+3
        lda #4
        sta __fn_transport_ctx+4
        lda #8
        sta __fn_transport_ctx+6
        lda #0
        sta step
        sta mode
        sta failure
        jsr _fn_transport_init
        jsr _fn_atari_max_payload
        sta _test_result+6
        stx _test_result+7
        ; Initial W, then 60 pending P polls: must return timeout.
        jsr _fn_transport_exchange
        sta _test_result
        ; Outstanding request recovery must be P-ready, R, then next W/P/R.
        jsr _fn_transport_exchange
        sta _test_result+1
        lda step
        sta _test_result+2
        lda failure
        sta _test_result+3
        lda __fn_transport_ctx+8
        sta _test_result+4
        lda __fn_transport_ctx+9
        sta _test_result+5
        ; Rejected W must not create an outstanding transaction: the next
        ; exchange's first SIOV call is W, not recovery P/R.
        lda #1
        sta mode
        lda #0
        sta step
        sta failure
        jsr _fn_transport_exchange
        sta _test_result+8
        jsr _fn_transport_exchange
        sta _test_result+9
        lda step
        sta _test_result+10
        lda failure
        sta _test_result+11
        lda response
        sta _test_result+12
        lda response+1
        sta _test_result+13
        lda response+2
        sta _test_result+14
        lda response+3
        sta _test_result+15
        lda __fn_transport_ctx+8
        sta _test_result+16
        lda __fn_transport_ctx+9
        sta _test_result+17
        rts

; X=expected command, A=expected DSTATS.  Bad DCB is a sticky test failure.
check_dcb:
        sta expected_dstats
        lda $0300
        cmp #$7f
        bne bad
        txa
        cmp $0302
        bne bad
        lda expected_dstats
        cmp $0303
        bne bad
        cpx #'P'
        beq fixed_poll
        lda $0308
        cmp #4
        bne bad
        lda $0309
        bne bad
        lda $030a
        cmp #4
        bne bad
        lda $030b
        bne bad
        rts
fixed_poll:
        lda $0308
        cmp #3
        bne bad
        lda $0309
        bne bad
        lda $030a
        bne bad
        lda $030b
        bne bad
        rts
bad:    lda step
        clc
        adc #1
        sta failure
        rts

; A=state and X/Y=reply length for a P reply.
put_poll:
        pha
        lda ptr1
        sta saved_ptr1
        lda ptr1+1
        sta saved_ptr1+1
        lda $0304
        sta ptr1
        lda $0305
        sta ptr1+1
        ldy #0
        pla
        sta (ptr1),y
        iny
        txa
        sta (ptr1),y
        iny
        tya
        ; caller places high length in _test_result+15
        lda _test_result+15
        sta (ptr1),y
        lda saved_ptr1
        sta ptr1
        lda saved_ptr1+1
        sta ptr1+1
        lda #1
        sta $0303
        rts

fake_siov:
        lda mode
        beq :+
        jmp rejected_fake
:
        ldx step
        cpx #0
        bne :+
        jmp first_w
:
        cpx #61
        bcs :+
        jmp pending_p
:
        cpx #61
        bne :+
        jmp recovery_p
:
        cpx #62
        bne :+
        jmp recovery_r
:
        cpx #63
        bne :+
        jmp next_w
:
        cpx #64
        bne :+
        jmp next_p
:
        cpx #65
        bne :+
        jmp next_r
:
        jmp bad
first_w:
        ldx #'W'
        lda #$80
        jsr check_dcb
        inc step
        lda #1
        sta $0303
        rts

; Mode 1: rejected W, then direct W/P/R success.  Any recovery P/R before
; step 1 reaches bad, proving the rejected W left no outstanding request.
rejected_fake:
        ldx step
        cpx #0
        beq rejected_w
        cpx #1
        beq accepted_w
        cpx #2
        beq accepted_p
        cpx #3
        bne :+
        jmp accepted_r
:
        jmp bad
rejected_w:
        ldx #'W'
        lda #$80
        jsr check_dcb
        inc step
        lda #0
        sta $0303
        rts
accepted_w:
        ldx #'W'
        lda #$80
        jsr check_dcb
        inc step
        lda #1
        sta $0303
        rts
accepted_p:
        ldx #'P'
        lda #$40
        jsr check_dcb
        lda #0
        sta _test_result+15
        lda #2
        ldx #4
        jsr put_poll
        inc step
        rts
accepted_r:
        ldx #'R'
        lda #$40
        jsr check_dcb
        ldy #0
        lda ptr1
        sta saved_ptr1
        lda ptr1+1
        sta saved_ptr1+1
        lda $0304
        sta ptr1
        lda $0305
        sta ptr1+1
        lda #$fc
        sta (ptr1),y
        iny
        lda #$01
        sta (ptr1),y
        iny
        lda #$04
        sta (ptr1),y
        iny
        lda #$ff
        sta (ptr1),y
        lda saved_ptr1
        sta ptr1
        lda saved_ptr1+1
        sta ptr1+1
        inc step
        lda #1
        sta $0303
        rts
pending_p:
        ldx #'P'
        lda #$40
        jsr check_dcb
        lda #0
        sta _test_result+15
        lda #1
        ldx #0
        jsr put_poll
        inc step
        rts
recovery_p:
        ldx #'P'
        lda #$40
        jsr check_dcb
        lda #0
        sta _test_result+15
        lda #2
        ldx #4
        jsr put_poll
        inc step
        rts
recovery_r:
        ldx #'R'
        lda #$40
        jsr check_dcb
        inc step
        lda #1
        sta $0303
        rts
next_w:
        ldx #'W'
        lda #$80
        jsr check_dcb
        inc step
        lda #1
        sta $0303
        rts
next_p:
        lda $0300
        sta _test_result+8
        lda $0302
        sta _test_result+9
        lda $0303
        sta _test_result+10
        lda $0308
        sta _test_result+11
        lda $030a
        sta _test_result+12
        ldx #'P'
        lda #$40
        jsr check_dcb
        lda #0
        sta _test_result+15
        lda #2
        ldx #4
        jsr put_poll
        inc step
        rts
next_r:
        ldx #'R'
        lda #$40
        jsr check_dcb
        inc step
        ldy #0
        lda ptr1
        sta saved_ptr1
        lda ptr1+1
        sta saved_ptr1+1
        lda $0304
        sta ptr1
        lda $0305
        sta ptr1+1
        lda #$fc
        sta (ptr1),y
        iny
        lda #$01
        sta (ptr1),y
        iny
        lda #$04
        sta (ptr1),y
        iny
        lda #$ff
        sta (ptr1),y
        lda saved_ptr1
        sta ptr1
        lda saved_ptr1+1
        sta ptr1+1
        lda #1
        sta $0303
        rts

FN_ATARI_TEST_SIOV = fake_siov
        .include "../src/platform/atari/fn_transport.s"
