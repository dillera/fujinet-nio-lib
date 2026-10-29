/* Black-box protocol vectors. The mock checks independently specified request
 * bytes before returning a canned response; it does not call the C encoder. */
#include <stdint.h>
#include <string.h>
#include "../include/fujinet-nio.h"
#include "../include/fn_raw.h"

uint8_t test_case, test_result, test_seen;
static uint8_t raw_calls, raw_bad;
static uint8_t guarded[514], filter[257];
#define wirebuf (guarded + 1)
static char long_uri[301];
static fn_file_io_t io;
static fn_list_pages_req_t req;
static fn_list_pages_t out;

static const uint8_t plain_wire[] = {
    1, 3, 0, 'a', ':', '/', 5, 0, 9, 0xe0, 1, 3, 31
};
static const uint8_t filter_wire[] = {
    1, 3, 0, 'a', ':', '/', 5, 0, 9, 0xe0, 1, 3, 31,
    5, 'm', 'i', 'n', 'e', 'r'
};
static const uint8_t canned_reply[] = {
    1, 3, 0, 0, 0x78, 0x56, 0x34, 0x12, 5, 0, 9, 1,
    1, 11, 0, 0, 1, 'x', 7, 0, 0, 0, 9, 0, 0, 0
};

uint8_t fn_raw_call(uint8_t device, uint8_t command, const void *payload,
                    uint16_t len, void *reply, uint16_t capacity,
                    fn_raw_response_t *response)
{
    const uint8_t filtered = test_case == 1 || test_case == 23 || test_case == 24;
    const uint8_t *expected = filtered ? filter_wire : plain_wire;
    uint8_t expected_len = filtered ? sizeof(filter_wire) : sizeof(plain_wire);
    ++raw_calls;
    if (device != 0xfe || command != 7 || capacity != io.capacity || reply != io.buffer)
        raw_bad = 1;
    if (test_case == 19) {
        const uint8_t *wire = (const uint8_t *)payload;
        uint16_t i;
        if (len != 269 || memcmp(wire, plain_wire, sizeof(plain_wire)) || wire[13] != 255)
            raw_bad = 1;
        for (i = 14; i < 269; ++i) if (wire[i] != 'x') raw_bad = 1;
    } else if (test_case == 20) {
        const uint8_t *wire = (const uint8_t *)payload;
        uint16_t i;
        if (len != 310 || wire[0] != 1 || wire[1] != 44 || wire[2] != 1 ||
            memcmp(wire + 303, plain_wire + 6, 7)) raw_bad = 1;
        for (i = 3; i < 303; ++i) if (wire[i] != 'u') raw_bad = 1;
    } else if (len != expected_len || memcmp(payload, expected, expected_len)) {
        raw_bad = 1;
    }
    if (test_case == 7) return FN_ERR_TIMEOUT;
    if (test_case == 22 || test_case == 24) return FN_ERR_IO;
    response->status = (test_case >= 8 && test_case <= 16) ? (uint8_t)(test_case - 7) : 0;
    response->payload_length = test_case == 17 ? 11 :
                               test_case == 21 ? 300 : sizeof(canned_reply);
    memcpy(reply, canned_reply, sizeof(canned_reply));
    if (test_case == 21) memset((uint8_t *)reply + sizeof(canned_reply), 0x5a, 274);
    if (test_case == 18) ((uint8_t *)reply)[0] = 2;
    return FN_OK;
}

uint8_t profile_list_pages(fn_file_io_t *, const char *, const fn_list_pages_req_t *, fn_list_pages_t *);
int main(void) { return 0; }

void test_func(void)
{
    static const uint8_t status_map[] = {
        FN_ERR_NOT_FOUND, FN_ERR_INVALID, FN_ERR_BUSY, FN_ERR_NOT_READY,
        FN_ERR_IO, FN_ERR_TIMEOUT, FN_ERR_INTERNAL, FN_ERR_UNSUPPORTED, FN_ERR_UNKNOWN
    };
    const char *uri = "a:/";
    uint8_t result, expected = FN_OK, should_call = 1;
    uint16_t i;

    test_seen = test_case;
    raw_calls = raw_bad = 0;
    memset(guarded, 0xa5, sizeof(guarded));
    memset(&out, 0xa5, sizeof(out));
    io.buffer = wirebuf;
    io.capacity = 512;
    req.start_page = 5; req.page_size = 9; req.max_payload = 480;
    req.flags = 3; req.max_name = 31; req.filter = 0;
    if (test_case == 1) req.filter = "miner";
    if (test_case == 2) req.filter = "";
    if (test_case == 3) { uri = ""; expected = FN_ERR_INVALID; should_call = 0; }
    if (test_case == 4) { req.page_size = 0; expected = FN_ERR_INVALID; should_call = 0; }
    if (test_case == 5) { io.capacity = 14; expected = FN_ERR_INVALID; should_call = 0; }
    if (test_case == 6) {
        for (i = 0; i < 256; ++i) filter[i] = 'x';
        filter[256] = 0; req.filter = (const char *)filter;
        expected = FN_ERR_INVALID; should_call = 0;
    }
    if (test_case == 19) {
        for (i = 0; i < 255; ++i) filter[i] = 'x';
        filter[255] = 0; req.filter = (const char *)filter;
    }
    if (test_case == 20) {
        for (i = 0; i < 300; ++i) long_uri[i] = 'u';
        long_uri[300] = 0; uri = long_uri;
    }
    if (test_case == 22) { io.capacity = 15; expected = FN_ERR_IO; }
    if (test_case == 23) { io.capacity = 20; req.filter = "miner"; expected = FN_ERR_INVALID; should_call = 0; }
    if (test_case == 24) { io.capacity = 21; req.filter = "miner"; expected = FN_ERR_IO; }
    if (test_case == 7) expected = FN_ERR_TIMEOUT;
    if (test_case >= 8 && test_case <= 16) expected = status_map[test_case - 8];
    if (test_case == 17 || test_case == 18) expected = FN_ERR_IO;
    result = profile_list_pages(&io, uri, &req, &out);
    if (result != expected || raw_calls != should_call || raw_bad) { test_result = 1; return; }
    if (result == FN_OK &&
        (out.flags != 3 || out.total != 0x12345678UL || out.start_page != 5 ||
         out.page_size != 9 || out.page_count != 1 || out.pages != wirebuf + 12 ||
         out.pages_len != (test_case == 21 ? 288 : 14) || memcmp(out.pages, canned_reply + 12, 14))) {
        test_result = 2; return;
    }
    if (test_case == 21 && (wirebuf[26] != 0x5a || wirebuf[299] != 0x5a)) { test_result = 4; return; }
    if (guarded[0] != 0xa5 || guarded[513] != 0xa5) { test_result = 5; return; }
    if (result != FN_OK) {
        for (i = 0; i < sizeof(out); ++i) {
            if (((uint8_t *)&out)[i] != 0xa5) { test_result = 3; return; }
        }
    }
    test_result = 0;
}
