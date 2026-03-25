from __future__ import annotations

import pathlib
from dataclasses import dataclass

import serial


MODE_MAX = 3
REG_MAX = 31
PROTOCOL_VERSION_CMD = "PROTOCOL_VERSION"
GET_PC_CMD = "GET_PC"
GET_REG_CMD = "GET_REG"
READ_WORD_CMD = "READ_WORD"


def parse_int(value: str) -> int:
    return int(value, 0)


@dataclass
class WorkerInterface:
    port: str
    timeout_s: float = 1.0
    verbose: bool = False

    def __post_init__(self) -> None:
        self.ser = serial.Serial(self.port, 115200, timeout=self.timeout_s)
        self.ser.reset_input_buffer()
        self.ser.reset_output_buffer()

    def close(self) -> None:
        if self.ser.is_open:
            self.ser.close()

    def __enter__(self) -> "WorkerInterface":
        return self

    def __exit__(self, exc_type, exc, tb) -> None:
        self.close()

    def send(self, command: str) -> str:
        if self.verbose:
            print(f">>> {command}")
        self.ser.write((command + "\n").encode("ascii"))
        self.ser.flush()

        while True:
            raw = self.ser.readline()
            if not raw:
                raise TimeoutError(f"No response for command: {command}")
            if self.verbose:
                print(f"<<< {raw!r}")

            line = raw.decode("ascii", errors="replace").strip()
            if not line:
                continue

            if line.startswith("OK"):
                return line

            if line.startswith("ERR"):
                raise RuntimeError(f"SoC rejected '{command}': {line}")

            raise RuntimeError(f"Unexpected SoC response for '{command}': {line!r}")

    def _send_ack(self, command: str) -> None:
        response = self.send(command)
        if response != "OK":
            raise RuntimeError(f"Malformed ACK response for '{command}': {response!r}")

    def _send_u32(self, command: str) -> int:
        response = self.send(command)
        return self._parse_ok_u32(response, command)

    def _parse_ok_u32(self, response: str, command: str) -> int:
        parts = response.split()
        if len(parts) != 2 or parts[0] != "OK":
            raise RuntimeError(f"Malformed OK response for '{command}': {response!r}")
        try:
            return parse_int(parts[1]) & 0xFFFFFFFF
        except ValueError as exc:
            raise RuntimeError(
                f"Malformed numeric payload for '{command}': {response!r}"
            ) from exc

    def _check_reg_idx(self, reg_idx: int) -> None:
        if reg_idx < 0 or reg_idx > REG_MAX:
            raise ValueError(f"reg_idx must be in [0, {REG_MAX}], got {reg_idx}")

    def _check_mode(self, mode: int) -> None:
        if mode < 0 or mode > MODE_MAX:
            raise ValueError(f"mode must be in [0, {MODE_MAX}], got {mode}")

    def _check_word_addr(self, addr: int, name: str) -> None:
        if addr & 0x3:
            raise ValueError(f"{name} must be 4-byte aligned, got 0x{addr:08X}")

    def protocol_version(self) -> int:
        return self._send_u32(PROTOCOL_VERSION_CMD)

    def start(self) -> None:
        self._send_ack("START")

    def stop(self) -> None:
        self._send_ack("STOP")

    def step(self) -> None:
        self._send_ack("STEP")

    def get_pc(self) -> int:
        return self._send_u32(GET_PC_CMD)

    def set_pc(self, pc_addr: int) -> None:
        self._send_ack(f"SET_PC 0x{pc_addr:08X}")

    def get_reg(self, reg_idx: int) -> int:
        self._check_reg_idx(reg_idx)
        return self._send_u32(f"{GET_REG_CMD} {reg_idx}")

    def set_reg(self, reg_idx: int, value: int) -> None:
        self._check_reg_idx(reg_idx)
        self._send_ack(f"SET_REG {reg_idx} 0x{value & 0xFFFFFFFF:08X}")

    def read_word(self, addr: int) -> int:
        self._check_word_addr(addr, "addr")
        return self._send_u32(f"{READ_WORD_CMD} 0x{addr:08X}")

    def write_word(self, addr: int, value: int) -> None:
        self._check_word_addr(addr, "addr")
        self._send_ack(f"WRITE_WORD 0x{addr:08X} 0x{value & 0xFFFFFFFF:08X}")

    def fault_reg(self, reg_idx: int, mode: int, mask: int) -> None:
        self._check_reg_idx(reg_idx)
        self._check_mode(mode)
        self._send_ack(f"FAULT_REG {reg_idx} {mode} 0x{mask & 0xFFFFFFFF:08X}")

    def fault_mem(self, addr: int, mode: int, mask: int) -> None:
        self._check_word_addr(addr, "addr")
        self._check_mode(mode)
        self._send_ack(f"FAULT_MEM 0x{addr:08X} {mode} 0x{mask & 0xFFFFFFFF:08X}")

    def upload_words(
        self, base_addr: int, words: list[int], verify: bool = False
    ) -> None:
        for idx, word in enumerate(words):
            self.write_word(base_addr + (idx * 4), word)

        if verify:
            for idx, expected in enumerate(words):
                addr = base_addr + (idx * 4)
                actual = self.read_word(addr)
                if actual != expected:
                    raise RuntimeError(
                        f"Upload verify failed at 0x{addr:08X}: "
                        f"expected 0x{expected:08X}, got 0x{actual:08X}"
                    )


def read_words_from_text(path: pathlib.Path) -> list[int]:
    words: list[int] = []
    for line in path.read_text(encoding="utf-8").splitlines():
        stripped = line.split("#", 1)[0].strip()
        if not stripped:
            continue
        words.append(parse_int(stripped) & 0xFFFFFFFF)
    return words
