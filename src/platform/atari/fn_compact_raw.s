; Parameter block: device, command, payload*, length, reply*, capacity, response*.
; No C runtime or extra packet buffer. Disk's opposite-buffer alias is preserved.
.export fn_asm_raw_call, fn_raw_args
.import _fn_init, _fn_transport_exchange, _fn_parse_response_header
.import __fn_initialized, __fn_req_buf, __fn_resp_buf
.import __fn_transport_ctx, __fn_parse_ctx
.import fn_asm_packet_checksum, fn_core_len
.importzp fn_core_ptr
.zeropage
dest: .res 2
.bss
fn_raw_args: .res 12
copy_len: .res 2
.code
fn_asm_raw_call:
    lda fn_raw_args+10
    sta dest
    lda fn_raw_args+11
    sta dest+1
    ora dest
    beq :+
    ldy #0
    lda #7
    sta (dest),y
    iny
    lda #0
    sta (dest),y
    iny
    sta (dest),y
:
    lda __fn_initialized
    bne :+
    jsr _fn_init
    cmp #0
    beq :+
    rts
:
    lda fn_raw_args+4
    ora fn_raw_args+5
    beq bounds
    lda fn_raw_args+2
    ora fn_raw_args+3
    beq invalid
bounds:
    lda fn_raw_args+5
    cmp #1
    bcc build
    bne invalid
    lda fn_raw_args+4
    cmp #251
    bcc build
invalid:
    lda #2
    ldx #0
    rts
build:
    lda fn_raw_args
    sta __fn_req_buf
    lda fn_raw_args+1
    sta __fn_req_buf+1
    lda fn_raw_args+4
    clc
    adc #6
    sta __fn_req_buf+2
    sta __fn_transport_ctx+4
    lda fn_raw_args+5
    adc #0
    sta __fn_req_buf+3
    sta __fn_transport_ctx+5
    lda #0
    sta __fn_req_buf+4
    sta __fn_req_buf+5
    lda fn_raw_args+2
    sta fn_core_ptr
    lda fn_raw_args+3
    sta fn_core_ptr+1
    lda #<(__fn_req_buf+6)
    sta dest
    lda #>(__fn_req_buf+6)
    sta dest+1
    lda fn_raw_args+4
    sta copy_len
    lda fn_raw_args+5
    sta copy_len+1
    jsr copy_bytes
    lda #<__fn_req_buf
    sta fn_core_ptr
    sta __fn_transport_ctx
    lda #>__fn_req_buf
    sta fn_core_ptr+1
    sta __fn_transport_ctx+1
    lda __fn_transport_ctx+4
    sta fn_core_len
    lda __fn_transport_ctx+5
    sta fn_core_len+1
    jsr fn_asm_packet_checksum
    sta __fn_req_buf+4
    lda #<__fn_resp_buf
    sta __fn_transport_ctx+2
    sta __fn_parse_ctx
    lda #>__fn_resp_buf
    sta __fn_transport_ctx+3
    sta __fn_parse_ctx+1
    lda #0
    sta __fn_transport_ctx+6
    sta __fn_transport_ctx+8
    sta __fn_transport_ctx+9
    lda #2
    sta __fn_transport_ctx+7
    jsr _fn_transport_exchange
    cmp #0
    beq :+
    jmp return
:
    lda __fn_transport_ctx+8
    sta __fn_parse_ctx+4
    lda __fn_transport_ctx+9
    sta __fn_parse_ctx+5
    bne identity
    lda __fn_transport_ctx+8
    cmp #6
    bcc io_error
identity:
    lda __fn_resp_buf
    cmp fn_raw_args
    bne io_error
    lda __fn_resp_buf+1
    cmp fn_raw_args+1
    bne io_error
    jsr _fn_parse_response_header
    cmp #0
    bne return
    lda fn_raw_args+8
    cmp __fn_parse_ctx+10
    lda fn_raw_args+9
    sbc __fn_parse_ctx+11
    bcc io_error
    lda fn_raw_args+6
    sta dest
    lda fn_raw_args+7
    sta dest+1
    ora dest
    beq metadata
    lda __fn_parse_ctx+10
    sta copy_len
    lda __fn_parse_ctx+11
    sta copy_len+1
    lda __fn_parse_ctx+8
    clc
    adc #<__fn_resp_buf
    sta fn_core_ptr
    lda __fn_parse_ctx+9
    adc #>__fn_resp_buf
    sta fn_core_ptr+1
    jsr copy_bytes
metadata:
    lda fn_raw_args+10
    sta dest
    lda fn_raw_args+11
    sta dest+1
    ora dest
    beq ok
    ldy #0
    lda __fn_parse_ctx+24
    sta (dest),y
    iny
    lda __fn_parse_ctx+10
    sta (dest),y
    iny
    lda __fn_parse_ctx+11
    sta (dest),y
ok:
    lda #0
return:
    ldx #0
    rts
io_error:
    lda #5
    bne return
copy_bytes:
    lda copy_len
    ora copy_len+1
    beq copy_done
    ldy #0
    lda (fn_core_ptr),y
    sta (dest),y
    inc fn_core_ptr
    bne :+
    inc fn_core_ptr+1
:
    inc dest
    bne :+
    inc dest+1
:
    lda copy_len
    bne :+
    dec copy_len+1
:
    dec copy_len
    jmp copy_bytes
copy_done:
    rts
