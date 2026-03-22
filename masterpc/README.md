# Master PC

This directory contains source code for the Master PC application used to orchestrate worker boards and collect execution data.

The current implementation controls the SoC over UART (serial). The SoC-side C application (PS) acts as a passive command forwarder, while command logic lives in this Python app.

## CLI usage

The CLI currently exposes a single example workflow: upload the built-in dummy program to BRAM and verify it executes correctly.

```bash
uv run python -m masterpc
```

Optional flags:

- `--port /dev/ttyUSB0`: serial device (default `/dev/ttyUSB0`)
- `--timeout 1.0`: UART read timeout in seconds
- `--verbose`: print UART TX/RX lines

## UART interface

The command protocol between Master PC and PS firmware is documented in:

- [`docs/uart_protocol.md`](../docs/uart_protocol.md)

For architecture, prerequisites, and build flow of the full framework, see the root [README](../README.md).
