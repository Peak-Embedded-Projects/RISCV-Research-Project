"""
This is the main script used to both prepare the hardware implementation as well as
run selected simulation for a given RISC-V Core.
It is intended to be used within uv virtual environment either as an interactive CLI:
$ uv run python build.py
or (just an example)
$ uv run python build.py --runtime hardware --vendor xilinx --board "Zybo Z7-20" \
                         --core rv32i --hdl verilog

REMARKS: it currently supports only Xilinx hardware.
"""

import json
import logging
from enum import Enum
from pathlib import Path
from typing import Optional, List, Union

import click

import platforms.xilinx.riscv_build_utils as rv

HARDWARE_CONFIG_FILE = Path("hardware.json")
CORES_ROOT = Path("cores")
PLATFORMS_DIR = Path("platforms/")

logging.basicConfig(
    level=logging.INFO,
    format="[%(levelname)s] %(message)s",
    handlers=[logging.StreamHandler()],
)


class runtime_type(Enum):
    HARDWARE = "HARDWARE"
    SIMULATION = "SIMULATION"


class simulation_mode_type(Enum):
    COMPONENTS = "components"
    FULL = "full"


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
            exit(1)


def detect_tests(mode: str) -> list:
    """
    Find available tests depending on the mode type
    """

    pattern = None
    if mode == simulation_mode_type.COMPONENTS.value:
        testbenches_dir = CORES_ROOT / "components_testbenches"
        pattern = "test_*.py"
    else:
        testbenches_dir = CORES_ROOT / "test_programs"
        pattern = "*.S"
    if not testbenches_dir.exists():
        logging.error(f"{testbenches_dir.name} doesn't exist")
        exit(1)

    return [t for t in testbenches_dir.rglob(pattern)]


def get_riscv_cores() -> dict:
    """
    Return RISC-V IP Cores from cores/ directory
    """

    if not CORES_ROOT.exists():
        logging.error(f"{CORES_ROOT.name} doesn't exist")
        exit(1)

    return {
        p.name: p
        for p in CORES_ROOT.iterdir()
        if p.is_dir() and p.name not in ["test_programs", "components_testbenches"]
    }


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

    block_diagram_config = {"PROJECT_NAME": "RISC_V_worker_PL_layer", "XSA": xsa_name}
    click.secho(
        f"\n=== Building {block_diagram_config['PROJECT_NAME']} ===",
        fg="green",
        bold=True,
    )
    pl_layer = rv.fpga_design(config=block_diagram_config, dependencies=[riscv_ip])
    pl_layer.build(hw)

    soc_config = {
        "WORKSPACE": "vitis_ws",
        "PLATFORM": "RISC_V_worker_PS_layer_platform",
        "APPLICATION": "RISC_V_worker_PS_application",
    }

    click.secho(f"\n=== Building {soc_config['PLATFORM']} ===", fg="green", bold=True)
    ps_layer = rv.soc_design(config=soc_config, pl_layer=pl_layer)
    ps_layer.build(hw)


@click.command()
@click.option(
    "--runtime",
    type=click.Choice([e.value for e in runtime_type], case_sensitive=False),
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
@click.option(
    "--mode",
    type=click.Choice(["components", "full"], case_sensitive=False),
    help="Specify whether to verify components of RISC-V core or an entire CPU",
)
@click.option(
    "--which",
    type=str,
    multiple=True,
    help="Specify whether to test ALL or selected tests",
)
def launch(
    runtime: Optional[str],
    vendor: Optional[str],
    board: Optional[str],
    core: Optional[str],
    hdl: Optional[str],
    mode: Optional[str],
    which: Optional[Union[List[str], str]],
) -> None:
    """
    Interactive HDL Build Configuration tool
    """

    if not runtime:
        runtime = click.prompt(
            "Select Runtime",
            type=click.Choice([e.value for e in runtime_type], case_sensitive=False),
            default="SIMULATION",
        )
    runtime = runtime.upper()

    if runtime == runtime_type.HARDWARE.value:
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

    elif runtime == runtime_type.SIMULATION.value:
        if not mode:
            mode = click.prompt(
                "Select mode",
                type=click.Choice(
                    [e.value for e in simulation_mode_type], case_sensitive=False
                ),
                default="components",
            )
        mode = mode.lower()
        available_tests_paths = detect_tests(mode)

        test_mapping = {}
        if mode == "components":
            for p in available_tests_paths:
                display_name = p.stem
                test_mapping[display_name] = p.stem
        else:
            testbenches_dir = CORES_ROOT / "test_programs"
            for p in available_tests_paths:
                display_name = f"{p.parent.relative_to(testbenches_dir)}/"
                test_mapping[display_name] = str(p.relative_to(testbenches_dir))

        test_mapping["all"] = "all"

        logging.info(f"For mode {mode} detected following tests:")
        for t in test_mapping.keys():
            if t != "all":
                print(t)

        if not which:
            which = click.prompt(
                "Select test/tests",
                type=click.Choice(list(test_mapping.keys()), case_sensitive=False),
                show_choices=False,
            )

        which_test_name_match = next(
            (t for t in test_mapping.keys() if t.lower() == which.lower()), None
        )

        if not which_test_name_match:
            logging.error(f"Test: {which} not found.")
            exit(1)

        if which_test_name_match.lower() == "all":
            which = [val for key, val in test_mapping.items() if key != "all"]
        else:
            which = test_mapping[which_test_name_match]
        # TODO: here mutliple environmental variables have to set as well as a temporary file with tests to run (for the runner to see them)
    else:
        logging.error(
            f"{runtime} not supported, choose one of {[e.value for e in runtime_type]}"
        )
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
    else:
        click.echo(f"Mode:   {mode}")
        click.echo(f"Tests:   {which}")
    click.echo(f"Core:    {core}")
    click.echo(f"HDL:    {hdl}")

    if runtime == runtime_type.HARDWARE.value:
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
