"""
The following script allows for automatic Vitis project generation.
It will copy files from the provided with --code directory and include
them into application component which will be compiled.
Example command (use only from Makefile!!!):
vitis -s build_riscv_worker_ps_pl.py --workspace "../vitis_ws" --hw_design "../riscv_worker_hardware.xsa" --code "../zynq" --verbose 1

Current issues:
Vitis COPIES source files, therefore so far it works ok, when the source code is complete and we want to generate the project
and program the device. Unfortunately, as Vitis project directory is not included in the source control any source file modified there
will not be updated for the repository. I have tried to delete the application component but then somehow when I recreate it
add again files it fails to compile probelms with retargetting application to the platform- I don't know how to resolve that in an elegant way.
For now deleting entire project and rebuilding it from scratch with this script is the only way, which sucks...
I might try with symlinks later...
"""

import argparse
import os
import shutil

import vitis


def build_parser() -> argparse.ArgumentParser:
    """Parser factory function.

    Returns:
        argparse.ArgumentParser: parser with Vitis parameters
    """
    parser = argparse.ArgumentParser(
        description="Parser used to build Vitis project necessary to create the full PS-PL worker."
    )

    parser.add_argument(
        "--workspace",
        type=str,
        required=True,
        help="Directory where Vitis project should be created.",
    )

    parser.add_argument(
        "--platform",
        type=str,
        default="RISC_V_worker_PS_layer_platform",
        help="Name of the platform component (defaults to RISC_V_worker_PS_layer_platform).",
    )

    parser.add_argument(
        "--hw_design",
        type=str,
        required=True,
        help="Location of XSA file.",
    )

    parser.add_argument(
        "--cpu",
        type=str,
        default="ps7_cortexa9_0",
        help="CPU (defaults to ps7_cortexa9_0).",
    )

    parser.add_argument(
        "--application",
        type=str,
        default="RISC_V_worker_PS_application",
        help="Name of the application component (defaults to RISC_V_worker_PS_application).",
    )

    parser.add_argument(
        "--code",
        type=str,
        required=True,
        help="Location of source and include files (this directory should contain src/ and include/ directories).",
    )

    parser.add_argument(
        "--verbose",
        type=int,
        default=0,
        help="Verbose overview (defaults to 0).",
    )

    return parser

def main() -> None:
    """Create Vitis project based on the parser input.
    """
    parser = build_parser()
    vitis_args = parser.parse_args()

    abs_workspace = os.path.abspath(vitis_args.workspace)
    abs_hw        = os.path.abspath(vitis_args.hw_design)
    abs_code      = os.path.abspath(vitis_args.code)

    domain_name = "standalone_".join(vitis_args.cpu)

    if (vitis_args.verbose == 1):
        print("===================================")
        print("= Workspace  : {}".format(abs_workspace))
        print("= Platform   : {}".format(vitis_args.platform))
        print("= Hw design  : {}".format(abs_hw))
        print("= CPU        : {}".format(vitis_args.cpu))
        print("= Application: {}".format(vitis_args.application))
        print("= Code dir   : {}".format(abs_code))
        print("===================================")

    # Vitis Python API creates the project
    client = vitis.create_client()
    client.set_workspace(path=abs_workspace) # make sure to always exit any Vitis GUI session open in the worspace you want to use here,
                                             # otherwise it will crash

    if not os.path.exists(os.path.join(abs_workspace, vitis_args.platform)):
        print("===================================")
        print("= Creating platform: {}".format(vitis_args.platform))
        advanced_options = client.create_advanced_options_dict(dt_overlay="0")

        platform = client.create_platform_component(name=vitis_args.platform,
                                                    hw_design=abs_hw,
                                                    os="standalone",
                                                    cpu=vitis_args.cpu,
                                                    domain_name=domain_name,
                                                    generate_dtb=False,
                                                    advanced_options=advanced_options,
                                                    compiler="gcc"
        )

        print("= Building platform")
        platform.build()
        print("===================================")
    else:
        print("===================================")
        print("= Platform: {} already exists".format(vitis_args.platform))
        print("===================================")
        platform = client.get_component(name=vitis_args.platform)
        platform.update_hw(hw_design=abs_hw)
        platform.build()
        print("= Building platform")
        print("===================================")

    status = platform.update_desc(desc="PS layer of the worker")

    xpfm_path = os.path.join(abs_workspace, vitis_args.platform, "export", vitis_args.platform, "{}.xpfm".format(vitis_args.platform))
    if not os.path.exists(os.path.join(abs_workspace, vitis_args.application)):
        print("===================================")
        print("= Creating application: {}".format(vitis_args.application))
        print("===================================")
        comp = client.create_app_component(name=vitis_args.application,
                                        platform=xpfm_path,
                                        domain=domain_name,
                                        template="empty_application"
        )
    else:
        print("===================================")
        print("= Application: {} already exists".format(vitis_args.application))
        print("===================================")
        comp = client.get_component(name=vitis_args.application)
        # comp.update_app_component(platform=xpfm_path, domain=domain_name)

    print("===================================")
    print("= Importing sources and headers")
    print("===================================")
    # standard Vitis project structure is [Workspace]/[AppName]/sources/src
    app_src_dir = os.path.join(abs_workspace, vitis_args.application, "src")

    user_src_dir = os.path.join(abs_code, "src")
    user_inc_dir = os.path.join(abs_code, "include")

    def copy_files(src_dir, dst_dir, ext_filter=None):
        if not os.path.exists(src_dir):
            raise FileNotFoundError("Directory {} does not exist.".format(src_dir))
        
        if not os.path.exists(dst_dir):
            os.makedirs(dst_dir, exist_ok=True)

        for item in os.listdir(src_dir):
            s = os.path.join(src_dir, item)
            d = os.path.join(dst_dir, item)
            if os.path.isfile(s):
                if ext_filter and not item.endswith(ext_filter):
                    continue
                shutil.copy2(s, d)
                print("Imported: {}".format(item))
    
    copy_files(user_src_dir, app_src_dir)
    copy_files(user_inc_dir, app_src_dir)

    print("===================================")
    print("= Building application")
    print("===================================")
    comp.build()

    print("===================================")
    print("= Build complete!")
    print("ELF: {}".format(os.path.join(abs_workspace, vitis_args.application, 'build', domain_name, 'app.elf')))
    print("===================================")

    vitis.dispose()


if __name__ == "__main__":
    main()
