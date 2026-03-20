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

# route the import
if target_core == "rv32i":
    from .rv32i.constants import *
# elif target_core == "rv64i":
#     from .rv64i.constants import *
else:
    raise ImportError(f"No constants defined for target core: {target_core}")
