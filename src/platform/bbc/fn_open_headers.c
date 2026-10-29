#include "fujinet-nio.h"

/* The fn-rom network-open interface does not accept arbitrary headers or a
 * body length. Do not silently discard authentication or request bodies. */
uint8_t fn_open_headers(fn_handle_t *handle, uint8_t method, const char *url,
                        uint8_t flags, const fn_http_header_t *headers,
                        uint16_t count, uint32_t body_len)
{
    (void)handle; (void)method; (void)url; (void)flags;
    (void)headers; (void)count; (void)body_len;
    return FN_ERR_UNSUPPORTED;
}
