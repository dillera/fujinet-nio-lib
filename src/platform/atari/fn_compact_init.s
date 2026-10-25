.export _fn_init, _fn_is_ready
.import __fn_initialized, __fn_sessions
.import _fn_transport_init, _fn_transport_ready
.code
_fn_init:
    lda __fn_initialized
    beq first
    jsr _fn_transport_ready
    cmp #0
    bne ready
    jmp _fn_transport_init
first:
    lda #0
    sta __fn_sessions
    sta __fn_sessions+14
    jsr _fn_transport_init
    cmp #0
    bne done
    inc __fn_initialized
ready:
    lda #0
done:
    ldx #0
    rts
_fn_is_ready:
    jmp _fn_transport_ready
