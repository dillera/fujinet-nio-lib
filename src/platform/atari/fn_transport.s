; Packet-native Atari NIO transport (wire v1).  The public library supplies
; complete FujiBus packets; this target owns only the bounded 0x7f envelope.
        .export _fn_transport_init, _fn_transport_close, _fn_transport_ready
        .export _fn_transport_exchange, _fn_platform_name
        .export _fn_atari_last_sio_status, _fn_atari_proc_notify
        .export _fn_atari_query_capabilities, _fn_atari_max_payload
 .ifndef FN_ATARI_TEST_SIOV
        .import __fn_transport_ctx
 .endif
        .importzp ptr1, ptr2
        .include "atari.inc"

FN_OK = $00
FN_ERR_TIMEOUT = $06
FN_ERR_TRANSPORT = $10
SIO_OK = $01
NIO_DEVICE = $7f
NIO_CAPACITY = 512
SIO_TIMEOUT = 60
POLL_LIMIT = 60

.data
_platform_name: .byte "atari", 0
.bss
last_sio_status: .res 1
outstanding: .res 1
proc_ready: .res 1
capability_valid: .res 1
capability_max: .res 2
capability_reply: .res 4
poll_count: .res 1
reply_state: .res 3
reply_length: .res 2
discard_buffer: .res NIO_CAPACITY
.code

_fn_transport_init:
        lda #0
        sta outstanding
        sta proc_ready
        lda #<NIO_CAPACITY
        sta capability_max
        lda #>NIO_CAPACITY
        sta capability_max+1
        rts
_fn_transport_close: rts
_fn_transport_ready:
        lda #1
        rts
; ISR-safe latch only.  The application owns any VPRCED installation.
_fn_atari_proc_notify:
        lda #1
        sta proc_ready
        rts
; Explicit capability discovery; normal init/exchanges never call Q.
_fn_atari_query_capabilities:
        lda #4
        sta reply_length
        lda #0
        sta reply_length+1
        lda #$40
        sta dstats
        ldx #<capability_reply
        ldy #>capability_reply
        lda #'Q'
        jsr sio_call
        bne @bad
        lda capability_reply
        cmp #1
        bne @bad
        lda capability_reply+2
        cmp #2
        bcc @bad
        bne @good
        lda capability_reply+1
        beq @good
@bad:   lda #0
        sta capability_valid
        lda #<NIO_CAPACITY
        sta capability_max
        lda #>NIO_CAPACITY
        sta capability_max+1
        lda #FN_ERR_TRANSPORT
        rts
@good:  lda capability_reply+1
        sta capability_max
        lda capability_reply+2
        sta capability_max+1
        cmp #>NIO_CAPACITY
        bcc @cap_set
        bne @cap_limit
        lda capability_max
        beq @cap_set
@cap_limit:
        lda #<NIO_CAPACITY
        sta capability_max
        lda #>NIO_CAPACITY
        sta capability_max+1
@cap_set:
        lda #1
        sta capability_valid
        lda #FN_OK
        rts
_fn_atari_max_payload:
        lda capability_max
        ldx capability_max+1
        rts
_fn_atari_last_sio_status:
        lda last_sio_status
        rts
_fn_platform_name:
        lda #<_platform_name
        ldx #>_platform_name
        rts

; A=command, X/Y=buffer, reply_length=exact AUX/DCB byte count.
sio_call:
        sta dcomnd
        lda #NIO_DEVICE
        sta ddevic
        lda #1
        sta dunit
        stx dbuflo
        sty dbufhi
        lda reply_length
        sta dbytlo
        sta daux1
        lda reply_length+1
        sta dbythi
        sta daux2
        lda dcomnd
        cmp #'P'
        beq @fixed_aux
        cmp #'Q'
        bne @aux_done
@fixed_aux:
        lda #0
        sta daux1
        sta daux2
@aux_done:
        lda #SIO_TIMEOUT
        sta dtimlo
        lda #0
        sta dunuse
        jsr siov
        lda dstats
        sta last_sio_status
        cmp #SIO_OK
        rts

; Carry clear only for ready; idle releases an outstanding request only after
; the device has actually reported idle (for example, after reset).
nio_poll:
        lda #3
        sta reply_length
        lda #0
        sta reply_length+1
        lda #$40
        sta dstats
        ldx #<reply_state
        ldy #>reply_state
        lda #'P'
        jsr sio_call
        bne @poll_bad
        lda reply_state
        cmp #2
        beq @poll_ready
        cmp #1
        beq @poll_bad
        cmp #0
        bne @poll_bad
        lda #0
        sta outstanding
@poll_bad:
        sec
        rts
@poll_ready:
        lda reply_state+1
        sta reply_length
        lda reply_state+2
        sta reply_length+1
        lda reply_length
        ora reply_length+1
        beq @poll_bad
        clc
        rts
nio_read_reply:
        lda #$40
        sta dstats
        lda #'R'
        jsr sio_call
        rts

; Retire a timed-out transaction before another W. Failure preserves state.
nio_recover:
        lda #POLL_LIMIT
        sta poll_count
@recover_loop:
        jsr nio_poll
        bcc @recover_ready
        lda outstanding
        beq @recover_done
        dec poll_count
        bne @recover_loop
        lda #FN_ERR_TRANSPORT
        rts
@recover_ready:
        lda reply_length+1
        cmp #>NIO_CAPACITY
        bcc @recover_read
        bne @recover_fail
        lda reply_length
        beq @recover_read
@recover_fail:
        lda #FN_ERR_TRANSPORT
        rts
@recover_read:
        ldx #<discard_buffer
        ldy #>discard_buffer
        jsr nio_read_reply
        bne @recover_fail
        lda #0
        sta outstanding
@recover_done:
        lda #FN_OK
        rts

_fn_transport_exchange:
        ldy #0
        lda __fn_transport_ctx,y
        sta ptr1
        iny
        lda __fn_transport_ctx,y
        sta ptr1+1
        iny
        lda __fn_transport_ctx,y
        sta ptr2
        iny
        lda __fn_transport_ctx,y
        sta ptr2+1
        ldy #4
        lda __fn_transport_ctx,y
        sta reply_length
        iny
        lda __fn_transport_ctx,y
        sta reply_length+1
        cmp #>NIO_CAPACITY
        bcc @start
        bne @transport_error
        lda reply_length
        beq @start
@transport_error:
        lda #FN_ERR_TRANSPORT
        rts
@start:
        lda outstanding
        beq @send
        jsr nio_recover
        cmp #FN_OK
        bne @return
@send:
        lda #$80
        sta dstats
        ldx ptr1
        ldy ptr1+1
        lda #'W'
        jsr sio_call
        bne @transport_error
        lda #1
        sta outstanding
        lda #POLL_LIMIT
        sta poll_count
@wait:
        jsr nio_poll
        bcc @ready
        lda outstanding
        beq @transport_error
        dec poll_count
        bne @wait
        lda #FN_ERR_TIMEOUT
        rts
@ready:
        ldy #6
        lda __fn_transport_ctx,y
        sta ptr1
        iny
        lda __fn_transport_ctx,y
        sta ptr1+1
        lda reply_length+1
        cmp ptr1+1
        bcc @read
        bne @transport_error
        lda reply_length
        cmp ptr1
        bcc @read
        beq @read
        jmp @transport_error
@read:
        ldx ptr2
        ldy ptr2+1
        jsr nio_read_reply
        bne @transport_error
        ldy #8
        lda reply_length
        sta __fn_transport_ctx,y
        iny
        lda reply_length+1
        sta __fn_transport_ctx,y
        lda #0
        sta outstanding
        sta proc_ready
        lda #FN_OK
@return:
        rts
