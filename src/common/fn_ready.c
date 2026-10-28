#include "fn_internal.h"
#include "fn_platform.h"

/* Ready (0x08): which of this client's sessions can be read or queried now.
 * Response payload: version, flags, reserved u16, count u8, then count x { handle u16, ready u8, available u16 }. */
#define FN_READY_HEADER_BYTES 5
#define FN_READY_ENTRY_BYTES  5

uint8_t fn_ready(fn_ready_entry_t *entries, uint8_t max_entries, uint8_t *count)
{
    uint16_t req_len;
    uint16_t base;
    uint8_t result;
    uint8_t listed;
    uint8_t stored;
    uint8_t i;
    const uint8_t *entry;

    if (!_fn_initialized) {
        return FN_ERR_INVALID;
    }
    if (count == NULL || (entries == NULL && max_entries != 0)) {
        return FN_ERR_INVALID;
    }

    req_len = fn_build_ready_packet(_fn_req_buf);
    if (req_len == 0) {
        return FN_ERR_INVALID;
    }

    _fn_transport_ctx.request = _fn_req_buf;
    _fn_transport_ctx.req_len = req_len;
    _fn_transport_ctx.response = _fn_resp_buf;
    _fn_transport_ctx.resp_max = FN_MAX_PACKET_SIZE;

    result = fn_transport_exchange();
    if (result != FN_OK) {
        return result;
    }

    _fn_parse_ctx.response = _fn_resp_buf;
    _fn_parse_ctx.resp_len = _fn_transport_ctx.resp_len;
    result = fn_parse_response_header();
    if (result != FN_OK) {
        return result;
    }
    if (_fn_parse_ctx.status != FN_OK) {
        return _fn_parse_ctx.status;   /* FN_ERR_UNSUPPORTED from firmware without the command */
    }
    if (_fn_parse_ctx.data_len < FN_READY_HEADER_BYTES) {
        return FN_ERR_INVALID;
    }

    base = _fn_parse_ctx.data_offset;
    listed = _fn_resp_buf[base + 4];
    if ((uint16_t)_fn_parse_ctx.data_len <
        (uint16_t)(FN_READY_HEADER_BYTES + (uint16_t)listed * FN_READY_ENTRY_BYTES)) {
        return FN_ERR_INVALID;
    }

    stored = listed < max_entries ? listed : max_entries;
    entry = _fn_resp_buf + base + FN_READY_HEADER_BYTES;
    for (i = 0; i < stored; ++i) {
        entries[i].handle = FN_READ_LE16(entry, 0);
        entries[i].flags = entry[2];
        entries[i].available = FN_READ_LE16(entry, 3);
        entry += FN_READY_ENTRY_BYTES;
    }
    *count = stored;
    return FN_OK;
}
