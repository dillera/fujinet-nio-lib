#!/bin/sh
set -eu

mkdir -p build/tests
gcc -std=c99 -Wall -Wextra -Werror -Iinclude \
    tests/raw_transport_retry_test.c \
    src/common/fn_raw.c src/common/fn_init.c src/common/fn_state.c \
    src/common/fn_packet_header.c src/common/fn_packet_parse_common.c \
    src/common/fn_packet_checksum.c src/common/fn_packet_checksum_packet.c \
    src/common/fn_checksum_fold.c \
    -o build/tests/raw_transport_retry_test
build/tests/raw_transport_retry_test
