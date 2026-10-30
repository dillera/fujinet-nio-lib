#ifndef FN_WIFI_INTERNAL_H
#define FN_WIFI_INTERNAL_H
#include <stdint.h>
uint8_t fn_wifi_call(uint8_t cmd, const void *req, uint16_t req_len,
                     void *reply, uint16_t cap, uint16_t *len);
#endif
