# LineageOS 24.0/Android 17 patches for Galaxy Tab S2 9.7 Wi-Fi (gts210wifi)

These instructions assume that:

- the LineageOS 24.0 sources live (or will live) in `~/android/system`
  (see <https://github.com/LineageOS/android/tree/lineage-24.0>)
- this repository is cloned in `~/android/system/patches/gts210wifi-patches`
- `git`, `git-lfs`, `repo` and `xmllint` are installed, plus the usual
  LineageOS build dependencies

All scripts accept the source root as their last argument and default to the
current directory. Run them directly (`./setup.sh`); sourcing them
(`. setup.sh`) also works.

## Quick start: set up everything

```bash
cd ~/android/system
patches/gts210wifi-patches/LOS-24.0/setup.sh
```

`setup.sh` does the whole job and can be re-run at any time:

1. `repo init -b lineage-24.0 --git-lfs` if the directory isn't a checkout yet
2. `cleanup.sh`: removes local manifests of other devices and drops any
   previously applied patches (gts210wifi's or another device's)
3. installs `exynos5433-24.0.xml` into `.repo/local_manifests/`
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

To return the tree to plain LineageOS 24.0, without any local manifest or
patches:

```bash
cd ~/android/system
patches/gts210wifi-patches/LOS-24.0/cleanup.sh
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
patches/gts210wifi-patches/LOS-24.0/apply.sh
patches/gts210wifi-patches/LOS-24.0/revert.sh
```

A repo whose patches don't apply is left in the middle of `git am` so it can
be resolved by hand; the output points at a log with the details. `revert.sh`
aborts that and resets the patched repos with `repo sync`.

## Maintaining the patch set

- The patched repositories are listed once, in `common.sh` (`PATCHED_REPOS`).
  To track a new repo, add a line there and put its `git format-patch` output
  in the matching `android_*` directory.
- Device, kernel, hardware and vendor repos are forks, listed in
  `exynos5433-24.0.xml`. `create-lineage-24.0-branches.sh` creates and pushes
  the `lineage-24.0` branch in each of them.

## What the patches address

The Tab S2 (exynos5433) is a legacy device: a Linux 3.10 kernel, no Treble,
no separate vendor partition, and closed-source blobs built for Android 6-7.
LineageOS 24.0 builds against current AOSP, which has removed much of the
compatibility code these blobs and this kernel depend on. The patches put
it back, grouped here by problem rather than by repository.

- **No BPF in the kernel** (`system_bpf`, `system_netd`,
  `packages_modules_Connectivity`, `packages_modules_DnsResolver`,
  `frameworks_native`): Android now requires eBPF for network statistics,
  per-app firewalling and DNS. The BPF loaders, netd and DnsResolver no
  longer abort when BPF is missing. Beyond the usual no-BPF patches, this
  release needed more:
  - NetBpfLoad has two new kernel-version gates (5.10 and 5.15) that stopped
    it before it set `bpf.progs_loaded`.
  - `BpfNetMaps` crashed system_server when the BPF maps were missing: once
    at boot (uid permission maps) and once as soon as Wi-Fi got an IP
    address (local-network access map). Both are now guarded.
  - `LocalNetEventHandler` and `LoopbackEventHandler` aborted system_server
    when their BPF ring buffers weren't there.

  `gpuservice` is disabled, because its GPU memory accounting needs BPF.
- **Kernel without netlink TCP info** (`packages_modules_NetworkStack`):
  reverts the NetworkStack changes that require querying TCP info over a
  netlink socket and parsing kernel netlink events, and fixes the code those
  reverts restored so it builds against current NetworkStack.
- **cgroup v1-only kernel** (`system_core`, `frameworks_base`,
  `system_netd`, `system_zygote`): the kernel has no cgroup v2. These revert
  the v2-only freezer and memcg defaults, let cgroup setup continue when a
  controller fails to mount, and make process-group creation failures
  non-fatal in the framework and netd. `system_zygote` does the same for
  Android 17's Rust `zygote_next`, which starts the native-only sandboxed
  processes of Chrome and WebView. It aborted every child with "Unable to
  create cgroup for process". It now also skips capabilities newer than the
  kernel (3.10 stops at `CAP_BLOCK_SUSPEND`) when dropping the bounding set,
  and logs Rust panics to logcat, because `zygote_next`'s stderr goes to
  /dev/null. These patches are the same as galaxys7-patches'
  `system_zygote`.
- **Old kernel syscalls** (`bionic`, `art`, `external_perfetto`,
  `frameworks_native`): `memfd_create` version checks, `MADV_WIPEONFORK` in
  `arc4random`, `renameat2` (`renameat()` is reverted to the old
  implementation) and `epoll_pwait2` (Linux 5.11; without a fallback
  `BLASTBufferQueue` can't release buffers). `Bitmap` keeps using ashmem
  instead of memfd, because memfd broke apps such as YouTube with "Could not
  copy bitmap to parcel blob". `libbinder` no longer aborts when it shrinks
  its thread pool.
- **Old prebuilt blobs** (`bionic`): linker shim libraries
  (`LD_SHIM_LIBS`), ignoring library namespaces so vendor blobs can load
  system libraries, a per-process target SDK override, and the pre-Android 9
  mutex behaviour these blobs expect.
- **No Treble, no vendor partition** (`system_linkerconfig`, `build_soong`,
  `build_make`):
  - restores the non-Treble linker configuration;
  - fixes Soong's filesystem generator for vendor-only modules installed
    under `/system/vendor`;
  - fixes the OTA build writing `recovery-from-boot.p` to a path nothing
    reads, which made `otapackage` fail with `AssertionError`.
- **Samsung boot image and kernel build** (`build_make`, `build_soong`,
  `system_tools_mkbootimg`, `prebuilts_build-tools`, `vendor_lineage`,
  `hardware_samsung`):
  - `dt.img` support in boot and recovery images (`mkbootimg --dt`);
  - device-specific header overrides (`TARGET_SPECIFIC_HEADER_PATH`), and
    automatic use of the kernel header library;
  - xz 5.2.5 for the kernel build;
  - uncompressed APEXes;
  - LineageOS's kernel flags no longer replace the device's own GCC flags
    with clang-only ones;
  - `lineage_generator` modules are skipped when this board config doesn't
    export the variables they need.
- **Camera HAL v1** (`frameworks_av`, `frameworks_base`, `system_core`,
  `device_lineage_sepolicy`): the camera blob only speaks the HAL v1 API,
  which AOSP removed. This restores HALv1 support in cameraserver and
  mediaserver, the `camera2.legacy` shim, the old recording path and the
  HALv1 sepolicy. On top of that:
  - fixes the restored code for current interfaces (`AudioRestriction`,
    `SurfaceType`, the batched and consolidated `configureStreams` calls);
  - keeps `camera2.legacy` out of the public API;
  - fixes the two crashes that stopped camera preview (consolidated
    `configureStreams` rejected, null `multiResConcurrentReadersInfo`).
- **Legacy HIDL HALs** (`hardware_lineage_interfaces`,
  `hardware_libhardware_legacy`, `device_lineage_sepolicy`,
  `frameworks_base`, `frameworks_native`, `frameworks_hardware_interfaces`,
  `system_tools_hidl`):
  - restores the legacy Wi-Fi HIDL HAL (1.0-legacy, with dynamic softAP
    interfaces) and the Wi-Fi headers it builds against;
  - restores the legacy GNSS passthrough HAL, the sepolicy labels for both
    HALs, and `android.frameworks.schedulerservice`;
  - `HintManagerService` no longer crashes when there is no AIDL power HAL;
  - `libperfmgr` is linked statically: the power HAL couldn't find
    `libperfmgr.so`, so it never registered and system_server was killed by
    the watchdog at boot.
- **Samsung hardware** (`hardware_samsung`, `hardware_lineage_compat`):
  - restores macloader and wifiloader;
  - fixes audio/RIL, `libdtbimg` headers and the USB gadget HAL's namespace
    import;
  - disables the IR HIDL service, which was removed upstream (this device
    has no IR blaster);
  - fixes a `libsensor` null-pointer crash in
    `SensorManager::getSensorList`;
  - the fingerprint HAL also looks for templates in `/data/biometrics`. The
    old `libbauthserver.so` can't list its own enrollments and stores them
    there, so the HAL found none and every fingerprint was removed at boot.
- **Stability and build fixes** (`frameworks_base`, `frameworks_av`,
  `frameworks_native`, `bootable_recovery`, `system_vold`, `build_make`):
  - `AdvancedProtectionService` no longer crash-loops system_server on a
    feature flag it can't resolve;
  - `FileIntegrity` skips fs-verity, which this kernel lacks, instead of
    logging a stack trace on every settings and permissions write;
  - lmkd no longer exits at every boot: it uses the kernel's low memory
    killer, but tried to start PSI monitoring when ActivityManager asked,
    and this kernel has no PSI;
  - media codec fixes (no crash when a codec fails to load, no leaks when a
    buffer lock times out or an observer dies);
  - missing `<algorithm>`/`<vector>` includes for the current libc++;
  - `link_type_error` downgraded to a warning;
  - fast reboot on legacy devices too;
  - reverts of the SurfaceFlinger fuzzer removal and of SurfaceFlinger's
    string-free permission check (with a build fix for the latter).

## Fixes in the device and kernel repos

Some problems are fixed in the forked repos from `exynos5433-24.0.xml`
instead of with patches. They come with `repo sync` and need no
`apply.sh`.

- **Speaker volume** (`kernel/samsung/universal5433`,
  `device/samsung/gts2-common`):
  - Short sounds such as taps and notifications played at a random volume
    after a pause. The codec driver unmuted the speaker and started the
    stream straight away, while the unmute was still ramping the volume
    up from mute. The driver now waits for the ramp to finish. This
    happened on 23.2 as well, but the louder 24.0 volume curves made it
    much more noticeable.
  - AOSP's ring, notification and alarm curves are made for phone
    speakers, so even the lowest step was loud on the tablet. Ring and
    notifications now use the media curve. The alarm gets its own curve,
    which starts at -40 dB instead of -30 dB but stays well above the
    media curve's -58 dB, so it can still wake you up.
  - The longer AudioFlinger standby time from earlier builds, a first
    attempt at the random volume, is gone: it didn't help.
