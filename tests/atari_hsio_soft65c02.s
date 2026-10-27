; fn_hsio.s enable/disable under a fixture SIOV. The engine itself drives POKEY and is not run here;
; this checks what the library decides: the 3F query as sent, which answers enable accepts, and that the
; SIO vector moves to the driver and back.
        .export _test_func, _test_result, __fn_transport_ctx, __fn_resp_buf
        .export fake_siov
 .ifndef FN_ATARI_COMPACT
        .importzp ptr1, ptr2
 .endif
        .import _fn_atari_hsio_enable, _fn_atari_hsio_disable, _fn_atari_hsio_index
        .segment "BSS"
__fn_transport_ctx: .res 10
__fn_resp_buf: .res 512
reply_byte: .res 1
reply_status: .res 1
seen_device: .res 1
seen_unit: .res 1
seen_command: .res 1
seen_dstats: .res 1
seen_dbytlo: .res 1
seen_dbythi: .res 1
calls: .res 1
default_lo: .res 1
default_hi: .res 1
_test_result: .res 32
        .segment "CODE"
_test_func:
        jsr _fn_transport_init
        lda fn_sio_vec
        sta default_lo
        lda fn_sio_vec+1
        sta default_hi
        lda #0
        sta calls

        ; Off at the start.
        jsr _fn_atari_hsio_index
        sta _test_result+0                      ; $FF

        ; The firmware answers index 6.
        lda #6
        sta reply_byte
        lda #1
        sta reply_status
        jsr _fn_atari_hsio_enable
        sta _test_result+1                      ; FN_OK
        jsr _fn_atari_hsio_index
        sta _test_result+2                      ; 6
        lda seen_device
        sta _test_result+3                      ; $7F
        lda seen_unit
        sta _test_result+4                      ; 1
        lda seen_command
        sta _test_result+5                      ; $3F
        lda seen_dstats
        sta _test_result+6                      ; $40: a read
        lda seen_dbytlo
        sta _test_result+7                      ; 1 byte
        lda seen_dbythi
        sta _test_result+8                      ; 0
        lda calls
        sta _test_result+9                      ; one SIOV call, through the OS
        ; The vector moved off the OS SIO.
        lda fn_sio_vec
        cmp default_lo
        bne @moved
        lda fn_sio_vec+1
        cmp default_hi
        bne @moved
        lda #0
        beq @store_moved
@moved: lda #1
@store_moved:
        sta _test_result+10                     ; 1

        ; Disable: back to the OS SIO.
        jsr _fn_atari_hsio_disable
        jsr _fn_atari_hsio_index
        sta _test_result+11                     ; $FF
        lda fn_sio_vec
        cmp default_lo
        bne @bad_back
        lda fn_sio_vec+1
        cmp default_hi
        bne @bad_back
        lda #1
        bne @store_back
@bad_back: lda #0
@store_back:
        sta _test_result+12                     ; 1

        ; A NAK (no index set on the FujiNet): unsupported, nothing changes.
        lda #$8b
        sta reply_status
        jsr _fn_atari_hsio_enable
        sta _test_result+13                     ; FN_ERR_UNSUPPORTED
        jsr _fn_atari_hsio_index
        sta _test_result+14                     ; $FF
        lda fn_sio_vec
        sta _test_result+15                     ; unchanged: low
        lda fn_sio_vec+1
        sta _test_result+16

        ; $0A is read by drivers as a Happy 1050: not accepted.
        lda #1
        sta reply_status
        lda #10
        sta reply_byte
        jsr _fn_atari_hsio_enable
        sta _test_result+17                     ; FN_ERR_UNSUPPORTED
        jsr _fn_atari_hsio_index
        sta _test_result+18                     ; $FF

        ; 9 is the highest index offered.
        lda #9
        sta reply_byte
        jsr _fn_atari_hsio_enable
        sta _test_result+19                     ; FN_OK
        jsr _fn_atari_hsio_index
        sta _test_result+20                     ; 9
        jsr _fn_atari_hsio_disable

        ; Divisor 0 is a real index (about 124 kbaud), not "off".
        lda #0
        sta reply_byte
        jsr _fn_atari_hsio_enable
        sta _test_result+21                     ; FN_OK
        jsr _fn_atari_hsio_index
        sta _test_result+22                     ; 0
        jsr _fn_atari_hsio_disable
        lda calls
        sta _test_result+23                     ; 5 queries in all
        rts

; The OS SIO as the library sees it here: record the DCB, return the configured answer.
fake_siov:
        inc calls
        lda $0300
        sta seen_device
        lda $0301
        sta seen_unit
        lda $0302
        sta seen_command
        lda $0303
        sta seen_dstats
        lda $0308
        sta seen_dbytlo
        lda $0309
        sta seen_dbythi
        lda $0304               ; the DCB buffer: one reply byte
        sta ptr2
        lda $0305
        sta ptr2+1
        ldy #0
        lda reply_byte
        sta (ptr2),y
        lda reply_status
        sta $0303
        rts

FN_ATARI_TEST_SIOV = fake_siov
        .include "../src/platform/atari/fn_transport.s"
