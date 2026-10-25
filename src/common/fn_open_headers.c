#include <string.h>

#include "fn_internal.h"
#include "fn_platform.h"

/* Own file so programs that only call fn_open() don't link the header
   packet builder. */

static uint16_t put_u16(uint8_t *buffer, uint16_t offset, uint16_t value)
{
    buffer[offset++] = (uint8_t)(value & 0xFF);
    buffer[offset++] = (uint8_t)(value >> 8);
    return offset;
}

static uint16_t put_string(uint8_t *buffer, uint16_t offset, const char *s)
{
    uint16_t len;

    len = (uint16_t)strlen(s);
    offset = put_u16(buffer, offset, len);
    memcpy(buffer + offset, s, len);
    return (uint16_t)(offset + len);
}

uint8_t fn_open_headers(fn_handle_t *handle,
                        uint8_t method,
                        const char *url,
                        uint8_t flags,
                        const fn_header_t *headers,
                        uint8_t header_count,
                        uint32_t body_length)
{
    size_t total;
    size_t name_len;
    size_t value_len;
    uint16_t offset;
    uint8_t open_flags;
    uint8_t result;
    uint8_t i;

    result = fn_open_prepare(handle, url, flags, &open_flags);
    if (result != FN_OK) {
        return result;
    }
    if (header_count > 0 && headers == NULL) {
        return FN_ERR_INVALID;
    }

    /* Open: version, method, flags, url, header pairs, body length and an
       empty response-header list, all in one packet */
    total = FN_HEADER_SIZE + 3 + 2 + strlen(url) + 2 + 4 + 2;
    for (i = 0; i < header_count; ++i) {
        if (headers[i].name == NULL || headers[i].value == NULL) {
            return FN_ERR_INVALID;
        }
        name_len = strlen(headers[i].name);
        value_len = strlen(headers[i].value);
        if (name_len > FN_MAX_PACKET_SIZE || value_len > FN_MAX_PACKET_SIZE) {
            return FN_ERR_INVALID;
        }
        total += 4 + name_len + value_len;
        if (total > FN_MAX_PACKET_SIZE) {
            return FN_ERR_INVALID;
        }
    }
    if (total > FN_MAX_PACKET_SIZE) {
        return FN_ERR_INVALID;
    }

    offset = fn_build_header(_fn_req_buf, FN_DEVICE_NETWORK, FN_CMD_OPEN, (uint16_t)total);
    _fn_req_buf[offset++] = FN_PROTOCOL_VERSION;
    _fn_req_buf[offset++] = method;
    _fn_req_buf[offset++] = open_flags;
    offset = put_string(_fn_req_buf, offset, url);
    offset = put_u16(_fn_req_buf, offset, header_count);
    for (i = 0; i < header_count; ++i) {
        offset = put_string(_fn_req_buf, offset, headers[i].name);
        offset = put_string(_fn_req_buf, offset, headers[i].value);
    }
    _fn_req_buf[offset++] = (uint8_t)(body_length & 0xFF);
    _fn_req_buf[offset++] = (uint8_t)((body_length >> 8) & 0xFF);
    _fn_req_buf[offset++] = (uint8_t)((body_length >> 16) & 0xFF);
    _fn_req_buf[offset++] = (uint8_t)((body_length >> 24) & 0xFF);
    offset = put_u16(_fn_req_buf, offset, 0);
    _fn_req_buf[FN_CHECKSUM_OFFSET] = fn_calc_packet_checksum(_fn_req_buf, offset);

    return fn_open_exchange(handle, offset);
}
