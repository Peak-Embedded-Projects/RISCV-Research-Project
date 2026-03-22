from __future__ import annotations

import argparse
import sys

from .demo_workflow import run_demo_program_test
from .worker_interface import WorkerInterface


def run_command(args: argparse.Namespace) -> int:
    with WorkerInterface(args.port, args.timeout, verbose=args.verbose) as client:
        run_demo_program_test(client)
    print("Demo program test passed!")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Master PC UART workflow runner for the RISC-V SoC"
    )
    parser.add_argument(
        "--port",
        default="/dev/ttyUSB1",
        help="Serial device (default: /dev/ttyUSB1)",
    )
    parser.add_argument("--timeout", type=float, default=1.0)
    parser.add_argument(
        "--verbose",
        "-v",
        action="store_true",
        help="Enable verbose output (for debugging)",
    )
    args = parser.parse_args()

    try:
        return run_command(args)
    except Exception as exc:  # pragma: no cover - CLI edge handling
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
