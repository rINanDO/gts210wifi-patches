#!/bin/bash

# Array of directories and corresponding patches
declare -A patches=(
    ["art"]="android_art"
    ["bionic"]="android_bionic"
    ["build/make"]="android_build"
    ["build/soong"]="android_build_soong"
    ["device/lineage/sepolicy"]="android_device_lineage_sepolicy"
    ["external/perfetto"]="android_external_perfetto"
    ["frameworks/base"]="android_frameworks_base"
    ["frameworks/native"]="android_frameworks_native"
    ["hardware/lineage/interfaces"]="android_hardware_lineage_interfaces"
    ["hardware/samsung"]="android_hardware_samsung"
    ["hardware/samsung_slsi/exynos"]="android_hardware_samsung_slsi_exynos"
    ["hardware/samsung_slsi/exynos5433"]="android_hardware_samsung_slsi_exynos5433"
    ["packages/modules/adb"]="android_packages_modules_adb"
    ["packages/modules/Connectivity"]="android_packages_modules_Connectivity"
    ["packages/modules/DnsResolver"]="android_packages_modules_DnsResolver"
    ["packages/modules/NetworkStack"]="android_packages_modules_NetworkStack"
    ["prebuilts/build-tools"]="android_prebuilts_build-tools"
    ["system/bpf"]="android_system_bpf"
    ["system/core"]="android_system_core"
    ["system/netd"]="android_system_netd"
    ["vendor/lineage"]="android_vendor_lineage"
)

# Base path for the patches
patches_base_path=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

for dir in "${!patches[@]}"; do
    cd $dir || { echo "Directory $dir not found"; exit 1; }

    patch_dir=${patches[$dir]}
    patch_files=($patches_base_path/$patch_dir/*.patch)

    num_patches=${#patch_files[@]}

    if [ $num_patches -gt 0 ]; then
        git am --abort
	repo sync .
    fi

    cd - > /dev/null
done
