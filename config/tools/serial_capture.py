#!/usr/bin/env python3
"""Capture ESP32 serial output non-interactively.

`idf.py monitor` is interactive and hangs a non-interactive shell. This exits
on its own after a fixed window, so a script or agent can run it safely.

Usage:
    python serial_capture.py COM3 30 > boot.log
    python serial_capture.py COM3 20 --baud 921600

Why a fixed window instead of waiting for a pattern: a device that never boots
must still terminate, or the caller waits forever. A timeout is a real ceiling
of this approach; if you need "wait until the device says READY, up to 60s",
that is a different script.
"""
import argparse
import sys
import time

import serial  # pyserial; installed in the system Python


def main() -> int:
    ap = argparse.ArgumentParser(description="Capture serial output to stdout.")
    ap.add_argument("port", help='serial port, e.g. COM3 or /dev/ttyUSB0')
    ap.add_argument("seconds", type=float, help="how long to capture")
    ap.add_argument("--baud", type=int, default=115200, help="baud rate")
    ap.add_argument("--dtr", action="store_true",
                    help="assert DTR/RTS (many boards reset on open)")
    args = ap.parse_args()

    try:
        ser = serial.Serial(args.port, args.baud, timeout=0.2)
    except serial.SerialException as exc:
        # Port busy or absent is the common case; say which, and stop.
        print(f"cannot open {args.port}: {exc}", file=sys.stderr)
        return 2

    with ser:
        if args.dtr:
            ser.dtr = True
            ser.rts = True
        # Drop stale bytes so a reset triggered by opening the port does not
        # immediately echo the old buffer back as if it were the new boot.
        ser.reset_input_buffer()

        deadline = time.time() + args.seconds
        while time.time() < deadline:
            chunk = ser.read(4096)
            if chunk:
                sys.stdout.buffer.write(chunk)
                sys.stdout.flush()

    return 0


if __name__ == "__main__":
    sys.exit(main())
