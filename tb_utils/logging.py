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
