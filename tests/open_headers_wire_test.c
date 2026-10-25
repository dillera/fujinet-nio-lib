#include <stdio.h>
#include <string.h>

#include "fn_internal.h"
#include "fn_platform.h"
#include "fn_protocol.h"
#include "fujinet-nio.h"

/* Drives fn_open_headers() through a fake transport that records the Open
 * request and plays back a successful reply. */

#define TEST_URL "http://h/x"
#define TEST_HANDLE 0x0201

static int failures;
static uint8_t sent[FN_MAX_PACKET_SIZE];
static uint16_t sent_len;
static unsigned exchange_calls;
static uint8_t reply_flags;

#define CHECK(condition) \
    do { \
        if (!(condition)) { \
            printf("FAIL %s:%d %s\n", __FILE__, __LINE__, #condition); \
            ++failures; \
        } \
    } while (0)

uint8_t fn_transport_exchange(void)
{
    uint8_t *r = _fn_transport_ctx.response;
    uint16_t o;

    ++exchange_calls;
    sent_len = _fn_transport_ctx.req_len;
    memcpy(sent, _fn_transport_ctx.request, sent_len);
    o = fn_build_header(r, FN_DEVICE_NETWORK, FN_CMD_OPEN, FN_HEADER_SIZE + 7);
    r[o++] = FN_PROTOCOL_VERSION;
    r[o++] = reply_flags;
    r[o++] = 0;
    r[o++] = 0;
    r[o++] = (uint8_t)(TEST_HANDLE & 0xFF);
    r[o++] = (uint8_t)(TEST_HANDLE >> 8);
    r[o++] = 0;
    r[FN_CHECKSUM_OFFSET] = fn_calc_packet_checksum(r, o);
    _fn_transport_ctx.resp_len = o;
    return FN_OK;
}

static void reset(void)
{
    memset(_fn_sessions, 0, sizeof _fn_sessions);
    _fn_initialized = 1;
    exchange_calls = 0;
    sent_len = 0;
    reply_flags = 0x01;
}

static uint16_t put_lp(uint8_t *out, uint16_t o, const char *s)
{
    uint16_t n = (uint16_t)strlen(s);

    out[o++] = (uint8_t)(n & 0xFF);
    out[o++] = (uint8_t)(n >> 8);
    memcpy(out + o, s, n);
    return (uint16_t)(o + n);
}

static void test_headers_and_body(void)
{
    static const fn_header_t headers[] = {
        { "Authorization", "Bearer t0k" },
        { "Content-Type", "application/json" },
    };
    uint8_t want[FN_MAX_PACKET_SIZE];
    uint16_t o;
    fn_handle_t handle = FN_INVALID_HANDLE;

    reset();
    reply_flags = 0x01 | FN_OPEN_RESP_NEEDS_BODY;
    CHECK(fn_open_headers(&handle, FN_METHOD_POST, TEST_URL, 0, headers, 2, 0x01020304UL) == FN_OK);
    CHECK(handle == TEST_HANDLE);
    CHECK(exchange_calls == 1);
    CHECK(_fn_sessions[0].active && _fn_sessions[0].needs_body);

    o = FN_HEADER_SIZE;
    want[o++] = FN_PROTOCOL_VERSION;
    want[o++] = FN_METHOD_POST;
    want[o++] = 0;
    o = put_lp(want, o, TEST_URL);
    want[o++] = 2;
    want[o++] = 0;
    o = put_lp(want, o, "Authorization");
    o = put_lp(want, o, "Bearer t0k");
    o = put_lp(want, o, "Content-Type");
    o = put_lp(want, o, "application/json");
    want[o++] = 0x04;
    want[o++] = 0x03;
    want[o++] = 0x02;
    want[o++] = 0x01;
    want[o++] = 0;
    want[o++] = 0;
    fn_build_header(want, FN_DEVICE_NETWORK, FN_CMD_OPEN, o);
    want[FN_CHECKSUM_OFFSET] = fn_calc_packet_checksum(want, o);
    CHECK(sent_len == o);
    CHECK(memcmp(sent, want, o) == 0);
}

static void test_plain_matches_fn_open(void)
{
    uint8_t plain[FN_MAX_PACKET_SIZE];
    uint16_t plain_len;
    fn_handle_t handle;

    reset();
    plain_len = fn_build_open_packet(plain, FN_METHOD_GET, FN_OPEN_FLAG_FOLLOW_REDIR, TEST_URL);
    CHECK(fn_open_headers(&handle, FN_METHOD_GET, TEST_URL, FN_OPEN_FOLLOW_REDIR, NULL, 0, 0) == FN_OK);
    CHECK(sent_len == plain_len);
    CHECK(memcmp(sent, plain, plain_len) == 0);
}

static void test_rejected_before_sending(void)
{
    static char big[FN_MAX_PACKET_SIZE];
    fn_header_t header;
    fn_header_t missing = { "X-Empty", NULL };
    fn_handle_t handle;

    reset();
    CHECK(fn_open_headers(&handle, FN_METHOD_GET, TEST_URL, 0, NULL, 1, 0) == FN_ERR_INVALID);
    CHECK(fn_open_headers(&handle, FN_METHOD_GET, TEST_URL, 0, &missing, 1, 0) == FN_ERR_INVALID);
    memset(big, 'v', sizeof big - 1);
    header.name = "X-Big";
    header.value = big;
    CHECK(fn_open_headers(&handle, FN_METHOD_GET, TEST_URL, 0, &header, 1, 0) == FN_ERR_INVALID);
    CHECK(exchange_calls == 0);
    CHECK(!_fn_sessions[0].active);
}

int main(void)
{
    test_headers_and_body();
    test_plain_matches_fn_open();
    test_rejected_before_sending();
    if (failures) {
        printf("open_headers_wire_test: %d failure(s)\n", failures);
        return 1;
    }
    puts("open_headers_wire_test: OK");
    return 0;
}
