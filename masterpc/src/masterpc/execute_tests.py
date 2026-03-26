from __future__ import annotations
from pathlib import Path

from .worker_interface import WorkerInterface


def expect_word_equal(
    base_addr: int, actual_value: int, expected_value: int, title: str = "Value"
) -> None:
    expected_values = [expected_value, (expected_value + base_addr) & 0xFFFFFFFF]
    if actual_value not in expected_values:
        print(
            f"{title} mismatch: expected 0x{expected_value:08X} or 0x{(expected_value + base_addr) & 0xFFFFFFFF:08X}, got 0x{actual_value:08X}"
        )


def execute_all_test_cases(client: WorkerInterface) -> None:
    test_cases_dir = (
        Path(__file__).parent.parent.parent.parent / "cores" / "test_programs"
    )
    for test_case_dir in sorted(test_cases_dir.iterdir()):
        if not test_case_dir.is_dir():
            continue
        for test_case_sub_dir in sorted(test_case_dir.iterdir()):
            if not test_case_sub_dir.is_dir():
                continue
            print(f"\n=== Executing test case: {test_case_sub_dir.name} ===")
            execute_test_case(client, test_case_sub_dir)


def execute_test_case(client: WorkerInterface, test_base_path: Path) -> None:
    """Basic end-to-end test for FAULT_REG and FAULT_MEM commands."""
    base_addr = 0x40000000
    data_addr = base_addr
    boot_addr = base_addr + 0x1000

    client.stop()  # ensure core is stopped before setup

    with open(test_base_path / "program.hex", "r") as f:
        program = [int(line.strip(), 16) for line in f if line.strip()]

    with open(test_base_path / "memory.hex", "r") as f:
        initial_memory = [int(line.strip(), 16) for line in f if line.strip()]

    with open(test_base_path / "expected_registers.hex", "r") as f:
        expected_registers = [int(line.strip(), 16) for line in f if line.strip()]
        assert len(expected_registers) == 31, "Expected exactly 31 register values"

    with open(test_base_path / "expected_memory.hex", "r") as f:
        expected_memory = [int(line.strip(), 16) for line in f if line.strip()]

    print("Setting all registers to zero before the test")
    for i in range(1, 32):
        client.set_reg(i, 0)

    print("resetting memory")
    for i, _ in enumerate(expected_memory):
        client.write_word(data_addr + (i * 4), 0)

    print("Setting initial memory values before the test")
    client.upload_words(boot_addr, program, verify=False)
    client.upload_words(data_addr, initial_memory, verify=False)
    print("Stopping core and setting PC to boot address")
    client.stop()
    client.set_pc(boot_addr)

    for i in range(1000):  # avoid running forever
        pc = client.get_pc()
        instr = client.read_word(pc)
        print(f"Step {i:03d}: PC=0x{pc:08X}, instr=0x{instr:08X}")
        if instr == 0x0000006F:  # JAL x0, 0 (infinite loop)
            print("Reached infinite loop, stopping execution.")
            break
        client.step()

    for i in range(1, 32):
        reg_val = client.get_reg(i)
        # print(f"x{i} = 0x{reg_val:08X}")
        expect_word_equal(
            base_addr, reg_val, expected_registers[i - 1], f"Register x{i}"
        )

    for i, expected_word in enumerate(expected_memory):
        mem_val = client.read_word(data_addr + (i * 4))
        # print(f"Mem[0x{data_addr + (i * 4):08X}] = 0x{mem_val:08X}")
        expect_word_equal(
            base_addr, mem_val, expected_word, f"Memory at 0x{data_addr + (i * 4):08X}"
        )
