        .export _test_func, _test_result, __fn_transport_ctx
        .importzp ptr1, ptr2
        .segment "BSS"
__fn_transport_ctx: .res 10
request: .res 4
response: .res 8
step: .res 1
_test_result: .res 16
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
        jsr _fn_atari_query_capabilities
        sta _test_result+6
        jsr _fn_transport_exchange
        sta _test_result
        lda step
        sta _test_result+1
        lda $0300
        sta _test_result+2
        lda $0302
        sta _test_result+3
        lda $0308
        sta _test_result+4
        lda $030a
        sta _test_result+5
        rts
fake_siov:
        ldx step
        cpx #0
        beq query
        cpx #1
        beq write
        cpx #2
        beq poll
        cpx #3
        beq read
query:  ldy #0
        lda $0304
        sta ptr1
        lda $0305
        sta ptr1+1
        lda #1
        sta (ptr1),y
        iny
        lda #0
        sta (ptr1),y
        iny
        lda #2
        sta (ptr1),y
        iny
        lda #0
        sta (ptr1),y
        inc step
        lda #1
        sta $0303
        rts
write:
        inc step
        lda #1
        sta $0303
        rts
poll:   ldy #0
        lda $0304
        sta ptr1
        lda $0305
        sta ptr1+1
        lda #2
        sta (ptr1),y
        iny
        lda #4
        sta (ptr1),y
        iny
        lda #0
        sta (ptr1),y
        inc step
        lda #1
        sta $0303
        rts
read:   inc step
        lda #1
        sta $0303
        rts
FN_ATARI_TEST_SIOV = fake_siov
        .include "../src/platform/atari/fn_transport.s"
