#include <stdio.h>
#include "fn_internal.h"
#include "fn_platform.h"
#include "fn_raw.h"

enum {
    MODE_TRANSPORT_ERROR,
    MODE_TRUNCATED,
    MODE_MALFORMED_LENGTH,
    MODE_MISMATCHED_IDENTITY,
    MODE_CORRUPT_CHECKSUM,
    MODE_INSUFFICIENT_CAPACITY,
    MODE_SUCCESS
};
static uint8_t mode;
static uint8_t exchanges;

uint8_t fn_transport_init(void) { return FN_OK; }
void fn_transport_close(void) {}
uint8_t fn_transport_ready(void) { return 1; }

static void complete_response(uint8_t device, uint8_t command, uint8_t data)
{
    fn_build_header(_fn_resp_buf, device, command, (uint16_t)(FN_HEADER_SIZE + 1));
    _fn_resp_buf[FN_HEADER_SIZE] = data;
    _fn_resp_buf[FN_CHECKSUM_OFFSET] =
        fn_calc_packet_checksum(_fn_resp_buf, (uint16_t)(FN_HEADER_SIZE + 1));
    _fn_transport_ctx.resp_len = (uint16_t)(FN_HEADER_SIZE + 1);
}

uint8_t fn_transport_exchange(void)
{
    exchanges++;
    if (mode == MODE_TRANSPORT_ERROR) return FN_ERR_TRANSPORT;
    if (mode == MODE_TRUNCATED) {
        _fn_transport_ctx.resp_len = 0;
        return FN_OK;
    }
    complete_response(mode == MODE_MISMATCHED_IDENTITY ? FN_DEVICE_CLOCK :
                      _fn_req_buf[0], _fn_req_buf[1], 0x42);
    if (mode == MODE_MALFORMED_LENGTH) {
        _fn_resp_buf[2]++;
        _fn_resp_buf[FN_CHECKSUM_OFFSET] =
            fn_calc_packet_checksum(_fn_resp_buf, (uint16_t)(FN_HEADER_SIZE + 1));
    }
    if (mode == MODE_CORRUPT_CHECKSUM)
        _fn_resp_buf[FN_CHECKSUM_OFFSET] ^= 1;
    return FN_OK;
}

static int expect_one_exchange(uint8_t selected_mode, uint16_t reply_capacity,
                               uint8_t expected_result)
{
    fn_raw_response_t response;
    uint8_t request = 0x24;
    uint8_t reply = 0;

    _fn_initialized = 1;
    mode = selected_mode;
    exchanges = 0;
    if (fn_raw_call(FN_DEVICE_FILE, 4, &request, 1, &reply, reply_capacity,
                    &response) != expected_result)
        return 1;
    return exchanges != 1;
}

static int test_uncertain_failures_are_not_replayed(void)
{
    if (expect_one_exchange(MODE_TRANSPORT_ERROR, 1, FN_ERR_TRANSPORT)) return 1;
    if (expect_one_exchange(MODE_TRUNCATED, 1, FN_ERR_IO)) return 1;
    if (expect_one_exchange(MODE_MALFORMED_LENGTH, 1, FN_ERR_INVALID)) return 1;
    if (expect_one_exchange(MODE_MISMATCHED_IDENTITY, 1, FN_ERR_IO)) return 1;
    if (expect_one_exchange(MODE_CORRUPT_CHECKSUM, 1, FN_ERR_IO)) return 1;
    if (expect_one_exchange(MODE_INSUFFICIENT_CAPACITY, 0, FN_ERR_IO)) return 1;
    return 0;
}

static int test_valid_response_is_returned_once(void)
{
    fn_raw_response_t response;
    uint8_t request = 0x42;
    uint8_t reply = 0;

    _fn_initialized = 1;
    mode = MODE_SUCCESS;
    exchanges = 0;
    if (fn_raw_call(FN_DEVICE_FILE, 4, &request, 1, &reply, 1, &response) != FN_OK)
        return 1;
    return exchanges != 1 || response.payload_length != 1 || reply != 0x42;
}

int main(void)
{
    if (test_uncertain_failures_are_not_replayed()) {
        fputs("uncertain raw-call outcome was replayed\n", stderr);
        return 1;
    }
    if (test_valid_response_is_returned_once()) {
        fputs("valid raw-call response did not complete once\n", stderr);
        return 1;
    }
    return 0;
}
