; Deliberately linked with ld65 and ONLY the production archive. No cc65 runtime,
; software stack, startup library, or alternate transport implementation.
.import fn_asm_raw_call, fn_raw_args
.import __BSS_RUN__, __BSS_SIZE__, __fn_req_buf, __fn_resp_buf
.zeropage
pointer: .res 2
.bss
reply: .res 4
metadata: .res 3
calls: .res 1
.segment "EXEHDR"
.byte "sim65",2,0,0
.word $2000,start
.segment "STARTUP"
start:
    cld
    ldx #$ff
    txs
    lda #<__BSS_RUN__
    sta pointer
    lda #>__BSS_RUN__
    sta pointer+1
    ldx #>(__BSS_SIZE__+255)
    lda #0
    ldy #0
@clear:
    sta (pointer),y
    iny
    bne @clear
    inc pointer+1
    dex
    bne @clear
    lda #$4c
    sta $e459
    lda #<siov
    sta $e45a
    lda #>siov
    sta $e45b
    ldx #11
@args:
    lda args,x
    sta fn_raw_args,x
    dex
    bpl @args
    jsr fn_asm_raw_call
    cmp #0
    beq :+
    jmp fail
:
    lda calls
    cmp #3
    beq :+
    jmp fail
:
    lda metadata
    beq :+
    jmp fail
:
    lda metadata+1
    cmp #2
    beq :+
    jmp fail
:
    lda metadata+2
    beq :+
    jmp fail
:
    lda reply
    cmp #$a1
    beq :+
    jmp fail
:
    lda reply+1
    cmp #$b2
    beq :+
    jmp fail
:
    ; Exercise the same opposite-buffer alias that Disk calls use.
    lda #<__fn_resp_buf
    sta fn_raw_args+2
    lda #>__fn_resp_buf
    sta fn_raw_args+3
    lda #$12
    sta __fn_resp_buf
    lda #$34
    sta __fn_resp_buf+1
    lda #<__fn_req_buf
    sta fn_raw_args+6
    lda #>__fn_req_buf
    sta fn_raw_args+7
    jsr fn_asm_raw_call
    cmp #0
    beq :+
    jmp fail
:
    lda __fn_req_buf
    cmp #$a1
    beq :+
    jmp fail
:
    lda __fn_req_buf+1
    cmp #$b2
    beq :+
    jmp fail
:
    lda #0
    jmp $fff9
fail:
    lda #1
    jmp $fff9
.code
siov:
    inc calls
    lda $0304
    sta pointer
    lda $0305
    sta pointer+1
    lda $0302
    cmp #'W'
    beq write
    cmp #'P'
    beq poll
    cmp #'R'
    beq :+
    jmp fail
:
    ldy #7
@response:
    lda response,y
    sta (pointer),y
    dey
    bpl @response
    bmi good
write:
    ldy #7
@check:
    lda request,y
    cmp (pointer),y
    beq :+
    jmp fail
:
    dey
    bpl @check
    bmi good
poll:
    ldy #0
    lda #2
    sta (pointer),y
    iny
    lda #8
    sta (pointer),y
    iny
    lda #0
    sta (pointer),y
good:
    lda #1
    sta $0303
    rts
.rodata
args: .byte $fc,$42
.word payload,2,reply,4,metadata
payload: .byte $12,$34
; End-around carry checksum skips offset4.
request: .byte $fc,$42,8,0,$8d,0,$12,$34
response: .byte $fc,$42,8,0,$9b,0,$a1,$b2
