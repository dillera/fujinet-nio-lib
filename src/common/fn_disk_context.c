#include <string.h>

#include "fn_disk_internal.h"

#if !defined(__CC65__)
static uint8_t context_parse_response(fn_disk_client_context_t *context,
                                      uint8_t device, uint8_t command,
                                      uint16_t response_length,
                                      uint16_t *data_offset,
                                      uint16_t *data_length,
                                      uint8_t *status)
{
    static const uint8_t field_sizes[8] = { 0, 1, 1, 1, 1, 2, 2, 4 };
    static const uint8_t field_counts[8] = { 0, 1, 2, 3, 4, 1, 2, 1 };
    uint8_t *response = context->packet_response;
    uint16_t offset = FN_HEADER_SIZE;
    uint8_t descriptor;
    uint8_t field_size;
    uint8_t field_count;

    if (response_length < FN_HEADER_SIZE || response[0] != device ||
        response[1] != command || fn_disk_get_u16le(response + 2) != response_length) {
        return FN_ERR_INVALID;
    }
    if (fn_calc_packet_checksum(response, response_length) != response[FN_CHECKSUM_OFFSET]) {
        return FN_ERR_IO;
    }

    descriptor = response[5];
    *status = FN_OK;
    if (descriptor != 0) {
        while ((descriptor & 0x80u) != 0) {
            if (offset >= response_length) return FN_ERR_INVALID;
            descriptor = response[offset++];
        }
        field_size = field_sizes[descriptor & 7u];
        field_count = field_counts[descriptor & 7u];
        if ((uint16_t)(offset + (uint16_t)field_size * field_count) >
            response_length) {
            return FN_ERR_INVALID;
        }
        if (field_count != 0) {
            *status = response[offset];
            offset = (uint16_t)(offset + (uint16_t)field_size * field_count);
        }
    }
    *data_offset = offset;
    *data_length = (uint16_t)(response_length - offset);
    return FN_OK;
}

static uint8_t context_disk_call(fn_disk_client_context_t *context,
                                 uint8_t command, uint16_t request_length,
                                 uint16_t *reply_length)
{
    uint16_t packet_length;
    uint16_t response_length = 0;
    uint16_t data_offset;
    uint16_t data_length;
    uint8_t status;
    uint8_t result;

    if (context == NULL) return FN_ERR_INVALID;
    context->last_error = FN_DISK_ERR_UNREPORTED;
    if (context->exchange == NULL ||
        request_length > FN_DISK_CONTEXT_PACKET_SIZE - FN_HEADER_SIZE) {
        return FN_ERR_INVALID;
    }
    packet_length = fn_build_header(context->packet_request, FN_DEVICE_DISK,
                                    command,
                                    (uint16_t)(FN_HEADER_SIZE + request_length));
    if (request_length != 0) {
        memcpy(context->packet_request + packet_length,
               context->codec_scratch, request_length);
        packet_length = (uint16_t)(packet_length + request_length);
    }
    context->packet_request[FN_CHECKSUM_OFFSET] =
        fn_calc_packet_checksum(context->packet_request, packet_length);

    result = context->exchange(context->exchange_context,
                               context->packet_request, packet_length,
                               context->packet_response,
                               sizeof(context->packet_response),
                               &response_length);
    if (result != FN_OK) return result;
    result = context_parse_response(context, FN_DEVICE_DISK, command,
                                    response_length, &data_offset,
                                    &data_length, &status);
    if (result != FN_OK) return result;
    if (data_length > sizeof(context->codec_scratch)) return FN_ERR_IO;
    if (data_length != 0) {
        memcpy(context->codec_scratch,
               context->packet_response + data_offset, data_length);
    }
    if (reply_length != NULL) *reply_length = data_length;
    context->last_error = status == 0
        ? FN_DISK_ERR_NONE
        : fn_disk_failure_error(context->codec_scratch, data_length);
    return fn_disk_status(status);
}

uint8_t fn_disk_context_init(fn_disk_client_context_t *context,
                             fn_disk_exchange_fn exchange,
                             void *exchange_context)
{
    if (context == NULL || exchange == NULL) return FN_ERR_INVALID;
    memset(context, 0, sizeof(*context));
    context->exchange = exchange;
    context->exchange_context = exchange_context;
    return FN_OK;
}

uint8_t fn_disk_last_error_context(const fn_disk_client_context_t *context)
{
    return context != NULL ? context->last_error : FN_DISK_ERR_UNREPORTED;
}

uint8_t fn_disk_mount_context(fn_disk_client_context_t *context, uint8_t slot,
                              const char *uri, uint8_t readonly, uint8_t type,
                              uint16_t sector_size_hint, fn_disk_info_t *info)
{
    uint16_t uri_length;
    uint16_t reply_length = 0;
    uint8_t result;

    if (context == NULL || uri == NULL) return FN_ERR_INVALID;
    uri_length = (uint16_t)strlen(uri);
    if ((uint32_t)8 + uri_length > sizeof(context->codec_scratch)) {
        return FN_ERR_INVALID;
    }
    context->codec_scratch[0] = FN_DISK_PROTOCOL_VERSION;
    context->codec_scratch[1] = slot;
    context->codec_scratch[2] = readonly ? 1 : 0;
    context->codec_scratch[3] = type;
    fn_disk_put_u16le(context->codec_scratch + 4, sector_size_hint);
    fn_disk_put_u16le(context->codec_scratch + 6, uri_length);
    memcpy(context->codec_scratch + 8, uri, uri_length);
    result = context_disk_call(context, FN_DISK_CMD_MOUNT,
                               (uint16_t)(8 + uri_length), &reply_length);
    if (result != FN_OK) return result;
    if (reply_length != 12 ||
        context->codec_scratch[0] != FN_DISK_PROTOCOL_VERSION) {
        return FN_ERR_IO;
    }
    if (info != NULL) {
        info->flags = context->codec_scratch[1];
        info->slot = context->codec_scratch[4];
        info->type = context->codec_scratch[5];
        info->sector_size = fn_disk_get_u16le(context->codec_scratch + 6);
        info->sector_count = fn_disk_get_u32le(context->codec_scratch + 8);
        info->last_error = 0;
    }
    return FN_OK;
}

uint8_t fn_disk_info_context(fn_disk_client_context_t *context, uint8_t slot,
                             fn_disk_info_t *info)
{
    uint16_t reply_length = 0;
    uint8_t result;
    if (context == NULL || info == NULL) return FN_ERR_INVALID;
    context->codec_scratch[0] = FN_DISK_PROTOCOL_VERSION;
    context->codec_scratch[1] = slot;
    result = context_disk_call(context, FN_DISK_CMD_INFO, 2, &reply_length);
    if (result != FN_OK) return result;
    return fn_disk_parse_info(context->codec_scratch, reply_length, info);
}

uint8_t fn_disk_restore_boot_context(fn_disk_client_context_t *context,
                                     uint8_t slot, fn_disk_info_t *info)
{
    uint16_t reply_length = 0;
    uint8_t result;
    if (context == NULL || info == NULL) return FN_ERR_INVALID;
    context->codec_scratch[0] = FN_DISK_PROTOCOL_VERSION;
    context->codec_scratch[1] = slot;
    result = context_disk_call(context, FN_DISK_CMD_RESTORE_BOOT, 2,
                               &reply_length);
    if (result != FN_OK) return result;
    return fn_disk_parse_info(context->codec_scratch, reply_length, info);
}

uint8_t fn_disk_inspect_context(fn_disk_client_context_t *context,
                                const char *uri, uint8_t type,
                                uint16_t sector_size_hint,
                                fn_disk_inspection_t *inspection)
{
    uint16_t uri_length;
    uint16_t reply_length = 0;
    uint16_t boot_length;
    uint8_t result;
    if (context == NULL || uri == NULL || inspection == NULL) return FN_ERR_INVALID;
    uri_length = (uint16_t)strlen(uri);
    if ((uint32_t)10 + uri_length > sizeof(context->codec_scratch)) return FN_ERR_INVALID;
    context->codec_scratch[0] = FN_DISK_PROTOCOL_VERSION;
    context->codec_scratch[1] = 0;
    context->codec_scratch[2] = type;
    fn_disk_put_u16le(context->codec_scratch + 3, sector_size_hint);
    fn_disk_put_u16le(context->codec_scratch + 5, FN_DISK_INSPECT_BOOT_BYTES);
    fn_disk_put_u16le(context->codec_scratch + 7, uri_length);
    memcpy(context->codec_scratch + 9, uri, uri_length);
    result = context_disk_call(context, FN_DISK_CMD_INSPECT,
                               (uint16_t)(9 + uri_length), &reply_length);
    if (result != FN_OK) return result;
    if (reply_length < 10 || context->codec_scratch[0] != FN_DISK_PROTOCOL_VERSION) return FN_ERR_IO;
    boot_length = fn_disk_get_u16le(context->codec_scratch + 8);
    if (boot_length > FN_DISK_INSPECT_BOOT_BYTES || reply_length != (uint16_t)(10 + boot_length)) return FN_ERR_IO;
    memset(inspection, 0, sizeof(*inspection));
    inspection->media.flags = FN_DISK_FLAG_MOUNTED | FN_DISK_FLAG_READONLY;
    inspection->media.type = context->codec_scratch[1];
    inspection->media.sector_size = fn_disk_get_u16le(context->codec_scratch + 2);
    inspection->media.sector_count = fn_disk_get_u32le(context->codec_scratch + 4);
    inspection->boot_length = boot_length;
    memcpy(inspection->boot_bytes, context->codec_scratch + 10, boot_length);
    return FN_OK;
}

uint8_t fn_disk_read_sector_context(fn_disk_client_context_t *context,
                                    uint8_t slot, uint32_t lba, uint8_t *data,
                                    uint16_t data_capacity,
                                    uint16_t *data_length)
{
    uint16_t reply_length = 0;
    uint16_t payload_length;
    uint8_t result;
    if (context == NULL || data == NULL || data_capacity == 0 ||
        data_length == NULL) return FN_ERR_INVALID;
    context->codec_scratch[0] = FN_DISK_PROTOCOL_VERSION;
    context->codec_scratch[1] = slot;
    fn_disk_put_u32le(context->codec_scratch + 2, lba);
    fn_disk_put_u16le(context->codec_scratch + 6, data_capacity);
    result = context_disk_call(context, FN_DISK_CMD_READ_SECTOR, 8,
                               &reply_length);
    if (result != FN_OK) return result;
    if (reply_length < 11 ||
        context->codec_scratch[0] != FN_DISK_PROTOCOL_VERSION ||
        context->codec_scratch[4] != slot ||
        fn_disk_get_u32le(context->codec_scratch + 5) != lba) return FN_ERR_IO;
    payload_length = fn_disk_get_u16le(context->codec_scratch + 9);
    if ((uint32_t)11 + payload_length != reply_length ||
        payload_length > data_capacity) return FN_ERR_IO;
    memcpy(data, context->codec_scratch + 11, payload_length);
    *data_length = payload_length;
    return FN_OK;
}

static uint8_t context_slot_command(fn_disk_client_context_t *context,
                                    uint8_t command, uint8_t slot)
{
    uint16_t reply_length = 0;
    uint8_t result;
    if (context == NULL) return FN_ERR_INVALID;
    context->codec_scratch[0] = FN_DISK_PROTOCOL_VERSION;
    context->codec_scratch[1] = slot;
    result = context_disk_call(context, command, 2, &reply_length);
    if (result != FN_OK) return result;
    if (reply_length != 5 ||
        context->codec_scratch[0] != FN_DISK_PROTOCOL_VERSION ||
        context->codec_scratch[4] != slot) return FN_ERR_IO;
    return FN_OK;
}

uint8_t fn_disk_write_sector_context(fn_disk_client_context_t *context,
                                     uint8_t slot, uint32_t lba,
                                     const uint8_t *data,
                                     uint16_t data_length)
{
    uint16_t reply_length = 0;
    uint8_t result;
    if (context == NULL || data == NULL || data_length == 0 ||
        (uint32_t)8 + data_length > sizeof(context->codec_scratch))
        return FN_ERR_INVALID;
    context->codec_scratch[0] = FN_DISK_PROTOCOL_VERSION;
    context->codec_scratch[1] = slot;
    fn_disk_put_u32le(context->codec_scratch + 2, lba);
    fn_disk_put_u16le(context->codec_scratch + 6, data_length);
    memcpy(context->codec_scratch + 8, data, data_length);
    result = context_disk_call(context, FN_DISK_CMD_WRITE_SECTOR,
                               (uint16_t)(8 + data_length), &reply_length);
    if (result != FN_OK) return result;
    if (reply_length != 11 ||
        context->codec_scratch[0] != FN_DISK_PROTOCOL_VERSION ||
        context->codec_scratch[4] != slot ||
        fn_disk_get_u32le(context->codec_scratch + 5) != lba ||
        fn_disk_get_u16le(context->codec_scratch + 9) != data_length) return FN_ERR_IO;
    return FN_OK;
}

uint8_t fn_disk_unmount_context(fn_disk_client_context_t *context, uint8_t slot)
{ return context_slot_command(context, FN_DISK_CMD_UNMOUNT, slot); }
uint8_t fn_disk_clear_changed_context(fn_disk_client_context_t *context,
                                      uint8_t slot)
{ return context_slot_command(context, FN_DISK_CMD_CLEAR_CHANGED, slot); }
uint8_t fn_disk_flush_context(fn_disk_client_context_t *context, uint8_t slot)
{ return context_slot_command(context, FN_DISK_CMD_FLUSH, slot); }
#endif
