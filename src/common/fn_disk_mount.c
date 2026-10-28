#include <string.h>

#include "fn_disk_internal.h"

uint8_t fn_disk_mount(uint8_t slot, const char *uri, uint8_t readonly,
                      uint8_t type, uint16_t sector_size_hint,
                      fn_disk_info_t *info)
{
#if !defined(__CC65__)
    uint8_t disk_request[FN_MAX_PACKET_SIZE];
    uint8_t disk_reply[FN_MAX_PACKET_SIZE];
#endif
    uint16_t uri_length;
    uint16_t request_length;
    uint16_t reply_length = 0;
    uint8_t result;

    if (!uri) return FN_ERR_INVALID;
#if !defined(__CC65__) && !defined(__WATCOMC__)
    if (strlen(uri) > 0xFFFFu) return FN_ERR_INVALID;
#endif
    uri_length = (uint16_t)strlen(uri);
    if ((uint32_t)8 + uri_length > FN_MAX_PACKET_SIZE - FN_HEADER_SIZE) {
        return FN_ERR_INVALID;
    }
    disk_request[0] = FN_DISK_PROTOCOL_VERSION;
    disk_request[1] = slot;
    disk_request[2] = readonly ? 1 : 0;
    disk_request[3] = type;
    fn_disk_put_u16le(disk_request + 4, sector_size_hint);
    fn_disk_put_u16le(disk_request + 6, uri_length);
    memcpy(disk_request + 8, uri, uri_length);
    request_length = (uint16_t)(8 + uri_length);

    result = fn_disk_call(FN_DISK_CMD_MOUNT, disk_request, request_length,
                       disk_reply, sizeof(disk_reply), &reply_length);
    if (result != FN_OK) return result;
    if (reply_length != 12 || disk_reply[0] != FN_DISK_PROTOCOL_VERSION) {
        return FN_ERR_IO;
    }
    if (info) {
        info->flags = disk_reply[1];
        info->slot = disk_reply[4];
        info->type = disk_reply[5];
        info->sector_size = fn_disk_get_u16le(disk_reply + 6);
        info->sector_count = fn_disk_get_u32le(disk_reply + 8);
        info->last_error = 0;
    }
    return FN_OK;
}


uint8_t fn_disk_unmount(uint8_t slot)
{
#if !defined(__CC65__)
    uint8_t disk_request[2];
    uint8_t disk_reply[16];
#endif
    uint16_t reply_length = 0;
    uint8_t result;
    disk_request[0] = FN_DISK_PROTOCOL_VERSION;
    disk_request[1] = slot;
    result = fn_disk_call(FN_DISK_CMD_UNMOUNT, disk_request, 2,
                       disk_reply, sizeof(disk_reply), &reply_length);
    if (result != FN_OK) return result;
    if (reply_length != 5 || disk_reply[0] != FN_DISK_PROTOCOL_VERSION ||
        disk_reply[4] != slot) return FN_ERR_IO;
    return FN_OK;
}


uint8_t fn_disk_last_error(void)
{
    return fn_disk_error;
}
