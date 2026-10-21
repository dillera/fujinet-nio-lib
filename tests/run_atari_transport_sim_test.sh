#!/bin/sh
set -eu
mkdir -p build/tests
soft65c02_unit -b build/tests/atari-transport-soft65c02 -i tests/atari_transport_soft65c02.yaml
