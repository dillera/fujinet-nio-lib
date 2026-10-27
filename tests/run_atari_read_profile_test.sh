#!/bin/sh
# Cycle profile of fn_disk_read_sector against a fixture SIOV (needs build/fujinet-nio-atari-compact.lib).
# It asserts a ceiling on the whole call; run it with -v to see the cycle count at each mark.
set -eu
mkdir -p build/tests
soft65c02_unit -b build/tests/atari-read-profile -i tests/atari_read_profile_soft65c02.yaml "$@"
