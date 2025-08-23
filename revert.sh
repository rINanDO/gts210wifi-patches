#!/bin/bash

# Array of directories and corresponding patches
declare -A patches=(
    ["art"]="android_art"
    ["bionic"]="android_bionic"
    ["build/make"]="android_build"
    ["build/soong"]="android_build_soong"
    ["device/google/cuttlefish"]="android_device_google_cuttlefish"
    ["device/lineage/sepolicy"]="android_device_lineage_sepolicy"
    ["external/wpa_supplicant_8"]="android_external_wpa_supplicant_8"
    ["external/perfetto"]="android_external_perfetto"
    ["frameworks/av"]="android_frameworks_av"
    ["frameworks/base"]="android_frameworks_base"
    ["frameworks/ex"]="android_frameworks_ex"
    ["frameworks/native"]="android_frameworks_native"
    ["frameworks/opt/net/wifi"]="android_frameworks_opt_net_wifi"
    ["hardware/libhardware_legacy"]="android_hardware_libhardware_legacy"
    ["hardware/interfaces"]="android_hardware_interfaces"
    ["hardware/lineage/interfaces"]="android_hardware_lineage_interfaces"
    ["hardware/samsung"]="android_hardware_samsung"
    ["hardware/samsung_slsi/exynos"]="android_hardware_samsung_slsi_exynos"
    ["packages/modules/adb"]="android_packages_modules_adb"
    ["packages/modules/Bluetooth"]="android_packages_modules_Bluetooth"
    ["packages/modules/Connectivity"]="android_packages_modules_Connectivity"
    ["packages/modules/NetworkStack"]="android_packages_modules_NetworkStack"
    ["prebuilts/build-tools"]="android_prebuilts_build-tools"
    ["prebuilts/sdk"]="android_prebuilts_sdk"
    ["prebuilts/abi-dumps/ndk"]="android_prebuilts_abi-dumps_ndk"
    ["system/bpf"]="android_system_bpf"
    ["system/core"]="android_system_core"
    ["system/libhidl"]="android_system_libhidl"
    ["system/netd"]="android_system_netd"
    ["system/sepolicy"]="android_system_sepolicy"
    ["vendor/lineage"]="android_vendor_lineage"
)

# Base path for the patches
patches_base_path=~/patches

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
