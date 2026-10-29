#include <string.h>
#include "fn_internal.h"

static uint16_t put_string(uint8_t *b, uint16_t at, const char *s)
{
    uint16_t n = (uint16_t)strlen(s);
    b[at++] = (uint8_t)n;
    b[at++] = (uint8_t)(n >> 8);
    memcpy(b + at, s, n);
    return (uint16_t)(at + n);
}

uint8_t fn_open_headers(fn_handle_t *handle, uint8_t method, const char *url,
                        uint8_t flags, const fn_http_header_t *headers,
                        uint16_t count, uint32_t body_len)
{
    uint8_t wire_flags, result;
    uint16_t i, at;
    uint32_t total;
    result = fn_open_prepare(handle, url, flags, &wire_flags);
    if (result != FN_OK) return result;
    if (count && !headers) return FN_ERR_INVALID;
    if (body_len && method != FN_METHOD_POST && method != FN_METHOD_PUT)
        return FN_ERR_INVALID;
    total = FN_HEADER_SIZE + 3u + 2u + strlen(url) + 2u + 4u + 2u;
    for (i = 0; i < count; ++i) {
        size_t key_len, value_len;
        if (!headers[i].name || !headers[i].value || !headers[i].name[0]) return FN_ERR_INVALID;
        key_len = strlen(headers[i].name);
        value_len = strlen(headers[i].value);
        if (key_len > FN_MAX_PACKET_SIZE || value_len > FN_MAX_PACKET_SIZE) return FN_ERR_INVALID;
        total += 4u + key_len + value_len;
        if (total > FN_MAX_PACKET_SIZE) return FN_ERR_INVALID;
    }
    if (total > FN_MAX_PACKET_SIZE) return FN_ERR_INVALID;
    at = fn_build_header(_fn_req_buf, FN_DEVICE_NETWORK, FN_CMD_OPEN, (uint16_t)total);
    _fn_req_buf[at++] = FN_PROTOCOL_VERSION;
    _fn_req_buf[at++] = method;
    _fn_req_buf[at++] = wire_flags;
    at = put_string(_fn_req_buf, at, url);
    _fn_req_buf[at++] = (uint8_t)count;
    _fn_req_buf[at++] = (uint8_t)(count >> 8);
    for (i = 0; i < count; ++i) {
        at = put_string(_fn_req_buf, at, headers[i].name);
        at = put_string(_fn_req_buf, at, headers[i].value);
    }
    for (i = 0; i < 4; ++i) {
        _fn_req_buf[at++] = (uint8_t)body_len;
        body_len >>= 8;
    }
    _fn_req_buf[at++] = 0;
    _fn_req_buf[at++] = 0;
    _fn_req_buf[FN_CHECKSUM_OFFSET] = fn_calc_packet_checksum(_fn_req_buf, at);
    return fn_open_exchange(handle, at);
}
