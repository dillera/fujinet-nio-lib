/* Offsets consumed by fn_file_list_pages.s are cc65-specific. Fail the build
 * if a public structure changes rather than silently encoding the wrong wire. */
#include <stddef.h>
#include "fujinet-nio.h"
#include "fn_raw.h"
#include "fn_protocol.h"
#define ASSERT_OFFSET(type, field, value) \
    typedef char check_##type##_##field[(offsetof(type, field) == (value)) ? 1 : -1]
ASSERT_OFFSET(fn_file_io_t, buffer, 0);
ASSERT_OFFSET(fn_file_io_t, capacity, 2);
ASSERT_OFFSET(fn_list_pages_req_t, start_page, 0);
ASSERT_OFFSET(fn_list_pages_req_t, page_size, 2);
ASSERT_OFFSET(fn_list_pages_req_t, max_payload, 3);
ASSERT_OFFSET(fn_list_pages_req_t, flags, 5);
ASSERT_OFFSET(fn_list_pages_req_t, max_name, 6);
ASSERT_OFFSET(fn_list_pages_req_t, filter, 7);
ASSERT_OFFSET(fn_list_pages_t, flags, 0);
ASSERT_OFFSET(fn_list_pages_t, total, 1);
ASSERT_OFFSET(fn_list_pages_t, start_page, 5);
ASSERT_OFFSET(fn_list_pages_t, page_size, 7);
ASSERT_OFFSET(fn_list_pages_t, page_count, 8);
ASSERT_OFFSET(fn_list_pages_t, pages, 9);
ASSERT_OFFSET(fn_list_pages_t, pages_len, 11);
ASSERT_OFFSET(fn_raw_response_t, status, 0);
ASSERT_OFFSET(fn_raw_response_t, payload_length, 1);
typedef char check_file_io_size[(sizeof(fn_file_io_t) == 4) ? 1 : -1];
typedef char check_pages_request_size[(sizeof(fn_list_pages_req_t) == 9) ? 1 : -1];
typedef char check_pages_response_size[(sizeof(fn_list_pages_t) == 13) ? 1 : -1];
typedef char check_raw_response_size[(sizeof(fn_raw_response_t) == 3) ? 1 : -1];
/* The assembly maps device statuses 1..8 directly to these API values. */
typedef char check_status_values[(FN_OK == 0 && FN_ERR_NOT_FOUND == 1 &&
    FN_ERR_INVALID == 2 && FN_ERR_BUSY == 3 && FN_ERR_NOT_READY == 4 &&
    FN_ERR_IO == 5 && FN_ERR_TIMEOUT == 6 && FN_ERR_INTERNAL == 7 &&
    FN_ERR_UNSUPPORTED == 8 && FN_ERR_UNKNOWN == 255) ? 1 : -1];
typedef char check_file_command_values[(FN_DEVICE_FILE == 0xfe &&
    FN_CMD_FILE_LIST_PAGES == 7) ? 1 : -1];
