import json
import click
import logging
from typing import Optional
from pathlib import Path
from enum import StrEnum

BUILD_CACHE_DIR = Path(".build_cache")
IP_REPO_DIR = Path("build/ip_repos")
BUILD_SCRIPTS = Path("scripts")
LOGS_DIR = Path("logs")
BUILD_DIR = Path("build")

HARDWARE_CONFIG_FILE = Path("hardware.json")
CORES_ROOT = Path("cores")

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


@click.command()
@click.option(
    "--runtime",
    type=click.Choice(["HARDWARE", "SIMULATION"], case_sensitive=False),
    help="Target Runtime",
)
@click.option("--vendor", type=str, help="FPGA Vendor (HARDWARE only)")
@click.option("--board", type=str, help="FPGA Target Board (HARDWARE only)")
@click.option("--core", type=str, help="RISC-V IP Core")
def launch(
    runtime: Optional[str], vendor: Optional[str], board: Optional[str], core: str
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

    click.secho("\n=== Configuration Summary ===", fg="green", bold=True)
    click.echo(f"Runtime: {runtime}")
    if runtime == "HARDWARE":
        click.echo(f"Vendor:  {vendor}")
        click.echo(f"Board:   {board}")
    click.echo(f"Core:    {core}")

    # TODO: here the building begins


if __name__ == "__main__":
    launch()
