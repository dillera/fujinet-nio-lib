#!/bin/sh
set -eu
mkdir -p build/tests/atari-compact
out=build/tests/atari-compact
# Compile unchanged portable functions under reference symbols. Their calls
# also resolve to reference helpers, giving an independent differential oracle.
flags='-D fn_init=ref_init -D fn_is_ready=ref_ready -D fn_checksum_fold=ref_fold -D fn_calc_checksum=ref_checksum -D fn_calc_packet_checksum=ref_packet_checksum -D fn_build_header=ref_header -D fn_add_param=ref_param -D fn_parse_response_header=ref_parse -D fn_build_open_packet=ref_open -D fn_build_read_packet=ref_read -D fn_build_write_packet=ref_write -D fn_build_close_packet=ref_close -D fn_build_info_packet=ref_info -D fn_raw_call=ref_raw'
objects=''
for name in fn_checksum_fold fn_packet_checksum fn_packet_checksum_packet fn_packet_header fn_packet_parse_common fn_packet_build_open fn_packet_build_rw fn_packet_build_misc fn_raw fn_init; do
    cl65 -t sim6502 -O -I include $flags -c -o "$out/$name.o" "src/common/$name.c"
    objects="$objects $out/$name.o"
done
make -f makefiles/build.mk TARGET=atari PROGRAM=fujinet-nio ATARI_BACKEND=compact build/fujinet-nio-atari-compact.lib
cl65 -t sim6502 -O -I include -o "$out/test" tests/atari_compact_test.c $objects build/fujinet-nio-atari-compact.lib
sim65 "$out/test"

ca65 -o "$out/asm.o" tests/atari_compact_asm.s
ld65 -C tests/atari_compact_asm.cfg -m "$out/asm.map" -o "$out/asm-test" "$out/asm.o" build/fujinet-nio-atari-compact.lib
sim65 "$out/asm-test"
echo 'Atari runtime-free assembly raw/native transport: passed'
soft65c02_unit -b "$out/transport" -i tests/atari_transport_compact_soft65c02.yaml
