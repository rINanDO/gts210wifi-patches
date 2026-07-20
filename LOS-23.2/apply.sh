#!/bin/bash

# Array of directories and corresponding patches
declare -A patches=(
    # TODO ["art"]="android_art"
    # TODO ["bionic"]="android_bionic"
    # OK ["build/make"]="android_build"
    # OK ["build/soong"]="android_build_soong"
    # TODO ["device/lineage/sepolicy"]="android_device_lineage_sepolicy"
    # OK ["external/perfetto"]="android_external_perfetto"
    # TODO ["frameworks/base"]="android_frameworks_base"
    # TODO ["frameworks/av"]="android_frameworks_av"
    # OK ["frameworks/native"]="android_frameworks_native"
    # OK ["frameworks/hardware/interfaces"]="android_frameworks_hardware_interfaces"
    # OK ["hardware/libhardware_legacy"]="android_hardware_libhardware_legacy" 
    # OK ["hardware/lineage/interfaces"]="android_hardware_lineage_interfaces"
    # OK ["hardware/samsung"]="android_hardware_samsung"
    # CRASH ["hardware/samsung_slsi/exynos"]="android_hardware_samsung_slsi_exynos"
    # CRASH ["hardware/samsung_slsi/exynos5"]="android_hardware_samsung_slsi_exynos5"
    # CRASH ["hardware/samsung_slsi/exynos5433"]="android_hardware_samsung_slsi_exynos5433"
    # CRASH ["hardware/samsung_slsi/openmax"]="android_hardware_samsung_slsi_openmax"
    # TODO ["packages/modules/Connectivity"]="android_packages_modules_Connectivity"
    # OK ["packages/modules/DnsResolver"]="android_packages_modules_DnsResolver"
    # TODO ["packages/modules/NetworkStack"]="android_packages_modules_NetworkStack"
    # TODO["prebuilts/build-tools"]="android_prebuilts_build-tools"
    # TODO ["system/bpf"]="android_system_bpf"
    # TODO ["system/core"]="android_system_core"
    # OK ["system/linkerconfig"]="android_system_linkerconfig"
    # OK ["system/netd"]="android_system_netd" # TODO: Drop latest patch "connect_directly"
    # OK ["system/tools/mkbootimg"]="android_system_tools_mkbootimg"
    # OK ["system/tools/hidl"]="android_system_tools_hidl"
)

# Base path for the patches
patches_base_path=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

for dir in "${!patches[@]}"; do
    cd $dir || { echo "Directory $dir not found"; exit 1; }

    patch_dir=${patches[$dir]}
    patch_files=($patches_base_path/$patch_dir/*.patch)

    for patch_file in "${patch_files[@]}"; do
        git am --3way < "$patch_file"
    done

    cd - > /dev/null
done
