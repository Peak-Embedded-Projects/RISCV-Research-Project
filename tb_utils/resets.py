from cocotb.triggers import ClockCycles


async def reset_active_high(rst_pin, clk_pin, cycles=5) -> None:
    """
    Asserts an active-high reset for a given number of clock cycles
    """

    rst_pin.value = 1
    await ClockCycles(clk_pin, cycles)
    rst_pin.value = 0
    await ClockCycles(clk_pin, 1)


async def reset_active_low(rstn_pin, clk_pin, cycles=5) -> None:
    """
    Asserts an active-low reset for a given number of clock cycles
    """

    rstn_pin.value = 0
    await ClockCycles(clk_pin, cycles)
    rstn_pin.value = 1
    await ClockCycles(clk_pin, 1)
