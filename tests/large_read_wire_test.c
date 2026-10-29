#include <stdio.h>
#include <string.h>
#include "fn_internal.h"
#include "fn_platform.h"

static unsigned calls;
static int second_busy, malformed, short_eof;
static uint16_t requested[4];
static uint32_t offsets[4];

uint8_t fn_transport_exchange(void)
{
    uint8_t *p = _fn_transport_ctx.response;
    const uint8_t *req = _fn_transport_ctx.request;
    uint16_t n = FN_READ_LE16(req, 13);
    uint32_t off = FN_READ_LE32(req, 9);
    uint16_t i, at;
    requested[calls] = n;
    offsets[calls++] = off;
    if (second_busy && calls == 2) return FN_ERR_NOT_READY;
    if (short_eof && n > 7) n = 7;
    at = fn_build_header(p, FN_DEVICE_NETWORK, FN_CMD_READ, (uint16_t)(FN_HEADER_SIZE + 12 + n));
    p[at++] = 1; p[at++] = short_eof ? FN_READ_EOF : 0; p[at++] = 0; p[at++] = 0;
    p[at++] = 0x34; p[at++] = 0x12;
    p[at++] = (uint8_t)off; p[at++] = (uint8_t)(off >> 8);
    p[at++] = (uint8_t)(off >> 16); p[at++] = (uint8_t)(off >> 24);
    p[at++] = (uint8_t)(n + (malformed ? 1 : 0)); p[at++] = (uint8_t)(n >> 8);
    for (i = 0; i < n; ++i) p[at++] = (uint8_t)(off + i);
    p[FN_CHECKSUM_OFFSET] = fn_calc_packet_checksum(p, at);
    _fn_transport_ctx.resp_len = at;
    return FN_OK;
}

int main(void)
{
    uint8_t out[1024], flags;
    uint16_t got, i;
    _fn_initialized = 1;
    _fn_sessions[0].active = 1;
    _fn_sessions[0].handle = 0x1234;
    _fn_sessions[0].proto_flags = FN_PROTO_FLAG_SEQUENTIAL_READ;
    if (fn_read(0x1234, 0, out, sizeof out, &got, &flags) != FN_OK || got != sizeof out || calls != 2 ||
        requested[0] != FN_MAX_PACKET_SIZE - 22 || offsets[1] != requested[0]) return 1;
    for (i = 0; i < got; ++i) if (out[i] != (uint8_t)i) return 2;
    calls = 0; second_busy = 1; _fn_sessions[0].read_offset = 0;
    if (fn_read(0x1234, 0, out, sizeof out, &got, &flags) != FN_OK || got != requested[0] || calls != 2) return 3;
    calls = 0; second_busy = 0; malformed = 1; _fn_sessions[0].read_offset = 0;
    if (fn_read(0x1234, 0, out, 10, &got, &flags) != FN_ERR_INVALID || got != 0) return 4;
    calls = 0; malformed = 0; short_eof = 1; _fn_sessions[0].read_offset = 0;
    if (fn_read(0x1234, 0, out, sizeof out, &got, &flags) != FN_OK || got != 7 ||
        calls != 1 || !(flags & FN_READ_EOF)) return 5;
    puts("large read wire tests passed");
    return 0;
}
