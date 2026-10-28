#include <stdio.h>
#include <string.h>

#include "fn_internal.h"
#include "fn_platform.h"
#include "fn_protocol.h"
#include "fujinet-nio.h"

/* fn_ready(): the request bytes, the entry parse, truncation to the caller's buffer, an older firmware's
 * Unsupported, a malformed reply; and fn_read_available() from the Read response's reserved field.
 * fn_transport_exchange() below records the request and plays back the reply the test scripts. */

static int failures;

static uint8_t sent[FN_MAX_PACKET_SIZE];
static uint16_t sent_len;
static uint8_t transport_result;
static uint8_t reply[64];
static uint16_t reply_len;

#define CHECK(condition) \
    do { \
        if (!(condition)) { \
            printf("FAIL %s:%d %s\n", __FILE__, __LINE__, #condition); \
            ++failures; \
        } \
    } while (0)

uint8_t fn_transport_exchange(void)
{
    sent_len = _fn_transport_ctx.req_len;
    memcpy(sent, _fn_transport_ctx.request, sent_len);
    if (transport_result != FN_OK) {
        return transport_result;
    }
    memcpy(_fn_transport_ctx.response, reply, reply_len);
    _fn_transport_ctx.resp_len = reply_len;
    return FN_OK;
}

static void put_entry(uint16_t *offset, uint16_t handle, uint8_t ready, uint16_t available)
{
    reply[(*offset)++] = (uint8_t)(handle & 0xFF);
    reply[(*offset)++] = (uint8_t)(handle >> 8);
    reply[(*offset)++] = ready;
    reply[(*offset)++] = (uint8_t)(available & 0xFF);
    reply[(*offset)++] = (uint8_t)(available >> 8);
}

/* A Ready reply with `count` entries from the table below. */
static void script_ready_reply(uint8_t count)
{
    uint16_t offset;

    offset = fn_build_header(reply, FN_DEVICE_NETWORK, FN_CMD_READY, (uint16_t)(FN_HEADER_SIZE + 5 + count * 5));
    reply[offset++] = FN_PROTOCOL_VERSION;
    reply[offset++] = 0;       /* flags */
    reply[offset++] = 0;       /* reserved */
    reply[offset++] = 0;
    reply[offset++] = count;
    if (count > 0) put_entry(&offset, 0x0102, FN_READY_READ, 300);
    if (count > 1) put_entry(&offset, 0x0203, FN_READY_INFO, 0);
    if (count > 2) put_entry(&offset, 0x0304, FN_READY_READ | FN_READY_INFO, 0xFFFF);
    reply[FN_CHECKSUM_OFFSET] = fn_calc_packet_checksum(reply, offset);
    reply_len = offset;
}

/* A reply that carries only a status, as the device does for an error: descriptor 1 = one u8 parameter. */
static void script_status_reply(uint8_t status)
{
    uint16_t offset;

    offset = fn_build_header(reply, FN_DEVICE_NETWORK, FN_CMD_READY, FN_HEADER_SIZE + 1);
    reply[5] = 1;
    reply[offset++] = status;
    reply[FN_CHECKSUM_OFFSET] = fn_calc_packet_checksum(reply, offset);
    reply_len = offset;
}

static void reset(void)
{
    _fn_initialized = 1;
    sent_len = 0;
    transport_result = FN_OK;
    script_ready_reply(0);
}

static void test_request(void)
{
    uint8_t count = 99;
    fn_ready_entry_t entries[4];
    /* device 0xFD, command 8, total length 7, checksum, descriptor 0, version 1 */
    uint8_t expected[7] = { FN_DEVICE_NETWORK, FN_CMD_READY, 7, 0, 0, 0, FN_PROTOCOL_VERSION };

    reset();
    CHECK(fn_ready(entries, 4, &count) == FN_OK);
    expected[FN_CHECKSUM_OFFSET] = fn_calc_packet_checksum(expected, sizeof expected);
    CHECK(sent_len == sizeof expected);
    CHECK(memcmp(sent, expected, sizeof expected) == 0);
    CHECK(count == 0);   /* a reply with no entries */
}

static void test_entries(void)
{
    uint8_t count = 0;
    fn_ready_entry_t entries[4];

    reset();
    script_ready_reply(3);
    CHECK(fn_ready(entries, 4, &count) == FN_OK);
    CHECK(count == 3);
    CHECK(entries[0].handle == 0x0102 && entries[0].flags == FN_READY_READ && entries[0].available == 300);
    CHECK(entries[1].handle == 0x0203 && entries[1].flags == FN_READY_INFO && entries[1].available == 0);
    CHECK(entries[2].handle == 0x0304 && entries[2].flags == (FN_READY_READ | FN_READY_INFO) &&
          entries[2].available == 0xFFFF);

    /* Fewer slots than entries: only what fits is stored and counted. */
    reset();
    script_ready_reply(3);
    memset(entries, 0xAA, sizeof entries);
    CHECK(fn_ready(entries, 2, &count) == FN_OK);
    CHECK(count == 2);
    CHECK(entries[1].handle == 0x0203);
    CHECK(entries[2].handle == 0xAAAA);   /* untouched */

    /* No slots at all is fine, and counts nothing. */
    reset();
    script_ready_reply(3);
    CHECK(fn_ready(NULL, 0, &count) == FN_OK);
    CHECK(count == 0);
}

static void test_errors(void)
{
    uint8_t count = 0;
    fn_ready_entry_t entries[2];

    reset();
    _fn_initialized = 0;
    CHECK(fn_ready(entries, 2, &count) == FN_ERR_INVALID);
    reset();
    CHECK(fn_ready(entries, 2, NULL) == FN_ERR_INVALID);
    CHECK(fn_ready(NULL, 2, &count) == FN_ERR_INVALID);

    /* Firmware that predates the command answers Unsupported. */
    reset();
    script_status_reply(FN_ERR_UNSUPPORTED);
    CHECK(fn_ready(entries, 2, &count) == FN_ERR_UNSUPPORTED);

    /* A reply that claims more entries than it carries. */
    reset();
    script_ready_reply(3);
    reply[FN_HEADER_SIZE + 4] = 9;
    reply[FN_CHECKSUM_OFFSET] = 0;
    reply[FN_CHECKSUM_OFFSET] = fn_calc_packet_checksum(reply, reply_len);
    CHECK(fn_ready(entries, 2, &count) == FN_ERR_INVALID);

    /* A transport failure comes straight back. */
    reset();
    transport_result = FN_ERR_TIMEOUT;
    CHECK(fn_ready(entries, 2, &count) == FN_ERR_TIMEOUT);
}

/* A Read reply: version, flags, u16 (available when flag bit3), handle, offset, length, data. */
static void script_read_reply(uint8_t flags, uint16_t available, const uint8_t *data, uint16_t len)
{
    uint16_t offset;

    offset = fn_build_header(reply, FN_DEVICE_NETWORK, FN_CMD_READ, (uint16_t)(FN_HEADER_SIZE + 12 + len));
    reply[offset++] = FN_PROTOCOL_VERSION;
    reply[offset++] = flags;
    reply[offset++] = (uint8_t)(available & 0xFF);
    reply[offset++] = (uint8_t)(available >> 8);
    reply[offset++] = 0x34;                       /* handle */
    reply[offset++] = 0x12;
    reply[offset++] = 0; reply[offset++] = 0; reply[offset++] = 0; reply[offset++] = 0;   /* offset echo */
    reply[offset++] = (uint8_t)(len & 0xFF);
    reply[offset++] = (uint8_t)(len >> 8);
    memcpy(reply + offset, data, len);
    offset = (uint16_t)(offset + len);
    reply[FN_CHECKSUM_OFFSET] = fn_calc_packet_checksum(reply, offset);
    reply_len = offset;
}

static void test_read_available(void)
{
    uint8_t buf[8];
    uint16_t got = 0;
    uint8_t flags = 0;
    const uint8_t data[2] = { 'h', 'i' };

    reset();
    _fn_sessions[0].active = 1;
    _fn_sessions[0].handle = 0x1234;
    _fn_sessions[0].proto_flags = 0;

    /* The firmware reports 77 bytes still held. */
    script_read_reply(FN_READ_AVAILABLE | FN_READ_MORE_AVAILABLE, 77, data, 2);
    CHECK(fn_read(0x1234, 0, buf, sizeof buf, &got, &flags) == FN_OK);
    CHECK(got == 2);
    CHECK((flags & FN_READ_AVAILABLE) != 0);
    CHECK(fn_read_available() == 77);

    /* An older firmware leaves the field 0 and the flag clear. */
    script_read_reply(0, 0, data, 2);
    CHECK(fn_read(0x1234, 0, buf, sizeof buf, &got, &flags) == FN_OK);
    CHECK((flags & FN_READ_AVAILABLE) == 0);
    CHECK(fn_read_available() == 0);

    /* Even a nonzero reserved field is not read as a count without the flag. */
    script_read_reply(0, 55, data, 2);
    CHECK(fn_read(0x1234, 0, buf, sizeof buf, &got, &flags) == FN_OK);
    CHECK(fn_read_available() == 0);
}

int main(void)
{
    test_request();
    test_entries();
    test_errors();
    test_read_available();
    if (failures != 0) {
        printf("%d failure(s)\n", failures);
        return 1;
    }
    printf("ready_wire_test: ok\n");
    return 0;
}
