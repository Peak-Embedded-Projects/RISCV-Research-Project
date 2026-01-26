# =============================================================================================================
# This script creates custom RISC-V IP Core. It utilizes any implementation provided in the File Paths section.
# The script imports files from that location by coopying them, therefore in case of an update of the core
# it is necessary to re-execute this script to refresh the IP repository.
# Run the script with: vivado -mode batch -source ./package_riscv_ip.tcl (doesn't work anymore: got adjusted 
# to work only with Makefile)
# Then in order to get latest block diagram project of an entire system run either:
# vivado -mode batch -source build_riscv_worker_pl.tcl (non-GUI mode) (doesn't work standalone: check the script)
# or
# vivado -mode gui -source RISC_V_worker_PL_layerl.tcl (GUI mode)
# =============================================================================================================

# ==================Project Settings ==================
set ip_name        [lindex $argv 0]
set ip_vendor      [lindex $argv 1]
set ip_library     [lindex $argv 2]
set ip_version     [lindex $argv 3]
set ip_display_name "RISC-V 32i core with control module"
set target_part    [lindex $argv 4]
set core_name      [lindex $argv 5]
# ================== File Paths ==================
set sources_dir    "../cores/$core_name/src/hdl"
set headers_dir    "../cores/$core_name/src/include"
set output_repo    "ip_repos"

# List of files to exclude (full paths or basenames)
set exclude_list [list "axi_memory_mock.v" "bram32.v"]

# Top Module Name
set top_module     "cm_and_core"

# Script begins execution here
puts "--- Starting IP Packaging Process for $ip_name IP Core ---"

# 1. Create a temporary staging project in memory- this prevents Vivado from creating a .xpr
create_project -in_memory -part $target_part -force managed_ip_project

# 2. Add Verilog Source Files
puts "--- Adding Source Files from $sources_dir ---"
set v_files [glob -nocomplain "$sources_dir/*.v"]
if {$v_files eq ""} {
    puts "Error: No .v files found in $sources_dir"
    exit 1
}

set filtered_v_files {}
foreach f $v_files {
    if {[lsearch -exact $exclude_list [file tail $f]] == -1} {
        lappend filtered_v_files $f
    }
}

add_files $filtered_v_files

# 3. Add Verilog Header Files
puts "--- Adding Header Files from $headers_dir ---"
set h_files [glob -nocomplain "$headers_dir/*.vh"] 
if {$h_files ne ""} {
    add_files $h_files
    # explicitely set file type to 'Verilog Header' so Vivado doesn't look for modules inside
    set_property file_type "Verilog Header" [get_files $h_files]
    # Add the include directory to the fileset include path
    set_property include_dirs $headers_dir [current_fileset]
} else {
    puts "Info: No header files found. Proceeding without headers."
}

# 4. Set the Top Module
set_property top $top_module [current_fileset]
update_compile_order -fileset sources_1

# 5. Initialize IP Packaging
# Define the root directory where the final IP will live
set ip_output_dir "${output_repo}/${ip_vendor}_${ip_library}_${ip_name}_${ip_version}"

puts "--- Packaging IP to $ip_output_dir ---"
ipx::package_project -root_dir $ip_output_dir -vendor $ip_vendor -library $ip_library -taxonomy /UserIP -import_files -set_current false

# 6. Configure IP Metadata
set core [ipx::find_open_core $ip_vendor:$ip_library:$top_module:$ip_version]
set_property name $ip_name $core
set_property version $ip_version $core
set_property display_name $ip_display_name $core
set_property description "Automatically packaged IP core" $core

# 7. Ensure File Groups are correct- this merges the files into the IP core structure
ipx::create_xgui_files $core
ipx::update_checksums $core

# 8. Save and Finish
ipx::save_core $core
ipx::unload_core $core

puts "--- IP Packaging Complete! ---"
puts "Location: $ip_output_dir"

close_project
