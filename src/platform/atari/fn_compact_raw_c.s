.export _fn_raw_call
.import fn_asm_raw_call, fn_raw_args, addysp
.importzp c_sp
.code
_fn_raw_call:
    sta fn_raw_args+10
    stx fn_raw_args+11
    ldy #9
    lda (c_sp),y
    sta fn_raw_args
    dey
    lda (c_sp),y
    sta fn_raw_args+1
    ldx #2
    ldy #6
copy:
    lda (c_sp),y
    sta fn_raw_args,x
    iny
    inx
    lda (c_sp),y
    sta fn_raw_args,x
    inx
    dey
    dey
    dey
    bpl copy
    jsr fn_asm_raw_call
    ldy #10
    jmp addysp
