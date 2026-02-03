import json
import hashlib
import subprocess
import logging
from datetime import datetime
from abc import ABC, abstractmethod
from typing import List
from dataclasses import dataclass, field
from pathlib import Path


BUILD_CACHE_DIR = Path(".build_cache")
IP_REPO_DIR = Path("ip_repos")
BUILD_SCRIPTS = Path("scripts")
CORES_ROOT = Path("cores")
LOGS_DIR = Path("logs")


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

        current_hash = self._compute_hash()
        stored_hash = ""

        if self.digest_file.exists():
            with open(self.digest_file, "r") as f:
                stored_hash = f.read().strip()

        if current_hash == stored_hash and self._check_build_artifacts_exist():
            logging.info(f"{self.name}: Up to date. Skipping build.")
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


class ip_core(generic_design):
    """
    Class implementing RISC-V IP Core used to create the IP for the worker
    """

    def __init__(self, dir_name: str, config: dict) -> None:
        self.core_dir = CORES_ROOT / dir_name
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
            files.extend(src_dir.rglob(p))

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

        logging.info(f"Running IP Packager...")
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


@dataclass
class fpga_design:
    """
    Class implementing Vivado block diagram project for a complete PL layer
    """

    proj_name: str
    xsa: str
    hw: hardware
    riscv_vlnv: str

    digest_file: Path = field(init=False)


if __name__ == "__main__":
    with open("config.json", "r") as f:
        config = json.load(f)

    hw_config = config["HARDWARE"]
    hw = hardware(target=hw_config["TARGET"], board=hw_config["BOARD"])

    core_config = config["CORE"]
    riscv_ip = ip_core(dir_name="rv32i", config=config["CORE"])
    riscv_ip.build(hw)

    # vivado_config = config["PROJECT"]["VIVADO"]
    # pl_layer = fpga_design()
