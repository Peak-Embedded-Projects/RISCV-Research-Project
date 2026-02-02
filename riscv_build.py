import json
import hashlib
import subprocess
from dataclasses import dataclass, field
from pathlib import Path


BUILD_CACHE_DIR = Path(".build_cache")
IP_REPO_DIR = Path("ip_repos")
BUILD_SCRIPTS = Path("scripts")
CORES_ROOT = Path("cores")


@dataclass(frozen=True)
class hardware:
    """
    Class containing target platform details
    """

    target: str
    board: str


@dataclass()
class ip_core:
    """
    Class implementing RISC-V IP Core used to create the IP for the worker
    """

    dir: Path
    ip_name: str
    ip_vendor: str
    ip_library: str
    ip_version: str
    hdl: str

    digest_file: Path = field(init=False)

    def __init__(
        self,
        dir: str,
        ip_name: str,
        ip_vendor: str,
        ip_library: str,
        ip_version: str,
        hdl: str,
    ) -> None:
        ip_core_dir = CORES_ROOT / dir
        if not ip_core_dir.exists():
            raise FileNotFoundError(
                "[ERROR] IP core direcotry at: {} doesn't exist".format(
                    ip_core_dir.__str__()
                )
            )

        self.dir = ip_core_dir
        self.ip_name = ip_name
        self.ip_vendor = ip_vendor
        self.ip_library = ip_library
        self.ip_version = ip_version
        self.hdl = hdl
        self.digest_file = BUILD_CACHE_DIR / f"{self.ip_name}.digest"

    def _compute_hash(self) -> str:
        """
        Compute MD5 hash for all HDL source files in the IP Core direcotry
        """

        src_suffix = "*.v"
        hdr_suffix = "*.vh"
        xdc_suffix = "*.xdc"
        if self.hdl == "systemverilog":
            src_suffix = "*.sv"
            hdr_suffix = "*.svi"
        elif self.hdl == "vhdl":
            src_suffix = "*.vhd"
            hdr_suffix = ""

        hasher = hashlib.md5()
        files = []
        patterns = [p for p in [src_suffix, hdr_suffix, xdc_suffix] if p]
        src_directory = self.dir.joinpath("src")

        for suffix in patterns:
            for file in src_directory.rglob(suffix):
                files.append(file)

        for filepath in sorted(files):
            if filepath.is_file():
                hasher.update(str(filepath.relative_to(self.dir)).encode("utf-8"))
                with open(filepath, "rb") as f:
                    while chunk := f.read(4096):
                        hasher.update(chunk)

        hasher.update(self.ip_version.encode("utf-8"))

        return hasher.hexdigest()

    def build(self, h: hardware) -> None:
        """
        Build RISC-V IP only when the core is outdated or missing
        """
        print("================================")
        print("[INFO] {} checking status...".format(self.ip_name))
        print("================================")

        BUILD_CACHE_DIR.mkdir(exist_ok=True)

        current_hash = self._compute_hash()
        stored_hash = ""

        # check for stored hash
        if self.digest_file.exists():
            with open(self.digest_file, "r") as f:
                stored_hash = f.read().strip()

        if current_hash == stored_hash and IP_REPO_DIR.exists():
            print("================================")
            print(
                "[INFO] {} is up to date (v.{}). Skipping build...".format(
                    self.ip_name, self.ip_version
                )
            )
            print("================================")
            return

        print("================================")
        print("[INFO] {} is outdated or missing. Building...".format(self.ip_name))
        print("================================")

        self._package_riscv_ip(h)

        with open(self.digest_file, "w") as f:
            f.write(current_hash)

        print("================================")
        print("[INFO] {} build complete".format(self.ip_name))
        print("================================")

    def _package_riscv_ip(self, h: hardware) -> None:
        """
        Execute Vivadp TCL script for building the IP Core
        """

        tcl_script = BUILD_SCRIPTS / "package_riscv_ip.tcl"

        tcl_args = [
            self.ip_name,
            self.ip_vendor,
            self.ip_library,
            self.ip_version,
            h.target,
            self.dir.name,
        ]  # TODO: in the future add hdl argument as it is intended to support sv and vhd

        cmd = [
            "vivado",
            "-mode",
            "batch",
            "-source",
            str(tcl_script),
            "-tclargs",
        ] + tcl_args

        print("================================")
        print("[INFO] Running Vivado: {}".format(" ".join(cmd)))
        print("================================")

        try:
            subprocess.run(cmd, check=True)
        except subprocess.CalledProcessError as e:
            print("[ERROR] Vivado IP Core build failed for: {}".format(self.ip_name))
            self.digest_file.unlink(missing_ok=True)
            raise e


if __name__ == "__main__":
    with open("config.json", "r") as f:
        config = json.load(f)

    hw_config = config["HARDWARE"]
    hw = hardware(target=hw_config["TARGET"], board=hw_config["BOARD"])

    core_config = config["CORE"]
    riscv_ip = ip_core(
        dir=core_config["DIR"],
        ip_name=core_config["IP_NAME"],
        ip_vendor=core_config["IP_VENDOR"],
        ip_library=core_config["IP_LIBRARY"],
        ip_version=core_config["IP_VERSION"],
        hdl=core_config["HDL"],
    )

    riscv_ip.build(hw)
