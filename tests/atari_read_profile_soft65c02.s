; Cycle profile of fn_disk_read_sector (the real compact library) against a fixture SIOV.
; Not a pass/fail test: the script prints the cycle count at each mark. The marks:
;   call_start .. w_enter           building the request
;   w_exit .. p_enter, p_exit .. r_enter    the transport between the SIO calls
;   r_exit .. call_done             everything after the last byte of the response arrived
; which is what the Atari spends between the end of the FujiNet's reply and its next command.
        .export _test_func, _test_result
        .export fake_siov, results_stored, call_start, call_done, w_enter, w_exit, p_enter, p_exit, r_enter, r_exit
        .export checksum_start, checksum_done
        .import _fn_init, _fn_disk_read_sector, fn_sio_vec, fn_asm_packet_checksum, fn_core_len
        .import pusha, pushax, pusheax, __fn_req_buf
        .importzp fn_core_ptr, sreg
        .segment "BSS"
canned: .res 300
user_data: .res 512
user_length: .res 2
_test_result: .res 8
        .segment "CODE"
; Response packet: header (device, command, length, checksum, descriptor), a status byte, then the
; disk reply: version, 3 bytes, slot, lba (4), payload length (2), and 256 bytes of payload.
PACKET = 6 + 1 + 11 + 256
_test_func:
        lda #$FC
        sta canned
        lda #3
        sta canned+1
        lda #<PACKET
        sta canned+2
        lda #>PACKET
        sta canned+3
        lda #0
        sta canned+4
        lda #1                  ; descriptor: one 1-byte field (the status)
        sta canned+5
        lda #0
        sta canned+6            ; status OK
        lda #1
        sta canned+7            ; disk protocol version
        lda #0
        sta canned+8
        sta canned+9
        sta canned+10
        lda #1
        sta canned+11           ; slot 1
        lda #5
        sta canned+12           ; lba 5
        lda #0
        sta canned+13
        sta canned+14
        sta canned+15
        sta canned+16           ; payload length 256
        lda #1
        sta canned+17
        ldx #0
fill:   txa
        sta canned+18,x
        inx
        bne fill
        lda #<canned
        sta fn_core_ptr
        lda #>canned
        sta fn_core_ptr+1
        lda #<PACKET
        sta fn_core_len
        lda #>PACKET
        sta fn_core_len+1
checksum_start:
        jsr fn_asm_packet_checksum
checksum_done:
        sta canned+4
        jsr _fn_init
        lda #<(fake_siov-1)
        sta fn_sio_vec
        lda #>(fake_siov-1)
        sta fn_sio_vec+1
        ; fn_disk_read_sector(1, 5, user_data, 256, &user_length)
        lda #1
        jsr pusha
        lda #0
        sta sreg
        sta sreg+1
        lda #5
        ldx #0
        jsr pusheax
        lda #<user_data
        ldx #>user_data
        jsr pushax
        lda #<256
        ldx #>256
        jsr pushax
        lda #<user_length
        ldx #>user_length
call_start:
        jsr _fn_disk_read_sector
call_done:
        sta _test_result
        lda user_length
        sta _test_result+1
        lda user_length+1
        sta _test_result+2
        lda user_data+255
        sta _test_result+3
results_stored:
        rts

; DCB: $0302 command, $0303 status, $0304/5 buffer, $0308/9 byte count.
fake_siov:
        lda $0302
        cmp #'P'
        beq poll
        cmp #'R'
        beq read
w_enter:
        lda #1
        sta $0303
w_exit:
        rts
poll:
p_enter:
        lda $0304
        sta fn_core_ptr
        lda $0305
        sta fn_core_ptr+1
        ldy #0
        lda #2
        sta (fn_core_ptr),y
        iny
        lda #<PACKET
        sta (fn_core_ptr),y
        iny
        lda #>PACKET
        sta (fn_core_ptr),y
        lda #1
        sta $0303
p_exit:
        rts
read:
r_enter:
        lda $0304
        sta fn_core_ptr
        lda $0305
        sta fn_core_ptr+1
        ldy #0
rloop:  lda canned,y
        sta (fn_core_ptr),y
        iny
        bne rloop
        inc fn_core_ptr+1
        ldy #0
rtail:  lda canned+256,y
        sta (fn_core_ptr),y
        iny
        cpy #<(PACKET-256)
        bne rtail
        lda #1
        sta $0303
r_exit:
        rts
