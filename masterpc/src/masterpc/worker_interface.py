from __future__ import annotations

import pathlib
from dataclasses import dataclass

import serial


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

            if line.startswith("READY "):
                continue

            if line.startswith("OK"):
                return line

            if line.startswith("ERR"):
                raise RuntimeError(f"SoC rejected '{command}': {line}")

    def ping(self) -> str:
        return self.send("PING")

    def start(self) -> str:
        return self.send("START")

    def stop(self) -> str:
        return self.send("STOP")

    def step(self) -> str:
        return self.send("STEP")

    def reset(self, boot_addr: int | None = None) -> str:
        if boot_addr is None:
            return self.send("RESET")
        return self.send(f"RESET 0x{boot_addr:08X}")

    def get_pc(self) -> int:
        response = self.send("GET_PC")
        return parse_int(response.split()[1])

    def set_pc(self, pc_addr: int) -> str:
        return self.send(f"SET_PC 0x{pc_addr:08X}")

    def get_reg(self, reg_idx: int) -> int:
        response = self.send(f"GET_REG {reg_idx}")
        return parse_int(response.split()[1])

    def read_word(self, addr: int) -> int:
        response = self.send(f"READ_WORD 0x{addr:08X}")
        return parse_int(response.split()[1])

    def write_word(self, addr: int, value: int) -> str:
        return self.send(f"WRITE_WORD 0x{addr:08X} 0x{value & 0xFFFFFFFF:08X}")

    def fault_reg(self, reg_idx: int, mode: int, mask: int) -> str:
        return self.send(f"FAULT_REG {reg_idx} {mode} 0x{mask & 0xFFFFFFFF:08X}")

    def fault_mem(self, addr: int, mode: int, mask: int) -> str:
        return self.send(f"FAULT_MEM 0x{addr:08X} {mode} 0x{mask & 0xFFFFFFFF:08X}")


def read_words_from_text(path: pathlib.Path) -> list[int]:
    words: list[int] = []
    for line in path.read_text(encoding="utf-8").splitlines():
        stripped = line.split("#", 1)[0].strip()
        if not stripped:
            continue
        words.append(parse_int(stripped) & 0xFFFFFFFF)
    return words
