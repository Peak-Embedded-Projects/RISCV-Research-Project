from __future__ import annotations

import argparse
import sys

from .demo_workflow import run_demo_program_test
from .worker_interface import WorkerInterface, parse_int


def run_command(args: argparse.Namespace) -> int:
    with WorkerInterface(args.port, 115200, args.timeout) as client:
        run_demo_program_test(client, args.boot_addr)
    print("Demo program test passed!")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Master PC UART workflow runner for the RISC-V SoC"
    )
    parser.add_argument(
        "--port",
        default="/dev/ttyUSB0",
        help="Serial device (default: /dev/ttyUSB0)",
    )
    parser.add_argument("--timeout", type=float, default=1.0)
    parser.add_argument(
        "--boot-addr",
        type=parse_int,
        default=0x40000000,
        help="Program upload base address",
    )
    args = parser.parse_args()

    try:
        return run_command(args)
    except Exception as exc:  # pragma: no cover - CLI edge handling
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
