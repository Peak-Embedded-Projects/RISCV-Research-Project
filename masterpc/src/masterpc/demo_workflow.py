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


def _expect_eq(label: str, actual: int, expected: int) -> None:
    if actual != expected:
        raise RuntimeError(f"{label}: expected 0x{expected:08X}, got 0x{actual:08X}")


def run_demo_program_test(client: WorkerInterface) -> None:
    boot_addr = 0x40000000
    data_addr = 0x40001000
    client.upload_words(boot_addr, DEMO_PROGRAM, verify=True)
    client.stop()
    client.set_pc(boot_addr)

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


def run_fault_injection_test(client: WorkerInterface) -> None:
    """Basic end-to-end test for FAULT_REG and FAULT_MEM commands."""
    boot_addr = 0x40000000
    data_addr = 0x40001000
    probe_addr = data_addr + 0x40

    client.upload_words(boot_addr, DEMO_PROGRAM, verify=False)
    client.stop()
    client.set_pc(boot_addr)

    # Execute one instruction so x5 holds a known value (0xAB).
    client.step()
    _expect_eq("x5 before fault", client.get_reg(5), 0x000000AB)

    client.fault_reg(5, 1, 0x0000000F)  # XOR lower nibble.
    _expect_eq("x5 after FAULT_REG XOR", client.get_reg(5), 0x000000A4)

    client.write_word(probe_addr, 0x12345678)
    client.fault_mem(probe_addr, 2, 0x0000FF00)  # OR mask into byte 1.
    _expect_eq("mem after FAULT_MEM OR", client.read_word(probe_addr), 0x1234FF78)
