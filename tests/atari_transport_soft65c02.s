; Production fn_transport.s under a fixture-controlled SIOV peer.
        .export _test_func, _test_result, __fn_transport_ctx
        .importzp ptr1, ptr2
        .segment "BSS"
__fn_transport_ctx: .res 10
request: .res 4
response: .res 8
request_guard_lo: .res 1
request_large: .res 512
request_guard_hi: .res 1
response_guard_lo: .res 1
response_large: .res 512
response_guard_hi: .res 1
step: .res 1
mode: .res 1
failure: .res 1
pattern_failure: .res 1
expected_dstats: .res 1
expected_length_lo: .res 1
expected_length_hi: .res 1
saved_ptr1: .res 2
poll_length_high: .res 1
q_reply: .res 4
malformed_kind: .res 1
_test_result: .res 118
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
        sta pattern_failure
        sta poll_length_high
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
        sta pattern_failure
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
        ; A failed terminal R leaves the prior response outstanding.  The next
        ; exchange must retire it with P/R before issuing its new W.
        lda #2
        sta mode
        lda #0
        sta step
        sta failure
        sta pattern_failure
        sta poll_length_high
        lda #$aa
        sta response
        sta response+1
        sta response+2
        sta response+3
        jsr _fn_transport_exchange
        sta _test_result+18
        jsr _fn_transport_exchange
        sta _test_result+19
        lda step
        sta _test_result+20
        lda failure
        sta _test_result+21
        lda response
        sta _test_result+22
        lda response+1
        sta _test_result+23
        lda response+2
        sta _test_result+24
        lda response+3
        sta _test_result+25
        lda __fn_transport_ctx+8
        sta _test_result+26
        lda __fn_transport_ctx+9
        sta _test_result+27
        ; 511/512-byte transfers must be exact, 513-byte requests must never
        ; enter SIOV, and an oversized reply must remain outstanding.
        jsr set_large_context
        lda #3
        sta mode
        lda #0
        sta step
        sta failure
        sta pattern_failure
        sta poll_length_high
        lda #$a1
        sta request_guard_lo
        lda #$a2
        sta request_guard_hi
        lda #$b1
        sta response_guard_lo
        lda #$b2
        sta response_guard_hi
        lda #$ff
        sta __fn_transport_ctx+4
        lda #$01
        sta __fn_transport_ctx+5
        jsr _fn_transport_exchange
        sta _test_result+28
        lda __fn_transport_ctx+8
        sta _test_result+29
        lda __fn_transport_ctx+9
        sta _test_result+30
        lda #0
        sta __fn_transport_ctx+4
        lda #2
        sta __fn_transport_ctx+5
        jsr _fn_transport_exchange
        sta _test_result+31
        lda __fn_transport_ctx+8
        sta _test_result+32
        lda __fn_transport_ctx+9
        sta _test_result+33
        lda #1
        sta __fn_transport_ctx+4
        lda #2
        sta __fn_transport_ctx+5
        jsr _fn_transport_exchange
        sta _test_result+34
        lda step
        sta _test_result+35
        lda #0
        sta __fn_transport_ctx+4
        lda #2
        sta __fn_transport_ctx+5
        jsr _fn_transport_exchange
        sta _test_result+36
        jsr _fn_transport_exchange
        sta _test_result+37
        lda step
        sta _test_result+38
        jsr verify_512_reply
        lda failure
        sta _test_result+39
        lda response_large
        sta _test_result+40
        lda response_large+255
        sta _test_result+41
        lda response_large+511
        sta _test_result+42
        lda request_guard_lo
        sta _test_result+43
        lda request_guard_hi
        sta _test_result+44
        lda response_guard_lo
        sta _test_result+45
        lda response_guard_hi
        sta _test_result+46
        lda pattern_failure
        sta _test_result+47
        ; Q is explicitly optional: init must retain the baseline without an
        ; SIOV call, then each malformed capability reply restores it.
        lda #4
        sta mode
        lda #0
        sta step
        sta failure
        sta pattern_failure
        lda #$d7
        sta poll_count
        lda #$c1
        sta reply_state
        lda #$c2
        sta reply_state+1
        lda #$c3
        sta reply_state+2
        jsr _fn_transport_init
        jsr _fn_atari_max_payload
        sta _test_result+48
        stx _test_result+49
        lda step
        sta _test_result+50
        jsr _fn_atari_query_capabilities
        sta _test_result+51
        jsr _fn_atari_max_payload
        sta _test_result+52
        stx _test_result+53
        lda capability_reply
        sta _test_result+54
        lda capability_reply+1
        sta _test_result+55
        lda capability_reply+2
        sta _test_result+56
        lda capability_reply+3
        sta _test_result+57
        jsr _fn_atari_query_capabilities
        sta _test_result+58
        jsr _fn_atari_max_payload
        sta _test_result+59
        stx _test_result+60
        jsr _fn_atari_query_capabilities
        sta _test_result+61
        jsr _fn_atari_max_payload
        sta _test_result+62
        stx _test_result+63
        jsr _fn_atari_query_capabilities
        sta _test_result+64
        jsr _fn_atari_max_payload
        sta _test_result+65
        stx _test_result+66
        lda step
        sta _test_result+67
        lda failure
        sta _test_result+68
        lda outstanding
        sta _test_result+69
        lda poll_count
        sta _test_result+70
        lda reply_state
        sta _test_result+71
        lda reply_state+1
        sta _test_result+72
        lda reply_state+2
        sta _test_result+73
        ; A malformed P or an SIO error must not turn an accepted W into an
        ; idle transaction.  Each next exchange first recovers the retained
        ; response with P/R, then sends its new W/P/R exchange.
        jsr set_small_context
        lda #5
        sta mode
        lda #0
        sta malformed_kind
        sta step
        sta failure
        sta pattern_failure
        jsr _fn_transport_init
        jsr _fn_transport_exchange
        sta _test_result+74
        lda outstanding
        sta _test_result+75
        jsr _fn_transport_exchange
        sta _test_result+76
        lda step
        sta _test_result+77
        lda failure
        sta _test_result+78
        jsr save_malformed_response_0
        ; READY with a zero byte count is also malformed and retains W.
        jsr set_small_context
        lda #1
        sta malformed_kind
        lda #0
        sta step
        sta failure
        sta pattern_failure
        jsr _fn_transport_init
        jsr _fn_transport_exchange
        sta _test_result+85
        lda outstanding
        sta _test_result+86
        jsr _fn_transport_exchange
        sta _test_result+87
        lda step
        sta _test_result+88
        lda failure
        sta _test_result+89
        jsr save_malformed_response_1
        ; A failed SIOV P has the same retain/recover behavior.
        jsr set_small_context
        lda #2
        sta malformed_kind
        lda #0
        sta step
        sta failure
        sta pattern_failure
        jsr _fn_transport_init
        jsr _fn_transport_exchange
        sta _test_result+96
        lda outstanding
        sta _test_result+97
        jsr _fn_transport_exchange
        sta _test_result+98
        lda step
        sta _test_result+99
        lda failure
        sta _test_result+100
        jsr save_malformed_response_2
        ; A device reset reports canonical idle.  It retires the stale local
        ; outstanding state without an R, then permits the next application
        ; request (whose payload differs from the timed-out request) to run.
        jsr set_small_context
        lda #6
        sta mode
        lda #0
        sta step
        sta failure
        sta pattern_failure
        jsr _fn_transport_init
        jsr _fn_transport_exchange
        sta _test_result+107
        lda outstanding
        sta _test_result+108
        lda #$fe
        sta request+3
        jsr _fn_transport_exchange
        sta _test_result+109
        lda step
        sta _test_result+110
        lda failure
        sta _test_result+111
        lda response
        sta _test_result+112
        lda response+1
        sta _test_result+113
        lda response+2
        sta _test_result+114
        lda response+3
        sta _test_result+115
        lda __fn_transport_ctx+8
        sta _test_result+116
        lda __fn_transport_ctx+9
        sta _test_result+117
        rts

; X=expected command, A=expected DSTATS.  Bad DCB is a sticky test failure.
check_dcb:
        sta expected_dstats
        cpx #'P'
        beq @poll
        lda #4
        sta expected_length_lo
        lda #0
        sta expected_length_hi
        jmp check_dcb_common
@poll:  lda #3
        sta expected_length_lo
        lda #0
        sta expected_length_hi
        jmp check_dcb_common
check_sized_dcb:
        sta expected_dstats
check_dcb_common:
        lda $0300
        cmp #$7f
        bne bad
        txa
        cmp $0302
        bne bad
        lda expected_dstats
        cmp $0303
        bne bad
        lda $0308
        cmp expected_length_lo
        bne bad
        lda $0309
        cmp expected_length_hi
        bne bad
        cpx #'P'
        beq fixed_poll
        cpx #'Q'
        beq fixed_poll
        lda $030a
        cmp expected_length_lo
        bne bad
        lda $030b
        cmp expected_length_hi
        bne bad
        rts
fixed_poll:
        lda $030a
        bne bad
        lda $030b
        bne bad
        rts
bad:    lda failure
        bne @done
        lda #1
        sta failure
@done:
        rts

set_large_context:
        lda #<request_large
        sta __fn_transport_ctx
        lda #>request_large
        sta __fn_transport_ctx+1
        lda #<response_large
        sta __fn_transport_ctx+2
        lda #>response_large
        sta __fn_transport_ctx+3
        lda #0
        sta __fn_transport_ctx+6
        lda #2
        sta __fn_transport_ctx+7
        rts

set_small_context:
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
        lda #0
        sta __fn_transport_ctx+5
        lda #8
        sta __fn_transport_ctx+6
        lda #0
        sta __fn_transport_ctx+7
        rts

; Record all delivered response bytes and the returned 16-bit length.  The
; three fixed locations keep the script assertions independent per bad-P case.
save_malformed_response_0:
        ldx #79
        jmp save_malformed_response
save_malformed_response_1:
        ldx #90
        jmp save_malformed_response
save_malformed_response_2:
        ldx #101
save_malformed_response:
        lda response
        sta _test_result,x
        inx
        lda response+1
        sta _test_result,x
        inx
        lda response+2
        sta _test_result,x
        inx
        lda response+3
        sta _test_result,x
        inx
        lda __fn_transport_ctx+8
        sta _test_result,x
        inx
        lda __fn_transport_ctx+9
        sta _test_result,x
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
        ; Caller supplies the response-length high byte.
        lda poll_length_high
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
        beq @timeout
        cmp #1
        beq @rejected
        cmp #2
        beq @interrupted
        cmp #3
        beq @capacity
        cmp #4
        bne :+
        jmp q_fake
:
        cmp #5
        bne :+
        jmp malformed_p_fake
:
        cmp #6
        bne :+
        jmp reset_idle_fake
:
        jmp bad
@timeout:
        jmp timeout_fake
@rejected:
        jmp rejected_fake
@interrupted:
        jmp interrupted_fake
@capacity:
        jmp capacity_fake
timeout_fake:
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
        sta poll_length_high
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
        sta poll_length_high
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
        sta poll_length_high
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
        sta poll_length_high
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

; Mode 2: W/P ready followed by a failed R.  The next exchange is accepted
; only as recovery P/R, then a new W/P/R transaction.
interrupted_fake:
        ldx step
        cpx #0
        bne :+
        jmp first_w
:
        cpx #1
        bne :+
        jmp interrupted_ready_p
:
        cpx #2
        bne :+
        jmp interrupted_r
:
        cpx #3
        bne :+
        jmp interrupted_recovery_p
:
        cpx #4
        bne :+
        jmp interrupted_recovery_r
:
        cpx #5
        bne :+
        jmp accepted_w
:
        cpx #6
        bne :+
        jmp accepted_p
:
        cpx #7
        bne :+
        jmp accepted_r
:
        jmp bad
interrupted_ready_p:
        ldx #'P'
        lda #$40
        jsr check_dcb
        lda #0
        sta poll_length_high
        lda #2
        ldx #4
        jsr put_poll
        inc step
        rts
interrupted_r:
        ldx #'R'
        lda #$40
        jsr check_dcb
        inc step
        lda #0
        sta $0303
        rts
interrupted_recovery_p:
        ldx #'P'
        lda #$40
        jsr check_dcb
        lda #0
        sta poll_length_high
        lda #2
        ldx #4
        jsr put_poll
        inc step
        rts
interrupted_recovery_r:
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

; Mode 3: exact 511/512-byte DCB transfers, local 513-byte request rejection,
; then a 513-byte reply that must remain outstanding without an R.
capacity_fake:
        ldx step
        cpx #0
        bne :+
        jmp capacity_w_511
:
        cpx #1
        bne :+
        jmp capacity_ready_512
:
        cpx #2
        bne :+
        jmp capacity_r_512
:
        cpx #3
        bne :+
        jmp capacity_w_512
:
        cpx #4
        bne :+
        jmp capacity_ready_512
:
        cpx #5
        bne :+
        jmp capacity_r_512
:
        cpx #6
        bne :+
        jmp capacity_w_oversized
:
        cpx #7
        bne :+
        jmp capacity_poll_oversized
:
        cpx #8
        bne :+
        jmp capacity_recover_oversized
:
        jmp bad
capacity_w_511:
        lda #$ff
        sta expected_length_lo
        lda #$01
        sta expected_length_hi
        ldx #'W'
        lda #$80
        jsr check_sized_dcb
        inc step
        lda #1
        sta $0303
        rts
capacity_w_512:
        lda #0
        sta expected_length_lo
        lda #2
        sta expected_length_hi
        ldx #'W'
        lda #$80
        jsr check_sized_dcb
        inc step
        lda #1
        sta $0303
        rts
capacity_ready_512:
        ldx #'P'
        lda #$40
        jsr check_dcb
        lda #2
        sta poll_length_high
        lda #2
        ldx #0
        jsr put_poll
        inc step
        rts
capacity_r_512:
        lda #0
        sta expected_length_lo
        lda #2
        sta expected_length_hi
        ldx #'R'
        lda #$40
        jsr check_sized_dcb
        jsr fill_512_reply
        inc step
        lda #1
        sta $0303
        rts
capacity_w_oversized:
        lda #0
        sta expected_length_lo
        lda #2
        sta expected_length_hi
        ldx #'W'
        lda #$80
        jsr check_sized_dcb
        inc step
        lda #1
        sta $0303
        rts
capacity_poll_oversized:
        ldx #'P'
        lda #$40
        jsr check_dcb
        lda #2
        sta poll_length_high
        lda #2
        ldx #1
        jsr put_poll
        inc step
        rts
capacity_recover_oversized:
        ldx #'P'
        lda #$40
        jsr check_dcb
        lda #2
        sta poll_length_high
        lda #2
        ldx #1
        jsr put_poll
        inc step
        rts

; Mode 5: no malformed P result may release an accepted W.  The fake peer
; returns the same bad P result for the complete local poll deadline, then
; insists on recovery P/R before accepting a new W.
malformed_p_fake:
        ldx step
        cpx #0
        bne :+
        jmp first_w
:
        cpx #61
        bcs :+
        jmp malformed_bad_p
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
        jmp accepted_w
:
        cpx #64
        bne :+
        jmp accepted_p
:
        cpx #65
        bne :+
        jmp accepted_r
:
        jmp bad
malformed_bad_p:
        ldx #'P'
        lda #$40
        jsr check_dcb
        lda malformed_kind
        beq malformed_unknown_p
        cmp #1
        beq malformed_zero_ready_p
        ; SIOV failure before a poll payload is received.
        inc step
        lda #0
        sta $0303
        rts
malformed_unknown_p:
        lda #0
        sta poll_length_high
        lda #3
        ldx #4
        jsr put_poll
        inc step
        rts
malformed_zero_ready_p:
        lda #0
        sta poll_length_high
        lda #2
        ldx #0
        jsr put_poll
        inc step
        rts

; Mode 6: a reset's P=idle releases the stale accepted W.  The idle response
; must be followed immediately by the new application's W, never an R for the
; reset-discarded response or a replay of the original request.
reset_idle_fake:
        ldx step
        cpx #0
        bne :+
        jmp reset_first_w
:
        cpx #61
        bcs :+
        jmp pending_p
:
        cpx #61
        bne :+
        jmp reset_idle_p
:
        cpx #62
        bne :+
        jmp reset_new_w
:
        cpx #63
        bne :+
        jmp accepted_p
:
        cpx #64
        bne :+
        jmp accepted_r
:
        jmp bad
reset_first_w:
        ldx #'W'
        lda #$80
        jsr check_dcb
        lda #$ff
        jsr check_w_payload
        inc step
        lda #1
        sta $0303
        rts
reset_idle_p:
        ldx #'P'
        lda #$40
        jsr check_dcb
        lda #0
        sta poll_length_high
        lda #0
        ldx #0
        jsr put_poll
        inc step
        rts
reset_new_w:
        ldx #'W'
        lda #$80
        jsr check_dcb
        lda #$fe
        jsr check_w_payload
        inc step
        lda #1
        sta $0303
        rts

; A=the expected fourth byte of the four-byte application W fixture.  This
; distinguishes the next application request from an accidental replay.
check_w_payload:
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
        lda (ptr1),y
        cmp #$fc
        beq :+
        jsr bad
:
        iny
        lda (ptr1),y
        cmp #$01
        beq :+
        jsr bad
:
        iny
        lda (ptr1),y
        cmp #$04
        beq :+
        jsr bad
:
        iny
        pla
        cmp (ptr1),y
        beq :+
        jsr bad
:
        lda saved_ptr1
        sta ptr1
        lda saved_ptr1+1
        sta ptr1+1
        rts

; Mode 4: explicit native Q discovery.  Any command other than the four
; fixture-defined Q calls reaches bad and leaves the sticky failure set.
q_fake:
        ldx step
        cpx #0
        bne :+
        jmp q_valid
:
        cpx #1
        bne :+
        jmp q_bad_revision
:
        cpx #2
        bne :+
        jmp q_small_capacity
:
        cpx #3
        bne :+
        jmp q_siov_failure
:
        jmp bad
q_valid:
        ldx #'Q'
        lda #$40
        jsr check_dcb
        lda #1
        sta q_reply
        lda #0
        sta q_reply+1
        lda #4
        sta q_reply+2
        lda #$a5
        sta q_reply+3
        jsr put_q_reply
        inc step
        lda #1
        sta $0303
        rts
q_bad_revision:
        ldx #'Q'
        lda #$40
        jsr check_dcb
        lda #2
        sta q_reply
        lda #0
        sta q_reply+1
        lda #2
        sta q_reply+2
        lda #$b2
        sta q_reply+3
        jsr put_q_reply
        inc step
        lda #1
        sta $0303
        rts
q_small_capacity:
        ldx #'Q'
        lda #$40
        jsr check_dcb
        lda #1
        sta q_reply
        lda #$ff
        sta q_reply+1
        lda #1
        sta q_reply+2
        lda #$c3
        sta q_reply+3
        jsr put_q_reply
        inc step
        lda #1
        sta $0303
        rts
q_siov_failure:
        ldx #'Q'
        lda #$40
        jsr check_dcb
        inc step
        lda #0
        sta $0303
        rts

; Write the four-byte Q fixture through the DCB buffer and preserve the
; production transport's zero-page scratch pointer.
put_q_reply:
        lda ptr1
        sta saved_ptr1
        lda ptr1+1
        sta saved_ptr1+1
        lda $0304
        sta ptr1
        lda $0305
        sta ptr1+1
        ldy #0
        lda q_reply
        sta (ptr1),y
        iny
        lda q_reply+1
        sta (ptr1),y
        iny
        lda q_reply+2
        sta (ptr1),y
        iny
        lda q_reply+3
        sta (ptr1),y
        lda saved_ptr1
        sta ptr1
        lda saved_ptr1+1
        sta ptr1+1
        rts

; Fill exactly two 256-byte pages with i ^ (i >> 8) ^ $a5 through the DCB
; buffer without changing the transport's zero-page request/response pointers.
fill_512_reply:
        lda ptr1
        sta saved_ptr1
        lda ptr1+1
        sta saved_ptr1+1
        lda $0304
        sta ptr1
        lda $0305
        sta ptr1+1
        ldy #0
@page_one:
        tya
        eor #$a5
        sta (ptr1),y
        iny
        bne @page_one
        inc ptr1+1
        ldy #0
@page_two:
        tya
        eor #$a4
        sta (ptr1),y
        iny
        bne @page_two
        lda saved_ptr1
        sta ptr1
        lda saved_ptr1+1
        sta ptr1+1
        rts

; Independently calculate the expected byte at every offset after the
; production R has completed.  Continue after mismatches so every byte is
; evaluated; pattern_failure is separate from the sticky DCB failure latch.
verify_512_reply:
        lda ptr1
        sta saved_ptr1
        lda ptr1+1
        sta saved_ptr1+1
        lda #<response_large
        sta ptr1
        lda #>response_large
        sta ptr1+1
        ldx #0
@page:
        ldy #0
@byte:
        tya
        eor #$a5
        cpx #0
        beq :+
        eor #1
:
        cmp (ptr1),y
        beq :+
        jsr pattern_bad
:
        iny
        bne @byte
        inc ptr1+1
        inx
        cpx #2
        bne @page
        lda saved_ptr1
        sta ptr1
        lda saved_ptr1+1
        sta ptr1+1
        rts
pattern_bad:
        lda pattern_failure
        bne :+
        lda #1
        sta pattern_failure
:
        rts

FN_ATARI_TEST_SIOV = fake_siov
        .include "../src/platform/atari/fn_transport.s"
