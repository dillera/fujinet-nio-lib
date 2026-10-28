#include "fn_disk_internal.h"

uint8_t fn_disk_error = FN_DISK_ERR_NONE;

uint8_t fn_disk_status(uint8_t status)
{
    static const uint8_t map[9] = {
        FN_OK, FN_ERR_NOT_FOUND, FN_ERR_INVALID, FN_ERR_BUSY, FN_ERR_NOT_READY,
        FN_ERR_IO, FN_ERR_TIMEOUT, FN_ERR_INTERNAL, FN_ERR_UNSUPPORTED
    };
    return status < 9 ? map[status] : FN_ERR_UNKNOWN;
}

/* The DiskError a failed response carries as {version, DiskError}. */
uint8_t fn_disk_failure_error(const uint8_t *payload, uint16_t length)
{
    if (payload != 0 && length == 2 && payload[0] == FN_DISK_PROTOCOL_VERSION) {
        return payload[1];
    }
    return FN_DISK_ERR_UNREPORTED;
}

uint8_t fn_disk_call(uint8_t command, const void *request,
                     uint16_t request_length, void *reply,
                     uint16_t reply_capacity, uint16_t *reply_length)
{
    fn_raw_response_t response;
    uint8_t result = fn_raw_call(FN_DEVICE_DISK, command,
                                 request, request_length, reply,
                                 reply_capacity, &response);
    fn_disk_error = FN_DISK_ERR_UNREPORTED;
    if (result != FN_OK) return result;
    if (reply_length) *reply_length = response.payload_length;
    fn_disk_error = response.status == 0
        ? FN_DISK_ERR_NONE
        : fn_disk_failure_error((const uint8_t *)reply, response.payload_length);
    return fn_disk_status(response.status);
}
