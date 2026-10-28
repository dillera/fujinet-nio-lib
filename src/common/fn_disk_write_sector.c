#include <string.h>

#include "fn_disk_internal.h"

uint8_t fn_disk_write_sector(uint8_t slot, uint32_t lba,
                             const uint8_t *data, uint16_t data_length)
{
#if !defined(__CC65__)
    uint8_t disk_request[FN_MAX_PACKET_SIZE];
    uint8_t disk_reply[16];
#endif
    uint16_t reply_length = 0;
    uint8_t result;

    if (!data || !data_length || (uint32_t)8 + data_length > FN_MAX_PACKET_SIZE - FN_HEADER_SIZE) {
        return FN_ERR_INVALID;
    }
    disk_request[0] = FN_DISK_PROTOCOL_VERSION;
    disk_request[1] = slot;
    fn_disk_put_u32le(disk_request + 2, lba);
    fn_disk_put_u16le(disk_request + 6, data_length);
    memcpy(disk_request + 8, data, data_length);
    result = fn_disk_call(FN_DISK_CMD_WRITE_SECTOR, disk_request,
                       (uint16_t)(8 + data_length), disk_reply,
                       sizeof(disk_reply),
                       &reply_length);
    if (result != FN_OK) return result;
    if (reply_length != 11 || disk_reply[0] != FN_DISK_PROTOCOL_VERSION ||
        disk_reply[4] != slot || fn_disk_get_u32le(disk_reply + 5) != lba ||
        fn_disk_get_u16le(disk_reply + 9) != data_length) return FN_ERR_IO;
    return FN_OK;
}
