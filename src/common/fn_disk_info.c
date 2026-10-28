#include <string.h>

#include "fn_disk_internal.h"

uint8_t fn_disk_restore_boot(uint8_t slot, fn_disk_info_t *info)
{
#if !defined(__CC65__)
    uint8_t disk_request[2];
    uint8_t disk_reply[16];
#endif
    uint16_t reply_length = 0;
    uint8_t result;

    if (!info) return FN_ERR_INVALID;
    disk_request[0] = FN_DISK_PROTOCOL_VERSION;
    disk_request[1] = slot;
    result = fn_disk_call(FN_DISK_CMD_RESTORE_BOOT, disk_request, 2,
                       disk_reply, sizeof(disk_reply), &reply_length);
    if (result != FN_OK) return result;
    return fn_disk_parse_info(disk_reply, reply_length, info);
}

uint8_t fn_disk_flush(uint8_t slot)
{
#if !defined(__CC65__)
    uint8_t disk_request[2];
    uint8_t disk_reply[16];
#endif
    uint16_t reply_length = 0;
    uint8_t result;
    disk_request[0] = FN_DISK_PROTOCOL_VERSION;
    disk_request[1] = slot;
    result = fn_disk_call(FN_DISK_CMD_FLUSH, disk_request, 2,
                       disk_reply, sizeof(disk_reply), &reply_length);
    if (result != FN_OK) return result;
    if (reply_length != 5 || disk_reply[0] != FN_DISK_PROTOCOL_VERSION ||
        disk_reply[4] != slot) return FN_ERR_IO;
    return FN_OK;
}

uint8_t fn_disk_info(uint8_t slot, fn_disk_info_t *info)
{
#if !defined(__CC65__)
    uint8_t disk_request[2];
    uint8_t disk_reply[16];
#endif
    uint16_t reply_length = 0;
    uint8_t result;

    if (!info) return FN_ERR_INVALID;
    disk_request[0] = FN_DISK_PROTOCOL_VERSION;
    disk_request[1] = slot;
    result = fn_disk_call(FN_DISK_CMD_INFO, disk_request, 2,
                       disk_reply, sizeof(disk_reply), &reply_length);
    if (result != FN_OK) return result;
    return fn_disk_parse_info(disk_reply, reply_length, info);
}

uint8_t fn_disk_clear_changed(uint8_t slot)
{
#if !defined(__CC65__)
    uint8_t disk_request[2];
    uint8_t disk_reply[16];
#endif
    uint16_t reply_length = 0;
    uint8_t result;
    disk_request[0] = FN_DISK_PROTOCOL_VERSION;
    disk_request[1] = slot;
    result = fn_disk_call(FN_DISK_CMD_CLEAR_CHANGED, disk_request, 2,
                       disk_reply, sizeof(disk_reply), &reply_length);
    if (result != FN_OK) return result;
    if (reply_length != 5 || disk_reply[0] != FN_DISK_PROTOCOL_VERSION ||
        disk_reply[4] != slot) return FN_ERR_IO;
    return FN_OK;
}
