def log_alu_result(dut):
    """
    ALU logging
    """

    dut._log.info(
        f"ctrl={dut.alu_ctrl.value.binstr} | "
        f"src1={dut.src1.value.hex()} | "
        f"src2={dut.src2.value.hex()} | "
        f"result={dut.alu_result.value.hex()}"
    )
