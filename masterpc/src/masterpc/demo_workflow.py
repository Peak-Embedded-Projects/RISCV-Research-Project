from __future__ import annotations

from .worker_interface import WorkerInterface

# Same program that used to be hardcoded in the SoC C test app.
DEMO_PROGRAM: list[int] = [
    0x0AB00293,  # addi x5, x0, 171
    0x0CD00313,  # addi x6, x0, 205
    0x0EF00393,  # addi x7, x0, 239
    0x40001537,  # li x10, 0x40001000
    0x00550023,  # sb x5, 0(x10)
    0x006500A3,  # sb x6, 1(x10)
    0x005502A3,  # sb x5, 5(x10)
    0x00750423,  # sb x7, 8(x10)
    0x00752623,  # sw x7, 12(x10)
    0x0000006F,  # j 0
]


def upload_words(
    client: WorkerInterface, base_addr: int, words: list[int], verify: bool = False
) -> None:
    client.stop()
    for idx, word in enumerate(words):
        client.write_word(base_addr + (idx * 4), word)

    if verify:
        for idx, expected in enumerate(words):
            addr = base_addr + (idx * 4)
            actual = client.read_word(addr)
            if actual != expected:
                raise RuntimeError(
                    f"Upload verify failed at 0x{addr:08X}: "
                    f"expected 0x{expected:08X}, got 0x{actual:08X}"
                )


def _expect_eq(label: str, actual: int, expected: int) -> None:
    if actual != expected:
        raise RuntimeError(f"{label}: expected 0x{expected:08X}, got 0x{actual:08X}")


def run_demo_program_test(client: WorkerInterface, boot_addr: int) -> None:
    data_addr = 0x40001000
    upload_words(client, boot_addr, DEMO_PROGRAM, verify=True)
    client.reset(boot_addr)

    _expect_eq("PC after reset", client.get_pc(), boot_addr)

    client.step()
    _expect_eq("PC after step 1", client.get_pc(), boot_addr + 0x04)
    _expect_eq("x5", client.get_reg(5), 0x000000AB)

    client.step()
    _expect_eq("PC after step 2", client.get_pc(), boot_addr + 0x08)
    _expect_eq("x6", client.get_reg(6), 0x000000CD)

    client.step()
    _expect_eq("PC after step 3", client.get_pc(), boot_addr + 0x0C)
    _expect_eq("x7", client.get_reg(7), 0x000000EF)

    client.step()
    _expect_eq("PC after step 4", client.get_pc(), boot_addr + 0x10)
    _expect_eq("x10", client.get_reg(10), data_addr)

    client.step()
    _expect_eq("Mem[DATA+0]", client.read_word(data_addr + 0x00) & 0xFF, 0xAB)

    client.step()
    _expect_eq("Mem[DATA+1]", (client.read_word(data_addr + 0x00) >> 8) & 0xFF, 0xCD)

    client.step()
    _expect_eq("Mem[DATA+5]", (client.read_word(data_addr + 0x04) >> 8) & 0xFF, 0xAB)

    client.step()
    _expect_eq("Mem[DATA+8]", client.read_word(data_addr + 0x08) & 0xFF, 0xEF)

    client.step()
    _expect_eq("Mem[DATA+12]", client.read_word(data_addr + 0x0C), 0x000000EF)
