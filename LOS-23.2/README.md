# LineageOS 23.2/Android 16 patches for Galaxy Tab S2 9.7 Wi-Fi (gts210wifi)

These instructions assume that:

- the LineageOS 23.2 sources live (or will live) in `~/android/system`
  (see <https://github.com/LineageOS/android/tree/lineage-23.2>)
- this repository is cloned in `~/android/system/patches/gts210wifi-patches`
- `git`, `git-lfs`, `repo` and `xmllint` are installed, plus the usual
  LineageOS build dependencies

All scripts accept the source root as their last argument and default to the
current directory. Run them directly (`./setup.sh`); sourcing them
(`. setup.sh`) also works.

## Quick start: set up everything

```bash
cd ~/android/system
patches/gts210wifi-patches/LOS-23.2/setup.sh
```

`setup.sh` does the whole job and can be re-run at any time:

1. `repo init -b lineage-23.2 --git-lfs` if the directory isn't a checkout yet
2. `cleanup.sh`: removes local manifests of other devices and drops any
   previously applied patches (gts210wifi's or another device's)
3. installs `exynos5433-23.2.xml` into `.repo/local_manifests/`
4. `repo sync -d --force-sync`
5. `apply.sh`

Options: `-y` (don't ask for confirmation), `--force` (see
[Cleaning up](#cleaning-up)), `-j N` (parallel sync jobs).

## Build the ROM

```bash
cd ~/android/system
. build/envsetup.sh
brunch gts210wifi
```

Your build will be put (after many hours) in:

`~/android/system/out/target/product/gts210wifi`

## Cleaning up

To return the tree to plain LineageOS 23.2, without any local manifest or
patches:

```bash
cd ~/android/system
patches/gts210wifi-patches/LOS-23.2/cleanup.sh
```

This works on the whole tree, whichever device it was set up for. It lists
what it is going to do and asks before doing it:

- local manifests are moved to `.repo/local_manifests.backup/<date>/`
- unfinished `git am`/rebase/cherry-pick operations are aborted
- local commits (applied patches) are dropped and every project is synced to
  its manifest revision; add `--fetch` to also fetch updates from the network

It refuses to continue when a project has uncommitted changes, or when a
device repo has commits that aren't pushed to any remote. Commit/push or stash
that work first, or pass `--force` to throw it away.

## Applying or reverting only the patches

When the local manifest is already installed and synced:

```bash
cd ~/android/system
patches/gts210wifi-patches/LOS-23.2/apply.sh
patches/gts210wifi-patches/LOS-23.2/revert.sh
```

A repo whose patches don't apply is left in the middle of `git am` so it can
be resolved by hand; the output points at a log with the details. `revert.sh`
aborts that and resets the patched repos with `repo sync`.

## Maintaining the patch set

- The patched repositories are listed once, in `common.sh` (`PATCHED_REPOS`).
  To track a new repo, add a line there and put its `git format-patch` output
  in the matching `android_*` directory.
- Device, kernel, hardware and vendor repos, including `hardware/samsung`,
  are forks listed in `exynos5433-23.2.xml`.
  `create-lineage-23.2-branches.sh` creates and pushes the `lineage-23.2`
  branch in each of them.

## What the patches address

The Tab S2 (exynos5433) is a legacy device: a Linux 3.10 kernel, no Treble,
no separate vendor partition, and closed-source blobs built for Android 6-7.
LineageOS 23.2 builds against current AOSP, which has removed much of the
compatibility code these blobs and this kernel depend on. The patches put
it back, grouped here by problem rather than by repository.

- **No BPF in the kernel** (`system_bpf`, `system_netd`,
  `packages_modules_Connectivity`, `packages_modules_DnsResolver`,
  `frameworks_native`): Android now requires eBPF for network statistics,
  per-app firewalling and DNS. The BPF loaders, netd, DnsResolver and the
  Connectivity module no longer abort when BPF is missing, and
  `gpuservice` is disabled, because its GPU memory accounting needs BPF.
- **Kernel without netlink TCP info** (`packages_modules_NetworkStack`):
  reverts the NetworkStack changes that require querying TCP info over a
  netlink socket and parsing kernel netlink events.
- **cgroup v1-only kernel** (`system_core`, `frameworks_base`,
  `system_netd`): the kernel has no cgroup v2. These revert the v2-only
  freezer and memcg defaults, let cgroup setup continue when a controller
  fails to mount, and make process-group creation failures non-fatal in the
  framework and netd.
- **Old kernel syscalls** (`bionic`, `art`, `external_perfetto`,
  `frameworks_native`, `frameworks_base`): `memfd_create` version checks,
  `MADV_WIPEONFORK` in `arc4random`, `renameat2` (`renameat()` is reverted
  to the old implementation) and `epoll_pwait2` (a fallback in
  `BLASTBufferQueue`). `Bitmap` keeps using ashmem instead of memfd.
  `libbinder` no longer aborts when it shrinks its thread pool.
- **Old prebuilt blobs** (`bionic`): linker shim libraries
  (`LD_SHIM_LIBS`), ignoring library namespaces so vendor blobs can load
  system libraries, a per-process target SDK override, the pre-Android 9
  mutex behaviour these blobs expect, and the `inaddr.h` header.
- **No Treble, no vendor partition** (`system_linkerconfig`, `build_make`):
  restores the non-Treble linker configuration and disables Treble in the
  build.
- **Samsung boot image and kernel build** (`build_make`, `build_soong`,
  `system_tools_mkbootimg`, `prebuilts_build-tools`):
  - `dt.img` support in boot images (`mkbootimg --dt`);
  - device-specific header overrides, and automatic use of the kernel
    header library;
  - xz 5.2.5 for the kernel build;
  - uncompressed APEXes.
- **Camera HAL v1** (`frameworks_av`, `frameworks_base`, `system_core`,
  `device_lineage_sepolicy`): the camera blob only speaks the HAL v1 API,
  which AOSP removed. This restores HALv1 support in cameraserver and
  mediaserver, the old recording path, the camera extensions and formats
  the blob uses, and the HALv1 sepolicy.
- **Legacy HIDL HALs** (`hardware_lineage_interfaces`,
  `hardware_libhardware_legacy`, `device_lineage_sepolicy`,
  `frameworks_base`, `frameworks_native`, `frameworks_hardware_interfaces`,
  `system_tools_hidl`):
  - restores the legacy Wi-Fi HIDL HAL (with dynamic interfaces) and the
    Wi-Fi headers it builds against, without TWT and 802.11az;
  - restores the sepolicy labels for the legacy GNSS and Wi-Fi HALs, and
    `android.frameworks.schedulerservice`;
  - `HintManagerService` no longer crashes when there is no AIDL power HAL.
- **Sensors for gpsd** (`hardware_lineage_compat`):
  - fixes a `libsensor` null-pointer crash in
    `SensorManager::getSensorList`;
  - `libsensor` gives each sensor event queue a real file descriptor.
    `gpsd` waits for sensor events on `SensorEventQueue::getFd()`, but
    the current sensor bridge only delivers them through a callback, so
    `gpsd` never got any and GPS ran without motion sensors. With the
    shim and SELinux fixes in `device/samsung/gts2-common`, `gpsd` now
    uses the accelerometer, magnetometer and gyroscope;
  - `libsensor` picks the default sensor from the sensor list instead of
    asking the sensor service. For a sensor the tablet lacks, the service
    replies with an error message, and in `gpsd`, which also loads the old
    `libutils-v32`, reading that message crashed it every minute.
- **Stability and build fixes** (`frameworks_base`, `frameworks_av`,
  `frameworks_native`, `system_core`, `system_memory_lmkd`, `build_make`,
  `hardware_lineage_interfaces`):
  - `FileIntegrity` skips fs-verity, which this kernel lacks, instead of
    logging a stack trace on every settings and permissions write;
  - lmkd no longer exits at every boot: it uses the kernel's low memory
    killer, but tried to start PSI monitoring when ActivityManager asked,
    and this kernel has no PSI;
  - media codec fixes (no crash when a codec fails to load, no leaks when a
    buffer lock times out or an observer dies, high frame rate recording);
  - `link_type_error` downgraded to a warning;
  - the health HAL's fast charge dump uses the right format for a 64-bit
    value on 32-bit ARM, which failed the build;
  - fast reboot on legacy devices too;
  - reverts of the SurfaceFlinger fuzzer removal and of SurfaceFlinger's
    string-free permission check.

## Fixes in the device and kernel repos

Some problems are fixed in the forked repos from `exynos5433-23.2.xml`
instead of with patches. They come with `repo sync` and need no
`apply.sh`. Most were found on LineageOS 24.0 and ported back.

- **Samsung hardware** (`hardware/samsung`): the fork carries the audio/RIL
  fix, macloader and wifiloader, and the `libdtbimg` header fix. The
  fingerprint HAL also looks for templates in `/data/biometrics`. The old
  `libbauthserver.so` can't list its own enrollments and stores them there,
  so the HAL found none and every fingerprint was removed at boot.
- **Fingerprint and lock screen** (`device/samsung/gts2-common`,
  `hardware/samsung_slsi/exynos5433`): the software gatekeeper issued
  authentication tokens the fingerprint trustlet can't verify, and the
  stub `libbauthtzcommon` never passed them on, so enrollment failed.
  gts2-common now uses the real `libbauthtzcommon.so` and the TEE-backed
  gatekeeper HAL from `hardware/samsung_slsi/exynos5433`, with the module
  name, trustlet path, data directory and SELinux rules it needs. It also
  lets the TEE daemon and the fingerprint HAL reach `/efs/prov` and the
  sensor's sysfs nodes.
- **GPS** (`device/samsung/gts2-common`):
  - `gpsd` couldn't start, because it links against `libicuuc.so`, which
    no longer exists outside the ICU APEX. An empty shim library takes
    its place;
  - `gpsd` crash-looped: its shim defined two `Singleton<SensorManager>`
    variables as functions, and the shim's stubs replaced the real sensor
    functions in `libsensor_vendor`;
  - SELinux now lets `gpsd` use the sensor service;
  - the GNSS HAL could crash at boot when the Broadcom blob called a
    callback that was being replaced at the same time.
- **Boot** (`device/samsung/gts2-common`): there is no metadata partition,
  and the system image had no `/metadata`, so aconfigd couldn't create its
  flag storage. System_server then crash-looped on the boot animation with
  "Missing permission definition for permission
  android.permission.RANGING". gts2-common now mounts a tmpfs on
  `/metadata` early in boot.
- **adb** (`kernel/samsung/universal5433`): adb stayed "offline", because
  adbd only does asynchronous USB I/O and this kernel's FunctionFS didn't
  support it. FunctionFS AIO is backported from Linux 3.16.
- **Speaker volume** (`kernel/samsung/universal5433`): short sounds such as
  taps and notifications played at a random volume after a pause. The codec
  driver unmuted the speaker and started the stream straight away, while the
  unmute was still ramping the volume up from mute. The driver now waits for
  the ramp to finish.
- **Low memory killer** (`kernel/samsung/universal5433`): it picked the
  same dying process again, once per thread, and killed more apps than
  needed. It now skips processes that are already exiting.
  It also kept waiting while zram was full: it only kills when free memory
  and the file cache are both low, and the file cache, mostly code of
  running apps, stayed above the limit while the system thrashed. Below 10%
  free swap it now ignores the file cache, so cached apps are killed
  instead (`/sys/module/lowmemorykiller/parameters/swap_free_low_percent`,
  0 disables it).
