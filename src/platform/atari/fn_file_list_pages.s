; Atari ListPages client. The compact Atari transport is already synchronous
; and non-reentrant; this wrapper uses private zero-page pointers and BSS
; scratch across fn_raw_call, and does not introduce any other-target limits.
; Structure offsets are checked by fn_file_list_pages_layout.c.
        .export _fn_file_list_pages
        .import _fn_raw_call, _strlen, pusha, pushax, addysp
        .importzp c_sp
        .macpack longbranch

        .segment "ZEROPAGE"
lp_req:    .res 2
lp_out:    .res 2
lp_buf:    .res 2
lp_src:    .res 2
lp_dst:    .res 2

        .segment "BSS"
lp_uri_len: .res 2
lp_filter:  .res 2
lp_filter_len: .res 1
lp_cap:     .res 2
lp_length:  .res 2
lp_raw:     .res 3             ; fn_raw_response_t: status, u16 length

        .segment "CODE"
_fn_file_list_pages:
        ; out in AX; stack contains req, uri, io (two bytes each).
        sta lp_out
        stx lp_out+1
        ldy #0
        lda (c_sp),y
        sta lp_req
        iny
        lda (c_sp),y
        sta lp_req+1
        iny
        lda (c_sp),y
        sta lp_src
        iny
        lda (c_sp),y
        sta lp_src+1
        iny
        lda (c_sp),y
        sta lp_dst
        iny
        lda (c_sp),y
        sta lp_dst+1
        ; Save io->buffer and io->capacity.
        ldy #0
        lda (lp_dst),y
        sta lp_buf
        iny
        lda (lp_dst),y
        sta lp_buf+1
        iny
        lda (lp_dst),y
        sta lp_cap
        iny
        lda (lp_dst),y
        sta lp_cap+1
        lda lp_src
        ldx lp_src+1
        jsr _strlen
        sta lp_uri_len
        stx lp_uri_len+1
        ora lp_uri_len+1
        jeq invalid
        ldy #2
        lda (lp_req),y
        jeq invalid
        ldy #7
        lda (lp_req),y
        sta lp_filter
        iny
        lda (lp_req),y
        sta lp_filter+1
        ora lp_filter
        beq no_filter
        lda lp_filter
        ldx lp_filter+1
        jsr _strlen
        cpx #0
        jne invalid
        sta lp_filter_len
        jmp have_filter_len
no_filter:
        sta lp_filter_len
have_filter_len:
        ; Request must fit io->capacity. Match the portable C's conservative
        ; 12-byte fixed allowance, with one extra length byte when nonempty.
        lda #12
        ldx #0
        clc
        adc lp_filter_len
        bcc :+
        inx
:       ldy lp_filter_len
        beq :+
        clc
        adc #1
        bcc :+
        inx
:       sta lp_length
        stx lp_length+1
        sec
        lda lp_cap
        sbc lp_length
        tay
        lda lp_cap+1
        sbc lp_length+1
        jcc invalid
        tax
        tya
        cmp lp_uri_len
        txa
        sbc lp_uri_len+1
        jcc invalid

        lda lp_buf
        sta lp_dst
        lda lp_buf+1
        sta lp_dst+1
        lda #1
        jsr put_byte
        lda lp_uri_len
        jsr put_byte
        lda lp_uri_len+1
        jsr put_byte
        ; lp_src still points to the URI; _strlen does not alter it.
        jsr copy_string
        ; startPage, pageSize, maxPayload, flags, maxName: seven bytes.
        ldx #0
fields: txa
        tay
        lda (lp_req),y
        jsr put_byte
        inx
        cpx #7
        bne fields
        lda lp_filter_len
        beq call_device
        jsr put_byte
        lda lp_filter
        sta lp_src
        lda lp_filter+1
        sta lp_src+1
        jsr copy_string
call_device:
        sec
        lda lp_dst
        sbc lp_buf
        sta lp_length
        lda lp_dst+1
        sbc lp_buf+1
        sta lp_length+1
        ; fn_raw_call(device, command, buf, len, buf, capacity, &raw).
        lda #$fe
        jsr pusha
        lda #7
        jsr pusha
        lda lp_buf
        ldx lp_buf+1
        jsr pushax
        lda lp_length
        ldx lp_length+1
        jsr pushax
        lda lp_buf
        ldx lp_buf+1
        jsr pushax
        lda lp_cap
        ldx lp_cap+1
        jsr pushax
        lda #<lp_raw
        ldx #>lp_raw
        jsr _fn_raw_call
        cmp #0
        bne done
        lda lp_raw
        beq raw_ok
        cmp #9
        bcc done              ; protocol status 1..8 equals library error
        lda #$ff
        bne done
raw_ok: lda lp_raw+2
        bne length_ok
        lda lp_raw+1
        cmp #12
        bcc io_error
length_ok:
        ldy #0
        lda (lp_buf),y
        cmp #1
        bne io_error
        ; Reply flags, total, startPage, pageSize, pageCount -> out[0..8].
        ldy #1
        lda (lp_buf),y
        ldy #0
        sta (lp_out),y
        ldx #4
        ldy #1
copy_reply:
        txa
        pha
        tay
        lda (lp_buf),y
        pha
        txa
        sec
        sbc #3
        tay
        pla
        sta (lp_out),y
        pla
        tax
        inx
        cpx #12
        bne copy_reply
        ldy #9
        clc
        lda lp_buf
        adc #12
        sta (lp_out),y
        iny
        lda lp_buf+1
        adc #0
        sta (lp_out),y
        iny
        sec
        lda lp_raw+1
        sbc #12
        sta (lp_out),y
        iny
        lda lp_raw+2
        sbc #0
        sta (lp_out),y
        lda #0
        beq done
io_error:
        lda #5
        bne done
invalid:
        lda #2
done:   ldx #0
        ldy #6                ; pop caller's three stacked pointer arguments
        jmp addysp

; put_byte advances lp_dst, preserving X. copy_string advances lp_src.
put_byte:
        ldy #0
        sta (lp_dst),y
        inc lp_dst
        bne :+
        inc lp_dst+1
:       rts
copy_string:
        ldy #0
        lda (lp_src),y
        beq :+
        jsr put_byte
        inc lp_src
        bne copy_string
        inc lp_src+1
        jmp copy_string
:       rts
