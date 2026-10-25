#include "fujinet-nio.h"

/* fn-rom opens take no request headers; a body length has its own call */
uint8_t fn_open_headers(fn_handle_t *handle,
                        uint8_t method,
                        const char *url,
                        uint8_t flags,
                        const fn_header_t *headers,
                        uint8_t header_count,
                        uint32_t body_length)
{
    uint8_t result;

    (void)headers;
    if (header_count != 0 || body_length > 0xFFFFUL) {
        return FN_ERR_UNSUPPORTED;
    }
    if (body_length != 0) {
        result = fn_set_body_length((uint16_t)body_length);
        if (result != FN_OK) {
            return result;
        }
    }
    return fn_open(handle, method, url, flags);
}
