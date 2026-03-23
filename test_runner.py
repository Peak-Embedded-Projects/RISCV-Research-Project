"""
This script is responsible for detecting and executing all
available tests from either cores/componenets_testbenches/ or
platforms/simulated/.
It assumes that build.py sets variables: TARGET_HDL,
TARGET_IP_CORE and TEST_MODE inside .sim_run_config.json
and then calls this script via pytest
"""

import json
from pathlib import Path
from typing import List

import pytest

from cocotb_tools.runner import get_runner

ROOT_DIR = Path(__file__).resolve().parent
COMPONENTS_TESTBENCHES_DIR = ROOT_DIR / "cores" / "components_testbenches"
SIMULATED_CPU_DIR = ROOT_DIR / "platforms" / "simulated"

EXT_MAP = {
    "verilog": [".v", ".vh"],
    "systemverilog": [".sv", ".sv"],
    "vhdl": [".vhd", ".vhd"],
}

SIMULATOR_MAP = {"verilog": "icarus", "vhdl": "ghdl"}


def read_sim_config() -> tuple:
    """
    Read .sim_run_config.jsonv
    """

    with open(".sim_run_config.json", "r") as f:
        sim_config = json.load(f)

    return (
        sim_config["CORE"],
        sim_config["HDL"],
        sim_config["MODE"],
        sim_config["TESTS_TO_RUN"],
    )


def discover_tests() -> List[dict]:
    """
    Discover tests based on the mode.
    """

    configs = []
    TARGET_IP_CORE, TARGET_HDL, TEST_MODE, tests_to_do = read_sim_config()

    # Assumes that *.v, *.vhd, *.sv files are inside hdl/
    # while (System)Verilog headers and VHDL packages are inside include/
    core_source_path = ROOT_DIR / "cores" / TARGET_IP_CORE / "src" / "hdl"
    core_include_path = ROOT_DIR / "cores" / TARGET_IP_CORE / "src" / "include"

    file_extension = EXT_MAP[TARGET_HDL]

    # TODO: for vhdl this won't be needed
    # include_files = list(core_include_path.rglob(f"*{file_extension[1]}"))
    sources = list(core_source_path.rglob(f"*{file_extension[0]}"))
    if TEST_MODE == "components":
        for test in tests_to_do:
            hw_name = test.replace("test_", "")
            # source = core_source_path / (hw_name + file_extension[0])
            # TODO: VHDL support needs to be well-thought in terms of
            #       how generics can be detected, passed.. maybe the easiest
            #       is to have a map of all components and their generics with defaults
            #       that could be used here. In any case some if statement is needed as
            #       VHDL config should not have includes inlcudes key but parameters instead!
            config = {
                "id": f"{test}_tb",
                "sim": SIMULATOR_MAP[TARGET_HDL],
                "hdl_toplevel": hw_name,
                "test_module": f"cores.components_testbenches.{test}",
                "sources": sources,
                "waves": True,
                "includes": [core_include_path],
            }
            configs.append(config)
    else:
        # sources = list(core_source_path.rglob(f"*{file_extension[0]}"))
        # TODO: can we make an assumption that the topmodule
        #       for the whole core is called riscv_cpu?
        # TODO: think how to pass information about program/programs
        #       to execute
        config = {
            "id": "riscv_simulated",
            "sim": SIMULATOR_MAP[TARGET_HDL],
            "hdl_toplevel": "riscv_cpu",
            "test_module": "platforms.simulated.test_full_cpu",
            "sources": sources,
            "waves": True,
            "includes": [core_include_path],
        }
        configs.append(config)

    return configs


TEST_CONFIG = discover_tests()
config_ids = [config["id"] for config in TEST_CONFIG]


@pytest.mark.parametrize("config", TEST_CONFIG, ids=config_ids)
def test_generic_runner(config: dict) -> None:
    """
    Main tests runner using pytest and cocotb
    """

    TARGET_IP_CORE, TARGET_HDL, TEST_MODE, _ = read_sim_config()

    test_id = config["id"]
    runner = get_runner(config["sim"])

    if TEST_MODE == "components":
        build_dir = COMPONENTS_TESTBENCHES_DIR / "build" / test_id
        log_dir = COMPONENTS_TESTBENCHES_DIR / "log" / test_id
    else:
        build_dir = SIMULATED_CPU_DIR / "build" / TARGET_IP_CORE / test_id
        log_dir = SIMULATED_CPU_DIR / "log" / TARGET_IP_CORE / test_id

    build_dir.mkdir(parents=True, exist_ok=True)
    log_dir.mkdir(parents=True, exist_ok=True)

    build_log_file = log_dir / f"{test_id}_build.log"
    test_log_file = log_dir / f"{test_id}_test.log"

    # TODO: add different versions for vhdl (maybe system verilog as well)
    runner.build(
        sources=config["sources"],
        hdl_toplevel=config["hdl_toplevel"],
        includes=config["includes"],
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
        extra_env={"TARGET_CORE": TARGET_IP_CORE},
    )
