#include <stdio.h>
#include <string.h>

#include "fn_internal.h"
#include "fn_platform.h"
#include "fn_raw.h"

enum { MODE_TRANSPORT_ERROR, MODE_BAD_BODY_THEN_GOOD };
static uint8_t mode;
static uint8_t exchanges;

uint8_t fn_transport_init(void) { return FN_OK; }
void fn_transport_close(void) {}
uint8_t fn_transport_ready(void) { return 1; }

uint8_t fn_transport_exchange(void)
{
    exchanges++;
    if (mode == MODE_TRANSPORT_ERROR) return FN_ERR_TRANSPORT;
    if (exchanges == 1) {
        _fn_transport_ctx.resp_len = 0; /* short body is safely retryable */
        return FN_OK;
    }
    fn_build_header(_fn_resp_buf, _fn_req_buf[0], _fn_req_buf[1], FN_HEADER_SIZE);
    _fn_resp_buf[FN_CHECKSUM_OFFSET] =
        fn_calc_packet_checksum(_fn_resp_buf, FN_HEADER_SIZE);
    _fn_transport_ctx.resp_len = FN_HEADER_SIZE;
    return FN_OK;
}

static int test_transport_error_is_not_replayed(void)
{
    fn_raw_response_t response;
    uint8_t value = 0x42;
    _fn_initialized = 1;
    mode = MODE_TRANSPORT_ERROR;
    exchanges = 0;
    if (fn_raw_call(FN_DEVICE_FILE, 4, &value, 1, 0, 0, &response) !=
        FN_ERR_TRANSPORT) return 1;
    return exchanges != 1;
}

static int test_bad_body_has_one_retry(void)
{
    fn_raw_response_t response;
    uint8_t value = 0x24;
    _fn_initialized = 1;
    mode = MODE_BAD_BODY_THEN_GOOD;
    exchanges = 0;
    if (fn_raw_call(FN_DEVICE_FILE, 4, &value, 1, 0, 0, &response) != FN_OK)
        return 1;
    return exchanges != 2;
}

int main(void)
{
    if (test_transport_error_is_not_replayed()) {
        fputs("transport error was replayed\n", stderr);
        return 1;
    }
    if (test_bad_body_has_one_retry()) {
        fputs("short body did not retain one safe retry\n", stderr);
        return 1;
    }
    return 0;
}
