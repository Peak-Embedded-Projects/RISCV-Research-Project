# UART Control Protocol (Master PC <-> PS)

This document defines the text-based UART protocol between the Master PC Python client and the Xilinx PS firmware.

## Transport

- Baud rate: 115200
- Framing: ASCII text lines, one command per line
- Command terminator: `\n` (LF)
- Response terminator: `\n` (LF)

Each command returns exactly one response line:

- Success: `OK` or `OK <value>`
- Error: `ERR <reason>`

## Protocol Version

Use this command to verify protocol compatibility before issuing workflow commands.

Request:

- `PROTOCOL_VERSION`

Response:

- `OK 1` (decimal integer)

Current protocol version: `1`

## Commands

### Acknowledgement commands (response is exactly `OK`)

- `START`
- `STOP`
- `STEP`
- `RESET`
- `RESET <boot_addr>`
- `SET_PC <addr>`
- `WRITE_WORD <addr> <value>`
- `FAULT_REG <reg_idx> <mode> <mask>`
- `FAULT_MEM <addr> <mode> <mask>`

### Read commands (response format is `OK <value>`)

- `GET_PC`
- `GET_REG <reg_idx>`
- `READ_WORD <addr>`

For `GET_PC`, `GET_REG`, and `READ_WORD`, `<value>` is returned as hex (`0x........`).
For `PROTOCOL_VERSION`, `<value>` is returned as decimal (`1`).

## Numeric Formats

The firmware accepts C-style integer parsing (`strtoul` base 0):

- Hex: `0x40000000`
- Decimal: `1073741824`

All values are treated as unsigned 32-bit quantities.

Out-of-range values are rejected with `ERR`.

## Validation Rules

- Register index must be in `[0, 31]`.
- Fault mode must be in `[0, 3]`.
- `FAULT_MEM` address must be 4-byte aligned.
- Overlong UART lines are rejected as `ERR LINE_TOO_LONG`.

Fault mode mapping:

- `0`: overwrite
- `1`: xor-mask
- `2`: or-mask
- `3`: and-not-mask

## Typical Session

1. Master opens serial port.
2. Master sends `PROTOCOL_VERSION` and checks `OK 1`.
3. Master runs control/read/fault commands.

## Firmware Source of Truth

- PS parser and command handling: `platforms/xilinx/src/main.c`
- Python client wrapper: `masterpc/src/masterpc/worker_interface.py`
