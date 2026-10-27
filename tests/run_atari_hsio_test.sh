#!/bin/sh
set -eu
mkdir -p build/tests
soft65c02_unit -b build/tests/atari-hsio-soft65c02 -i tests/atari_hsio_soft65c02.yaml
