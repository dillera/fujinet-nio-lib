/* The client archive's transport for the common code it carries (fn_raw_call, Fuji info, WiFi status): each packet
 * goes through the installed library's raw exchange (ABI 1.6) to the selected transport. A separate archive member,
 * so an app that only uses the library's own calls links none of it. */
#include "NioLibClient.h"
#include "fn_internal.h"
#include "fn_platform.h"

uint8_t nl_client_raw(const uint8_t *, uint16_t, uint8_t *, uint16_t, uint16_t *);

uint8_t fn_transport_exchange_buffers(const uint8_t *request, uint16_t length, uint8_t *response,
                                      uint16_t capacity, uint16_t *got)
{
    return nl_client_raw(request, length, response, capacity, got);
}

uint8_t fn_transport_exchange(void)
{
    return fn_transport_exchange_buffers(_fn_transport_ctx.request, _fn_transport_ctx.req_len,
                                         _fn_transport_ctx.response, _fn_transport_ctx.resp_max,
                                         &_fn_transport_ctx.resp_len);
}
