#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$ROOT/build/tests/disk_wire_test"

mkdir -p "$(dirname "$OUT")"
gcc -std=c99 -Wall -Wextra -Werror \
    -I"$ROOT/include" \
    "$ROOT/tests/disk_wire_test.c" \
    "$ROOT/src/common/fn_disk_common.c" \
    "$ROOT/src/common/fn_disk_le_get.c" \
    "$ROOT/src/common/fn_disk_put_u16le.c" \
    "$ROOT/src/common/fn_disk_put_u32le.c" \
    "$ROOT/src/common/fn_disk_parse_info.c" \
    "$ROOT/src/common/fn_disk_mount.c" \
    "$ROOT/src/common/fn_disk_info.c" \
    "$ROOT/src/common/fn_disk_read_sector.c" \
    "$ROOT/src/common/fn_disk_write_sector.c" \
    "$ROOT/src/common/fn_disk_context.c" \
    "$ROOT/src/common/fn_packet_header.c" \
    "$ROOT/src/common/fn_checksum_fold.c" \
    "$ROOT/src/common/fn_packet_checksum.c" \
    "$ROOT/src/common/fn_packet_checksum_packet.c" \
    -o "$OUT"
"$OUT"
