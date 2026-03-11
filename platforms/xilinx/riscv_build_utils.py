"""
This Python file contains implementations of classes which handle different stages
of project build workflow.
They use hash computations in order to deduce whether to rebuild a particular stage
or not.
"""

import hashlib
import logging
import subprocess
from abc import ABC, abstractmethod
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from typing import List

BUILD_CACHE_DIR = Path(".build_cache")
IP_REPO_DIR = Path("build/ip_repos")
BUILD_SCRIPTS = Path("scripts")
C_SRC = Path("src")
INC_FILES = Path("include")
LOGS_DIR = Path("logs")
BUILD_DIR = Path("build")


logging.basicConfig(
    level=logging.INFO,
    format="[%(levelname)s] %(message)s",
    handlers=[logging.StreamHandler()],
)


class generic_design(ABC):
    """
    Abstract Base Class for hash versioned build artifact
    """

    def __init__(self, name: str, version: str):
        self.name = name
        self.version = version
        self.digest_file = BUILD_CACHE_DIR / f"{self.name}.digest"

    @abstractmethod
    def _get_sources_for_hashing(self) -> List[Path]:
        """
        Return a list of file paths that contribute to the hash
        """
        pass

    @abstractmethod
    def _run_build_tool(self, h: "hardware", log_file: Path, jou_file: Path) -> None:
        """
        Execute the specific tool (Vivado/Vitis) command
        """
        pass

    @abstractmethod
    def _check_build_artifacts_exist(self) -> bool:
        """
        Look for any necessary directories that must exist in order to ensure the build
        """
        pass

    @property
    @abstractmethod
    def source_dir(self) -> Path:
        """
        Return the root source directory for this artifact
        """
        pass

    def _compute_hash(self) -> str:
        """
        Compute MD5 hash for all relevant files
        """

        hasher = hashlib.md5()
        files = sorted(self._get_sources_for_hashing())

        for filepath in files:
            if filepath.exists():
                # hash relative path
                try:
                    rel_path = filepath.relative_to(self.source_dir)
                except ValueError:
                    # if file is outside source_dir (like a dependency) use full path
                    rel_path = filepath.name

                hasher.update(str(rel_path).encode("utf-8"))

                with open(filepath, "rb") as f:
                    while chunk := f.read(4096):
                        hasher.update(chunk)

        hasher.update(self.version.encode("utf-8"))
        self._add_extra_hash_content(hasher)

        return hasher.hexdigest()

    def _add_extra_hash_content(self, hasher):
        """
        Hook for subclasses to add non-file data to hash
        (hashes of components that this object depends on;
        ex: Vivado block design depends on RISCV IP Core)
        """
        pass

    def build(self, h: "hardware") -> None:
        """
        Methodd defining the standard build workflow
        """

        logging.info(f"{self.name}: Checking status...")

        BUILD_CACHE_DIR.mkdir(exist_ok=True)
        LOGS_DIR.mkdir(exist_ok=True)
        BUILD_DIR.mkdir(exist_ok=True)

        current_hash = self._compute_hash()
        stored_hash = ""

        if self.digest_file.exists():
            with open(self.digest_file, "r") as f:
                stored_hash = f.read().strip()

        if current_hash == stored_hash and self._check_build_artifacts_exist():
            logging.info(f"{self.name}: Up to date. Skipping build.")
            logging.info(f"{self.name}: Latest build inside {BUILD_DIR}.")
            return

        logging.info(f"{self.name}: Outdated. Building...")

        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        log_file = LOGS_DIR / f"{self.name}_{timestamp}.log"
        jou_file = LOGS_DIR / f"{self.name}_{timestamp}.jou"

        try:
            self._run_build_tool(h, log_file, jou_file)

            with open(self.digest_file, "w") as f:
                f.write(current_hash)

            logging.info(f"{self.name}: Build complete.")

        except subprocess.CalledProcessError:
            logging.error(f"{self.name}: Failed. See {log_file}")
            exit(1)


@dataclass(frozen=True)
class hardware:
    """
    Class containing target platform details
    """

    target: str
    board: str
    cpu: str


class ip_core(generic_design):
    """
    Class implementing RISC-V IP Core used to create the IP for the worker
    """

    def __init__(self, core_dir: Path, config: dict) -> None:
        self.core_dir = core_dir
        super().__init__(name=config["IP_NAME"], version=config["IP_VERSION"])
        self.config = config
        self.hdl = config.get("HDL", "verilog")

    @property
    def source_dir(self) -> Path:
        return self.core_dir

    def _get_sources_for_hashing(self) -> List[Path]:
        """
        Collect HDL source files for hash
        """

        src_dir = self.core_dir / "src"

        src_suffix = "*.v"
        hdr_suffix = "*.vh"
        xdc_suffix = "*.xdc"
        if self.hdl == "systemverilog":
            src_suffix = "*.sv"
            hdr_suffix = "*.svi"
        elif self.hdl == "vhdl":
            src_suffix = "*.vhd"
            hdr_suffix = ""

        patterns = [p for p in [src_suffix, hdr_suffix, xdc_suffix] if p]
        files = []
        for p in patterns:
            for path in src_dir.rglob(p):
                # testbench sources excluded as they are not instantiating the IP Core
                if "sim" not in path.parts:
                    files.append(path)

        return files

    def _run_build_tool(self, h: "hardware", log_file: Path, jou_file: Path) -> None:
        """
        Run TCL IP Core build script
        """

        tcl_script = BUILD_SCRIPTS / "package_riscv_ip.tcl"
        tcl_args = [
            self.name,
            self.config["IP_VENDOR"],
            self.config["IP_LIBRARY"],
            self.version,
            h.target,
            self.core_dir.name,
        ]

        cmd = [
            "vivado",
            "-mode",
            "batch",
            "-source",
            str(tcl_script),
            "-log",
            str(log_file),
            "-journal",
            str(jou_file),
            "-tclargs",
        ] + tcl_args

        logging.info("Running IP Packager...")
        subprocess.run(cmd, check=True)

    def _check_build_artifacts_exist(self) -> bool:
        """
        Check if the IP directory actually exists
        """

        expected_path = (
            IP_REPO_DIR
            / f"{self.config['IP_VENDOR']}_{self.config['IP_LIBRARY']}_{self.name}_{self.version}"
        )
        return expected_path.exists()


class fpga_design(generic_design):
    """
    Class implementing Vivado block diagram project for a complete PL layer
    """

    def __init__(self, config: dict, dependencies: List[ip_core]) -> None:
        self.proj_dir = BUILD_SCRIPTS
        super().__init__(name=config["PROJECT_NAME"], version="1.0")
        self.xsa = config["XSA"]
        self.dependencies = dependencies

    @property
    def source_dir(self) -> Path:
        return self.proj_dir

    def _get_sources_for_hashing(self) -> List[Path]:
        """
        Hash TCL script which recreates the block diagram project
        """

        files = []
        files.extend(self.proj_dir.glob("*.tcl"))
        return files

    def _add_extra_hash_content(self, hasher):
        """
        Mix the current hashes of all IP Cores that this design depend on.
        If an IP changes then an entire block diagram has to be rebuilt
        """
        for ip in self.dependencies:
            ip_hash = ip._compute_hash()
            hasher.update(ip_hash.encode("utf-8"))

    def _run_build_tool(self, h: "hardware", log_file: Path, jou_file: Path) -> None:
        """
        Run TCL block diagram project build script
        """

        tcl_script = BUILD_SCRIPTS / "build_riscv_worker_pl.tcl"

        # for now dependencies list will contain only one entrance (one core) but this is added like that in case we have to extend it
        ip_vlnv = f"{self.dependencies[0].config['IP_VENDOR']}:{self.dependencies[0].config['IP_LIBRARY']}:{self.dependencies[0].name}:{self.dependencies[0].config['IP_VERSION']}"
        tcl_args = [
            self.name,
            h.target,
            h.board,
            self.xsa,
            ip_vlnv,
            self.dependencies[0].name,
        ]

        cmd = [
            "vivado",
            "-mode",
            "batch",
            "-source",
            str(tcl_script),
            "-log",
            str(log_file),
            "-journal",
            str(jou_file),
            "-tclargs",
        ] + tcl_args

        logging.info("Running IP Packager...")
        subprocess.run(cmd, check=True)

    def _check_build_artifacts_exist(self) -> bool:
        """
        Check for the build directory
        """

        expected_path = BUILD_DIR / f"build_riscv_worker_pl_{self.dependencies[0].name}"

        return expected_path.exists()


class soc_design(generic_design):
    """
    Class implementing Vitis project
    """

    def __init__(self, config: dict, pl_layer: fpga_design) -> None:
        self.proj_dir = Path.cwd()
        self.config = config
        self.c_src = C_SRC
        self.header_files = INC_FILES
        self.pl_layer = pl_layer
        super().__init__(name=config["PLATFORM"], version="1.0")

    @property
    def source_dir(self) -> Path:
        return self.proj_dir

    def _get_sources_for_hashing(self) -> List[Path]:
        """
        Get *.c and *.h files for hashing SOC related components
        """

        files = []
        files.extend(self.c_src.glob("*.c"))
        files.extend(self.header_files.glob("*.h"))
        return files

    def _add_extra_hash_content(self, hasher):
        """
        Mix *.c and *.h hash with the hash of block diagram,
        if that has been changed then *.xsa has changed and everything needs
        to be rebuilt
        """

        pl_hash = self.pl_layer._compute_hash()
        hasher.update(pl_hash.encode("utf-8"))

    def _run_build_tool(self, h: "hardware", log_file, jou_file) -> None:
        """
        Run Python script with Vitis runtime
        """

        python_vitis_script = BUILD_SCRIPTS / "build_riscv_worker_ps_pl.py"

        workspace = BUILD_DIR / self.config["WORKSPACE"]
        xsa_path = (
            BUILD_DIR
            / f"build_riscv_worker_pl_{self.pl_layer.dependencies[0].name}/{self.pl_layer.xsa}"
        )
        code_dir = self.proj_dir / "platforms/xilinx/"
        cmd = [
            "vitis",
            "-s",
            python_vitis_script,
            "--workspace",
            str(workspace),
            "--platform",
            self.config["PLATFORM"],
            "--hw_design",
            str(xsa_path),
            "--cpu",
            h.cpu,
            "--application",
            self.config["APPLICATION"],
            "--code",
            str(code_dir),
            "--verbose",
            "1",
        ]

        logging.info(f"Running Vitis Project creator...")

        # Vitis needs handling like that in order to save logs to logs/
        with open(log_file, "w") as f:
            subprocess.run(cmd, check=True, stdout=f, stderr=subprocess.STDOUT)

    def _check_build_artifacts_exist(self) -> bool:
        """
        Check for the build directory
        """

        expected_path = BUILD_DIR / "RISC_V_worker_PS_layer_platform"

        return expected_path.exists()
