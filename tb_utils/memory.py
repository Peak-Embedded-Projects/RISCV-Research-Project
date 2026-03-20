import os
import json
from pathlib import Path

target_core = os.environ.get("TARGET_CORE")

if not target_core:
    config_path = Path(__file__).resolve().parent.parent / ".sim_run_config.json"
    if config_path.exists():
        with open(config_path, "r") as f:
            target_core = json.load(f).get("CORE", "rv32i")
    else:
        target_core = "rv32i"

if target_core == "rv32i":
    from .rv32i.memory import *
# elif target_core == "rv64i":
#     from .rv64i.memory import *
else:
    raise ImportError(f"No memory utilities defined for target core: {target_core}")
