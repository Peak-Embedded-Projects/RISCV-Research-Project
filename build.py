import json
import click
import logging
from typing import Optional
from pathlib import Path, PurePath
from enum import StrEnum

import platforms.xilinx.riscv_build_utils as rv


HARDWARE_CONFIG_FILE = Path("hardware.json")
CORES_ROOT = Path("cores")
PLATFORMS_DIR = Path("platforms/")

logging.basicConfig(
    level=logging.INFO,
    format="[%(levelname)s] %(message)s",
    handlers=[logging.StreamHandler()],
)


class runtime_type(StrEnum):
    HARDWARE = "HARDWARE"
    SIMULATION = "SIMULATION"


def load_vendors_and_boards() -> dict:
    """
    Load vendors/boards configuration from json
    """

    if not HARDWARE_CONFIG_FILE.exists():
        logging.error(f"{HARDWARE_CONFIG_FILE.name} doesn't exist")
        exit(1)

    with open(HARDWARE_CONFIG_FILE, "r") as f:
        try:
            return json.load(f)
        except json.JSONDecodeError as err:
            logging.error(f"Cannot parse {HARDWARE_CONFIG_FILE.name}: {err}")


def get_riscv_cores() -> dict:
    """
    Return RISC-V IP Cores from cores/ directory
    """

    if not CORES_ROOT.exists():
        logging.error(f"{CORES_ROOT.name} doesn't exist")
        exit(1)

    return {p.name: p for p in CORES_ROOT.iterdir() if p.is_dir()}

# TODO: move xilinx implementation to a separate function, this function should
#       be imported from platforms/xilinx/ directory
def runtime_hardware_handler(
    vendor: str, hw: rv.hardware, core: Path, hdl: str
) -> None:
    
    ip_name = f"{core.name}_{hdl}"
    xsa_name = ip_name + "_hardware.xsa"

    vendor_platform_path = PLATFORMS_DIR / vendor.lower()
    core_config = {
        "IP_NAME": ip_name,
        "IP_VENDOR": "ISAE",
        "IP_LIBRARY": "user",
        "IP_VERSION": "1.0",  # TODO: how to properly handle here the version of IP Core ?
        "HDL": hdl,
    }

    rv.BUILD_CACHE_DIR = vendor_platform_path / rv.BUILD_CACHE_DIR
    rv.IP_REPO_DIR = vendor_platform_path / rv.IP_REPO_DIR
    rv.BUILD_SCRIPTS = vendor_platform_path / rv.BUILD_SCRIPTS
    rv.LOGS_DIR = vendor_platform_path / rv.LOGS_DIR
    rv.BUILD_DIR = vendor_platform_path / rv.BUILD_DIR
    rv.C_SRC = vendor_platform_path / rv.C_SRC
    rv.INC_FILES = vendor_platform_path / rv.INC_FILES

    click.secho(f"\n=== Building {core.name}_{hdl} ===", fg="green", bold=True)
    riscv_ip = rv.ip_core(core_dir=core, config=core_config)
    riscv_ip.build(hw)

    block_diagram_config = {
      "PROJECT_NAME" : "RISC_V_worker_PL_layer",
      "XSA"          : xsa_name
    }
    click.secho(f"\n=== Building {block_diagram_config["PROJECT_NAME"]} ===", fg="green", bold=True)
    pl_layer = rv.fpga_design(config=block_diagram_config, dependencies=[riscv_ip])
    pl_layer.build(hw)

    soc_config = {
      "WORKSPACE"    : "vitis_ws",
      "PLATFORM"     : "RISC_V_worker_PS_layer_platform",
      "APPLICATION"  : "RISC_V_worker_PS_application",
    }

    click.secho(f"\n=== Building {soc_config["PLATFORM"]} ===", fg="green", bold=True)
    ps_layer = rv.soc_design(config=soc_config, pl_layer=pl_layer)
    ps_layer.build(hw)

@click.command()
@click.option(
    "--runtime",
    type=click.Choice(["HARDWARE", "SIMULATION"], case_sensitive=False),
    help="Target Runtime",
)
@click.option("--vendor", type=str, help="FPGA Vendor (HARDWARE only)")
@click.option("--board", type=str, help="FPGA Target Board (HARDWARE only)")
@click.option("--core", type=str, help="RISC-V IP Core")
@click.option(
    "--hdl",
    type=click.Choice(["verilog", "vhdl", "systemverilog"], case_sensitive=False),
    help="HDL of IP Core",
)
def launch(
    runtime: Optional[str],
    vendor: Optional[str],
    board: Optional[str],
    core: Optional[str],
    hdl: Optional[str],
) -> None:
    """
    Interactive HDL Build Configuration tool
    """

    if not runtime:
        runtime = click.prompt(
            "Select Runtime",
            type=click.Choice(["HARDWARE", "SIMULATION"], case_sensitive=False),
            default="SIMULATION",
        )
    runtime = runtime.upper()

    if runtime == runtime_type.HARDWARE:
        data = load_vendors_and_boards()
        available_vendors = list(data.keys())

        if not vendor:
            vendor = click.prompt(
                "Select vendor",
                type=click.Choice(available_vendors, case_sensitive=False),
            )

        vendor_match = next(
            (v for v in available_vendors if v.lower() == vendor.lower()), None
        )
        if not vendor_match:
            logging.error(
                f"Vendor: {vendor} not found in the list. Available vendors: {available_vendors}"
            )
            exit(1)

        vendor = vendor_match

        available_boards = data.get(vendor, [])
        if not board:
            board = click.prompt(
                f"Select Board for {vendor}",
                type=click.Choice(available_boards, case_sensitive=False),
            )

        board_match = next(
            (b for b in available_boards if b.lower() == board.lower()), None
        )
        if not board_match:
            logging.error(
                f"Board: {board} not found in the list. Available boards: {available_boards}"
            )
            exit(1)

        board = board_match
        board_params = available_boards[board_match]

    elif runtime == runtime_type.SIMULATION:
        pass
    else:
        logging.error(f"{runtime} not supported")
        exit(1)

    available_cores = get_riscv_cores()
    available_cores_names = sorted(available_cores.keys())
    if not core:
        core = click.prompt(
            "Select RISC-V Core",
            type=click.Choice(available_cores, case_sensitive=False),
        )

    core_name_match = next(
        (c for c in available_cores_names if c.lower() == core.lower()), None
    )
    if not core_name_match:
        logging.error(
            f"Core: {core} not found in the list. Available cores: {available_cores_names}"
        )
        exit(1)

    core = core_name_match
    selected_core_path = available_cores[core]

    if not hdl:
        hdl = click.prompt(
            "Select HDL OF IP Core",
            type=click.Choice(
                ["verilog", "vhdl", "systemverilog"], case_sensitive=False
            ),
            default="verilog",
        )
    hdl = hdl.lower()

    click.secho("\n=== Configuration Summary ===", fg="green", bold=True)
    click.echo(f"Runtime: {runtime}")
    if runtime == "HARDWARE":
        click.echo(f"Vendor:  {vendor}")
        click.echo(f"Board:   {board}")
    click.echo(f"Core:    {core}")
    click.echo(f"HDL:    {hdl}")

    if runtime == runtime_type.HARDWARE:
        hw = rv.hardware(
            target=board_params["TARGET"],
            board=board_params["BOARD"],
            cpu=board_params["CPU"],
        )
        runtime_hardware_handler(vendor=vendor, hw=hw, core=selected_core_path, hdl=hdl)
    else:
        pass


if __name__ == "__main__":
    launch()
