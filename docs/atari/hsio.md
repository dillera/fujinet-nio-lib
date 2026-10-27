# High-speed SIO for the native endpoint (Atari)

The Atari OS talks SIO at 19200 baud. A SIO speed driver (the U1MB's, SpartaDOS X's, MyPicoDOS's
HISIO, the Happy/US Doubler/Ultra Speed patches) speeds up disk drives, but it decides per device,
and observed on a U1MB with `SIO driver: HSIO` and `SIO devices: All` it sends nothing but disk
traffic fast: the native endpoint (`0x7f`) stays at 19200. A native read of a 256-byte sector then
costs about 246 ms (1 KB/s).

`fn_atari_hsio_enable()` gives a program its own way:

1. It sends the Happy/Speedy "ultra speed" query (`3F`) to `0x7f` through the OS SIO, at standard
   speed. The firmware answers with a POKEY divisor, 0 to 9, only if `sio.hsio <index>` is set on its
   console (otherwise it NAKs and the function returns `FN_ERR_UNSUPPORTED`).
2. From then on every native call (`W`, `P`, `R`) goes through the driver in `fn_hsio.s` instead of
   the OS `SIOV`: the command frame, the ACK, the data and COMPLETE all at the speed the divisor
   gives (index 1 is about 108 kbaud, 0 about 124 kbaud; the rate is the PAL clock over
   2 x (index + 7)).
3. If a command fails at high speed, the driver retries at standard speed (the firmware follows the
   Atari's speed from frame to frame), so a mis-set index costs time and not data.

```c
fn_init();
if (fn_atari_hsio_enable() == FN_OK) {
    /* native calls now run at the FujiNet's speed index */
}
...
fn_atari_hsio_disable();   /* back to the OS SIO */
```

Nothing of the driver is linked into a program that does not call `fn_atari_hsio_enable`. The module
is about 700 bytes of code and 3 bytes of RAM; the transport only gains a replaceable SIO vector
(a few bytes). Disks and other devices still go through whatever SIO driver the machine has.

## Index 10 is never accepted

A speed byte of `$0A` is read by SIO drivers as a Happy 1050. The firmware does not offer it and the
library refuses it.

## Attribution

`src/platform/atari/fn_hsio.s` is derived from the high-speed SIO routine by Matthias Reichl
(hipatch 1.30, the HISIO driver of MyPicoDOS), Copyright (c) 2003-2010 Matthias Reichl, GPL version
2 or later. It is ported to ca65 and reduced to the ultra-speed case; see its header for what
changed. This repository is GPL-3.0 (`LICENSE`).

## Testing

`make test-atari-hsio` runs the enable/disable decisions under a fixture SIOV (what is sent for the
`3F`, which answers are accepted, the vector moving to the driver and back). The driver itself drives
POKEY and is exercised on hardware with the FujiNet's `sio.hsio` set; the firmware side is described in
`fujinet-nio/docs/atari/hsio.md`.
