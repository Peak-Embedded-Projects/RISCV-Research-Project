def log_alu_result(dut):
    """
    ALU logging
    """

    dut._log.info(
        f"ctrl={dut.alu_ctrl.value.binstr} | "
        f"src1={hex(dut.src1.value)} | "
        f"src2={hex(dut.src2.value)} | "
        f"result={hex(dut.result.value)}"
    )


def log_registers(dut):
    """
    Register File logging
    """

    dut._log.info(
        f"rs1_addr={int(dut.rs1_addr.value):02d} | rs2_addr={int(dut.rs2_addr.value):02d} | "
        f"rs1={hex(dut.rs1.value)} | rs2={hex(dut.rs2.value)} | "
        f"wrt_addr={int(dut.write_addr.value):02d} | wrt_dat={hex(dut.write_data.value)} | "
        f"write={dut.write_enable.value}"
    )


def log_err(exp, act) -> str:
    """
    Prepare incorrect value log
    """

    return f"Expected {hex(exp)}, got {hex(act)}"
