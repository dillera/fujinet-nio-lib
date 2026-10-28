#include "fn_disk_internal.h"

uint8_t fn_disk_parse_info(const uint8_t *reply, uint16_t length,
                           fn_disk_info_t *info)
{
    /*
     * The original DiskDevice Info response ended at sectorCount (12 bytes),
     * while newer responses may append the optional lastError byte (13 bytes).
     * Accepting both preserves compatibility with existing BBC/MS-DOS clients
     * and older NIO peers; this is not arbitrary size tolerance.
     */
    if (!info || (length != FN_DISK_INFO_RESPONSE_SIZE &&
                  length != FN_DISK_INFO_RESPONSE_SIZE_WITH_LAST_ERROR) ||
        reply[0] != FN_DISK_PROTOCOL_VERSION) {
        return FN_ERR_IO;
    }
    info->flags = reply[1];
    info->slot = reply[4];
    info->type = reply[5];
    info->sector_size = fn_disk_get_u16le(reply + 6);
    info->sector_count = fn_disk_get_u32le(reply + 8);
    info->last_error = (length == FN_DISK_INFO_RESPONSE_SIZE_WITH_LAST_ERROR)
                           ? reply[12]
                           : 0;
    return FN_OK;
}
