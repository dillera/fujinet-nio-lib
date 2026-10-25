.export _fn_checksum_fold, _fn_calc_checksum, _fn_calc_packet_checksum
.import fn_asm_checksum, fn_asm_packet_checksum, fn_core_len
.importzp fn_core_ptr
.import popax
.bss
seed: .res 2
.code
_fn_checksum_fold:
    sta seed
    stx seed+1
    jsr popax
    jsr arguments
    lda seed
    ldx seed+1
    jmp fn_asm_checksum
_fn_calc_checksum:
    jsr arguments
    lda #0
    tax
    jmp fn_asm_checksum
_fn_calc_packet_checksum:
    jsr arguments
    jmp fn_asm_packet_checksum
arguments:
    sta fn_core_len
    stx fn_core_len+1
    jsr popax
    sta fn_core_ptr
    stx fn_core_ptr+1
    rts
