"""
This script is responsible for detecting and executing all
available tests from either cores/componenets_testbenches/ or
platforms/simulated/.
It assumes that build.py sets environmental variables: TARGET_HDL,
TARGET_IP_CORE and TEST_MODE and then calls this script via pytest
"""

import os
from pathlib import Path
from typing import List

import pytest

from cocotb_tools.runner import get_runner

ROOT_DIR = Path(__file__).resolve().parent
COMPONENTS_TESTBENCHES_DIR = ROOT_DIR / "cores" / "components_testbenches"
SIMULATED_CPU_DIR = ROOT_DIR / "platforms" / "simulated"

# Environmental variables set by build.py before calling this script
TARGET_HDL: str = os.getenv("TARGET_HDL")
TARGET_IP_CORE: str = os.getenv("TARGET_RISCV_IP")
TEST_MODE: str = os.getenv("TEST_MODE")

EXT_MAP = {
    "verilog": [".v", ".vh"],
    "systemverilog": [".sv", ".sv"],
    "vhdl": [".vhd", ".vhd"],
}

SIMULATOR_MAP = {"verilog": "icarus", "vhdl": "ghdl"}


def discover_tests() -> List[dict]:
    """
    Discover tests based on the mode.
    """

    configs = []

    tests_path = (
        COMPONENTS_TESTBENCHES_DIR if TEST_MODE == "components" else SIMULATED_CPU_DIR
    )

    # Assumes that *.v, *.vhd, *.sv files are inside hdl/
    # while (System)Verilog headers and VHDL packages are inside include/
    core_source_path = ROOT_DIR / TARGET_IP_CORE / "src" / "hdl"
    core_include_path = ROOT_DIR / TARGET_IP_CORE / "src" / "include"

    file_extension = EXT_MAP[TARGET_HDL]
    include_files = list(core_include_path.rglob(f"*{file_extension[1]}"))

    # TODO: so far components mode will always execute all testbenches...
    #       das ist nich ideal, we might want to select which testbench/ set of
    #       them to run
    if TEST_MODE == "components":
        for test_file in tests_path.rglob("test_*.py"):
            module_name = test_file.stem.replace("test_", "")
            source = core_source_path / (module_name + file_extension[0])

            # TODO: VHDL support needs to be well-thought in terms of
            #       how generics can be detected, passed.. maybe the easiest
            #       is to have a map of all components and their generics with defaults
            #       that could be used here. In any case some if statement is needed as
            #       VHDL config should not have includes inlcudes key but parameters instead!
            config = {
                "id": f"{module_name}_tb",
                "sim": SIMULATOR_MAP[TARGET_HDL],
                "hdl_toplevel": module_name,
                "test_module": f"cores.components_testbenches.{test_file.stem}",
                "sources": source,
                "waves": True,
                "includes": include_files,
            }
            configs.append(config)
    else:
        sources = list(core_source_path.rglob(f"*{file_extension[0]}"))
        # TODO: can we make an assumption that the topmodule
        #       for the whole core is called riscv_cpu?
        config = {
            "id": "riscv_simulated",
            "sim": SIMULATOR_MAP[TARGET_HDL],
            "hdl_toplevel": "riscv_cpu",
            "test_module": "platforms.simulated.test_full_cpu",
            "sources": sources,
            "waves": True,
            "includes": include_files,
        }
        configs.append(config)

    return config


TEST_CONFIG = discover_tests()
config_ids = [config["id"] for config in TEST_CONFIG]


@pytest.mark.parametrize("config", TEST_CONFIG, ids=config_ids)
def test_generic_runner(config: dict) -> None:
    """
    Main tests runner using pytest and cocotb
    """

    test_id = config["id"]
    runner = get_runner(config["sim"])

    if TEST_MODE == "components":
        build_dir = COMPONENTS_TESTBENCHES_DIR / "build" / test_id
        log_dir = COMPONENTS_TESTBENCHES_DIR / "log"
    else:
        build_dir = SIMULATED_CPU_DIR / "build"
        log_dir = SIMULATED_CPU_DIR / "log"

    build_dir.mkdir(parents=True, exist_ok=True)
    log_dir.mkdir(parents=True, exist_ok=True)

    build_log_file = log_dir / f"{test_id}_build.log"
    test_log_file = log_dir / f"{test_id}_test.log"

    # TODO: add different versions for vhdl (maybe system verilog as well)
    runner.build(
        sources=config["sources"],
        hdl_toplevel=config["hdl_toplevel"],
        includes=config["inlcudes"],
        always=True,
        build_dir=build_dir,
        waves=config["waves"],
        log_file=build_log_file,
    )

    runner.test(
        hdl_toplevel=config["hdl_toplevel"],
        test_module=config["test_module"],
        waves=config["waves"],
        build_dir=build_dir,
        log_file=test_log_file,
    )
