; Full shared descriptor grammar, including chained descriptors and widths 1/2/4.
.export _fn_parse_response_header
.import __fn_parse_ctx, fn_asm_packet_checksum, fn_core_len
.importzp fn_core_ptr
.bss
cursor: .res 2
remaining: .res 2
.code
_fn_parse_response_header:
    lda __fn_parse_ctx+4
    sec
    sbc #6
    sta remaining
    lda __fn_parse_ctx+5
    sbc #0
    sta remaining+1
    bcs :+
    jmp invalid
:
    jsr response_pointer
    ldy #2
    lda (fn_core_ptr),y
    cmp __fn_parse_ctx+4
    beq :+
    jmp invalid
:
    iny
    lda (fn_core_ptr),y
    cmp __fn_parse_ctx+5
    beq :+
    jmp invalid
:
    lda __fn_parse_ctx+4
    sta fn_core_len
    lda __fn_parse_ctx+5
    sta fn_core_len+1
    jsr fn_asm_packet_checksum
    pha
    jsr response_pointer
    ldy #4
    pla
    cmp (fn_core_ptr),y
    bne io_error
    lda #0
    sta __fn_parse_ctx+24
    sta cursor+1
    lda #6
    sta cursor
    ldy #5
    lda (fn_core_ptr),y
chain:
    bpl fields
    jsr take_byte
    bcs invalid
    jmp chain
fields:
    and #7
    tax
    lda field_bytes,x
    beq success
    pha
    lda remaining+1
    bne :+
    lda remaining
    cmp field_width,x
    bcs :+
    pla
    jmp invalid
:
    pla
    tax
    ; Status is the low byte for every supported field width.
    jsr take_byte
    bcs invalid
    sta __fn_parse_ctx+24
    dex
    beq success
skip_fields:
    jsr take_byte
    bcs invalid
    dex
    bne skip_fields
success:
    lda cursor
    sta __fn_parse_ctx+8
    lda cursor+1
    sta __fn_parse_ctx+9
    lda remaining
    sta __fn_parse_ctx+10
    lda remaining+1
    sta __fn_parse_ctx+11
    lda #0
    tax
    rts
invalid:
    lda #2
    ldx #0
    rts
io_error:
    lda #5
    ldx #0
    rts
response_pointer:
    lda __fn_parse_ctx
    sta fn_core_ptr
    lda __fn_parse_ctx+1
    sta fn_core_ptr+1
    rts
; Consume at cursor, retaining the base pointer and X. Carry indicates EOF.
take_byte:
    lda remaining
    ora remaining+1
    beq eof
    lda remaining
    bne :+
    dec remaining+1
:
    dec remaining
    lda fn_core_ptr+1
    pha
    clc
    adc cursor+1
    sta fn_core_ptr+1
    ldy cursor
    lda (fn_core_ptr),y
    tay
    pla
    sta fn_core_ptr+1
    inc cursor
    bne :+
    inc cursor+1
:
    tya
    clc
    rts
eof:
    sec
    rts
.rodata
field_bytes: .byte 0,1,2,3,4,2,4,4
field_width: .byte 0,1,1,1,1,2,2,4
