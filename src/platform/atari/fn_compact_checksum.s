; Runtime-free checksum core. Shared scratch, synchronous/non-reentrant.
.export fn_asm_checksum, fn_asm_packet_checksum
.exportzp fn_core_ptr
.export fn_core_len
.segment "ZEROPAGE"
fn_core_ptr: .res 2
.bss
fn_core_len: .res 2
sum: .res 2
skip: .res 1
.code
fn_asm_packet_checksum:
    lda #5
    sta skip
    lda #0
    tax
    beq start
fn_asm_checksum:
    ldy #0
    sty skip
start:
    sta sum
    stx sum+1
loop:
    lda fn_core_len
    ora fn_core_len+1
    beq done
    lda skip
    beq add_byte
    dec skip
    beq advance
add_byte:
    ldy #0
    lda (fn_core_ptr),y
    clc
    adc sum
    sta sum
    lda sum+1
    adc #0
    clc
    adc sum
    sta sum
    lda #0
    adc #0
    sta sum+1
advance:
    inc fn_core_ptr
    bne :+
    inc fn_core_ptr+1
:
    lda fn_core_len
    bne :+
    dec fn_core_len+1
:
    dec fn_core_len
    jmp loop
done:
    lda sum
    ldx sum+1
    rts
