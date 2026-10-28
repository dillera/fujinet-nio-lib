#include <string.h>

#include "fn_disk_internal.h"

#if defined(__CC65__)
/* The framing around a sector in the response packet, at most: the FujiBus header (6), a status field (up
 * to 4) and the disk reply's own header (11). With the sector capacity it bounds the response. */
#define FN_DISK_READ_FRAMING 21u

#if defined(__ATARI__)
extern uint16_t fn_reply_hint;   /* fn_transport.s: a bound on the next response, 0 for none */
#endif

/* The reply is read in place in the response buffer and the sector copied out once, where fn_raw_call()
 * would copy it to a reply buffer first (about 2.4 ms for 256 bytes on an Atari). */
uint8_t fn_disk_read_sector(uint8_t slot, uint32_t lba,
                            uint8_t *data, uint16_t data_capacity,
                            uint16_t *data_length)
{
    fn_raw_response_t response;
    const uint8_t *reply;
    uint16_t reply_length;
    uint16_t payload_length;
    uint8_t result;

    if (!data || !data_capacity || !data_length) return FN_ERR_INVALID;
    disk_request[0] = FN_DISK_PROTOCOL_VERSION;
    disk_request[1] = slot;
    fn_disk_put_u32le(disk_request + 2, lba);
    fn_disk_put_u16le(disk_request + 6, data_capacity);
#if defined(__ATARI__)
    /* A transport that can read the response without asking its length first uses this bound. */
    if (data_capacity <= FN_MAX_PACKET_SIZE - FN_DISK_READ_FRAMING)
        fn_reply_hint = (uint16_t)(data_capacity + FN_DISK_READ_FRAMING);
#endif
    result = fn_raw_call(FN_DEVICE_DISK, FN_DISK_CMD_READ_SECTOR, disk_request, 8,
                         0, FN_MAX_PACKET_SIZE, &response);
#if defined(__ATARI__)
    fn_reply_hint = 0;
#endif
    fn_disk_error = FN_DISK_ERR_UNREPORTED;
    if (result != FN_OK) return result;
    reply = _fn_resp_buf + _fn_parse_ctx.data_offset;
    reply_length = response.payload_length;
    fn_disk_error = response.status == 0
        ? FN_DISK_ERR_NONE
        : fn_disk_failure_error(reply, reply_length);
    result = fn_disk_status(response.status);
    if (result != FN_OK) return result;
    if (reply_length < 11 || reply[0] != FN_DISK_PROTOCOL_VERSION ||
        reply[4] != slot || fn_disk_get_u32le(reply + 5) != lba) return FN_ERR_IO;
    payload_length = fn_disk_get_u16le(reply + 9);
    if ((uint32_t)11 + payload_length != reply_length ||
        payload_length > data_capacity) return FN_ERR_IO;
    memcpy(data, reply + 11, payload_length);
    *data_length = payload_length;
    return FN_OK;
}
#else
uint8_t fn_disk_read_sector(uint8_t slot, uint32_t lba,
                            uint8_t *data, uint16_t data_capacity,
                            uint16_t *data_length)
{
#if !defined(__CC65__)
    uint8_t disk_request[8];
    uint8_t disk_reply[FN_MAX_PACKET_SIZE];
#endif
    uint16_t reply_length = 0;
    uint16_t payload_length;
    uint8_t result;

    if (!data || !data_capacity || !data_length) return FN_ERR_INVALID;
    disk_request[0] = FN_DISK_PROTOCOL_VERSION;
    disk_request[1] = slot;
    fn_disk_put_u32le(disk_request + 2, lba);
    fn_disk_put_u16le(disk_request + 6, data_capacity);
    result = fn_disk_call(FN_DISK_CMD_READ_SECTOR, disk_request, 8,
                       disk_reply, sizeof(disk_reply), &reply_length);
    if (result != FN_OK) return result;
    if (reply_length < 11 || disk_reply[0] != FN_DISK_PROTOCOL_VERSION ||
        disk_reply[4] != slot || fn_disk_get_u32le(disk_reply + 5) != lba) return FN_ERR_IO;
    payload_length = fn_disk_get_u16le(disk_reply + 9);
    if ((uint32_t)11 + payload_length != reply_length ||
        payload_length > data_capacity) return FN_ERR_IO;
    memcpy(data, disk_reply + 11, payload_length);
    *data_length = payload_length;
    return FN_OK;
}

#endif
