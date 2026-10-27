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
; The sum is the byte-wise end-around-carry sum: fn_checksum_fold's value for a seed of 0..255, where the
; carry out of each add is added into the next one. That is what the 6502's ADC does by itself, so the
; common case is one ADC (10 cycles a byte); the general loop below handles a seed over 255, which only
; the fold's own tests use.
;
; fast_sum: A = seed (0..255), fn_core_ptr, fn_core_len. Returns A = the sum, X = 0.
; Clobbers Y, fn_core_ptr+1 and fn_core_len.
fast_sum:
    ldy #0
    ldx fn_core_len+1
    clc                     ; (CLC leaves Z from the LDX)
    beq tail
page:
    adc (fn_core_ptr),y
    iny
    bne page
    inc fn_core_ptr+1
    dex
    bne page
tail:
    ldx fn_core_len
    beq fs_done
byte:
    adc (fn_core_ptr),y
    iny
    dex
    bne byte
fs_done:
    adc #0                  ; the carry of the last add
    ldx #0
    rts

; The packet checksum skips the checksum byte (offset 4); a packet of 4 bytes or fewer is summed whole.
fn_asm_packet_checksum:
    lda fn_core_len+1
    bne packet_long
    lda fn_core_len
    cmp #5
    bcs packet_long
    lda #0
    jmp fast_sum
packet_long:
    lda fn_core_len         ; the bytes after the checksum byte: len - 5
    sec
    sbc #5
    sta sum
    lda fn_core_len+1
    sbc #0
    sta sum+1
    lda #4
    sta fn_core_len
    lda #0
    sta fn_core_len+1
    jsr fast_sum            ; offsets 0..3
    sta skip
    lda fn_core_ptr
    clc
    adc #5
    sta fn_core_ptr
    bcc :+
    inc fn_core_ptr+1
:   lda sum
    sta fn_core_len
    lda sum+1
    sta fn_core_len+1
    lda skip
    jmp fast_sum

fn_asm_checksum:
    cpx #0
    bne general
    jmp fast_sum
general:
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
