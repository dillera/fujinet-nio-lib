; C fastcall adapters for the public packet helpers.
.export _fn_build_header, _fn_add_param
.import popax, popa, incsp5
.importzp c_sp
.importzp fn_core_ptr
.bss
length: .res 2
command: .res 1
device: .res 1
value: .res 2
size: .res 1
.code
_fn_build_header:
    sta length
    stx length+1
    jsr popa
    sta command
    jsr popa
    sta device
    jsr popax
    sta fn_core_ptr
    stx fn_core_ptr+1
    ldy #0
    lda device
    sta (fn_core_ptr),y
    iny
    lda command
    sta (fn_core_ptr),y
    iny
    lda length
    sta (fn_core_ptr),y
    iny
    lda length+1
    sta (fn_core_ptr),y
    iny
    lda #0
    sta (fn_core_ptr),y
    iny
    sta (fn_core_ptr),y
    lda #6
    ldx #0
    rts
_fn_add_param:
    sta size
    ldy #0
    lda (c_sp),y
    sta value
    iny
    lda (c_sp),y
    sta value+1
    ldy #4
    lda (c_sp),y
    sta length
    lda #0
    sta length+1
    asl length
    rol length+1
    asl length
    rol length+1
    jsr incsp5
    jsr popax
    clc
    adc length
    sta fn_core_ptr
    txa
    adc length+1
    sta fn_core_ptr+1
    ldy #0
    lda size
    sta (fn_core_ptr),y
    iny
    lda #0
    sta (fn_core_ptr),y
    iny
    lda value
    sta (fn_core_ptr),y
    iny
    lda value+1
    sta (fn_core_ptr),y
    lda #4
    ldx #0
    rts
