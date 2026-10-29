#!/bin/sh
set -eu
# Run the same independent vectors against both the shared C implementation
# and the Atari assembly implementation, with identical cc65 optimisation.
soft65c02_unit -b build/tests/list-pages-c -i tests/atari_list_pages_reference_soft65c02.yaml
soft65c02_unit -b build/tests/list-pages-atari -i tests/atari_list_pages_soft65c02.yaml
