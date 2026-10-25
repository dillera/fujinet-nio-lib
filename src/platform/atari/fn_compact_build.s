.export _fn_build_open_packet, _fn_build_read_packet, _fn_build_write_packet
.export _fn_build_close_packet, _fn_build_info_packet
.import popax, popa, fn_asm_packet_checksum, fn_core_len
.importzp fn_core_ptr
.zeropage
source: .res 2
buffer: .res 2
.bss
command: .res 1
length: .res 2
count: .res 2
handle: .res 2
position: .res 4
url_length: .res 1
method: .res 1
flags: .res 1
.code
_fn_build_open_packet:
    sta source
    stx source+1
    jsr popa
    sta flags
    jsr popa
    sta method
    jsr get_buffer
    ldy #0
@scan:
    lda (source),y
    beq @url_end
    iny
    cpy #129
    bne @scan
    lda #0
    tax
    rts
@url_end:
    sty url_length
    tya
    clc
    adc #19
    sta length
    lda #0
    sta length+1
    lda #1
    sta command
    jsr header
    ldy #7
    lda method
    sta (buffer),y
    iny
    lda flags
    sta (buffer),y
    iny
    lda url_length
    sta (buffer),y
    iny
    lda #0
    sta (buffer),y
    ldx #0
@url:
    cpx url_length
    beq @tail
    txa
    tay
    lda (source),y
    pha
    txa
    clc
    adc #11
    tay
    pla
    sta (buffer),y
    inx
    bne @url
@tail:
    txa
    clc
    adc #11
    tay
    ldx #8
    lda #0
@zero:
    sta (buffer),y
    iny
    dex
    bne @zero
    jmp checksum
_fn_build_close_packet:
    ldy #4
    bne misc
_fn_build_info_packet:
    ldy #5
misc:
    sty command
    sta handle
    stx handle+1
    jsr get_buffer
    lda #9
    sta length
    lda #0
    sta length+1
    jsr header_handle
    jmp checksum
_fn_build_read_packet:
    sta count
    stx count+1
    lda #2
    sta command
    jsr rw_arguments
    lda #15
    sta length
    lda #0
    sta length+1
    jsr rw_header
    jmp checksum
_fn_build_write_packet:
    sta count
    stx count+1
    jsr popax
    sta source
    stx source+1
    lda #3
    sta command
    jsr rw_arguments
    lda count
    clc
    adc #15
    sta length
    lda count+1
    adc #0
    sta length+1
    jsr rw_header
    lda source
    ora source+1
    bne @copy_start
    ; Original writes declared header length but returns/checksums 15 when
    ; data is NULL, even when data_len is nonzero.
    lda #15
    sta length
    lda #0
    sta length+1
    jmp checksum
@copy_start:
    lda buffer
    clc
    adc #15
    sta fn_core_ptr
    lda buffer+1
    adc #0
    sta fn_core_ptr+1
@copy:
    lda count
    ora count+1
    beq checksum
    ldy #0
    lda (source),y
    sta (fn_core_ptr),y
    inc source
    bne :+
    inc source+1
:
    inc fn_core_ptr
    bne :+
    inc fn_core_ptr+1
:
    lda count
    bne :+
    dec count+1
:
    dec count
    jmp @copy
checksum:
    lda buffer
    sta fn_core_ptr
    lda buffer+1
    sta fn_core_ptr+1
    lda length
    sta fn_core_len
    lda length+1
    sta fn_core_len+1
    jsr fn_asm_packet_checksum
    ldy #4
    sta (buffer),y
    lda length
    ldx length+1
    rts
get_buffer:
    jsr popax
    sta buffer
    stx buffer+1
    rts
rw_arguments:
    jsr popax
    sta position
    stx position+1
    jsr popax
    sta position+2
    stx position+3
    jsr popax
    sta handle
    stx handle+1
    jmp get_buffer
rw_header:
    jsr header_handle
    ldy #9
    ldx #0
@position:
    lda position,x
    sta (buffer),y
    iny
    inx
    cpx #4
    bne @position
    lda count
    sta (buffer),y
    iny
    lda count+1
    sta (buffer),y
    rts
header_handle:
    jsr header
    ldy #7
    lda handle
    sta (buffer),y
    iny
    lda handle+1
    sta (buffer),y
    rts
header:
    ldy #0
    lda #$fd
    sta (buffer),y
    iny
    lda command
    sta (buffer),y
    iny
    lda length
    sta (buffer),y
    iny
    lda length+1
    sta (buffer),y
    iny
    lda #0
    sta (buffer),y
    iny
    sta (buffer),y
    iny
    lda #1
    sta (buffer),y
    rts
