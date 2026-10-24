#include <string.h>

#include "fn_internal.h"
#include "fn_platform.h"

/* Keep TCP URL formatting in its own archive member.  Most constrained
 * clients use fn_open() with a URI and must not retain this 128-byte scratch
 * buffer or the decimal-conversion helpers solely because fn_open() is used.
 * This state remains deliberately non-reentrant, matching the library's
 * existing foreground transport contract. */
static char tcp_url[FN_MAX_URL_LEN];

uint8_t fn_tcp_open(fn_handle_t *handle,
                    const char *host,
                    uint16_t port)
{
    uint8_t offset;
    uint8_t started;
    uint16_t p;

    strcpy(tcp_url, "tcp://");
    offset = 6;

    if (offset + strlen(host) > FN_MAX_URL_LEN - 10) {
        return FN_ERR_URL_TOO_LONG;
    }
    strcpy(tcp_url + offset, host);
    offset += (uint8_t)strlen(host);

    tcp_url[offset++] = ':';

    p = port;
    started = 0;
    if (p >= 10000) {
        tcp_url[offset++] = (char)('0' + (p / 10000));
        p %= 10000;
        started = 1;
    }
    if (started || p >= 1000) {
        tcp_url[offset++] = (char)('0' + (p / 1000));
        p %= 1000;
        started = 1;
    }
    if (started || p >= 100) {
        tcp_url[offset++] = (char)('0' + (p / 100));
        p %= 100;
        started = 1;
    }
    if (started || p >= 10) {
        tcp_url[offset++] = (char)('0' + (p / 10));
        p %= 10;
    }
    tcp_url[offset++] = (char)('0' + p);
    tcp_url[offset] = '\0';

    return fn_open(handle, 0, tcp_url, 0);
}
