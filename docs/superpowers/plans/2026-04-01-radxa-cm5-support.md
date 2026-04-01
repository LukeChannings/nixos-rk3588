# Radxa CM5 Support Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add NixOS SD image support for the Radxa CM5 (and CM5 Lite) on the CM5 IO Board, following the same patterns as Rock 5A and OPi5Pro.

**Architecture:** The CM5 uses Rockchip RK3588S and the two-stage U-Boot boot pattern (idbloader.img + u-boot.itb), identical to Rock5A. We use the Armbian prebuilt U-Boot DEB (committed to the repo), the existing Armbian vendor kernel (which already includes the CM5 DTB), and produce an SD image with U-Boot embedded. The CM5 Lite has no SPI NOR flash, so U-Boot must live in the SD image — no assumptions about pre-flashed bootloader.

**Tech Stack:** Nix flakes, NixOS SD image module, Armbian linux-rockchip 6.1 kernel, prebuilt Armbian U-Boot DEB, dpkg for extraction.

---

## File Map

| Action | Path | Purpose |
|--------|------|---------|
| Create | `pkgs/u-boot-radxa-cm5-io/default.nix` | Extract idbloader.img + u-boot.itb from committed DEB |
| Create | `pkgs/u-boot-radxa-cm5-io/<deb-filename>.deb` | Committed prebuilt Armbian U-Boot binary |
| Create | `modules/boards/radxa-cm5-io.nix` | Board core config: kernel, DTB, kernel params |
| Create | `modules/sd-image/radxa-cm5-io.nix` | SD image config: partitioning, U-Boot embedding |
| Modify | `flake.nix` | Register new board in nixosModules.boards and nixosConfigurations packages |

---

## Task 1: Obtain and commit the prebuilt U-Boot DEB

**Files:**
- Create: `pkgs/u-boot-radxa-cm5-io/<deb-filename>.deb`

The Armbian project publishes a prebuilt U-Boot DEB for the Radxa CM5 IO via GitHub Container Registry. We commit this binary directly (same approach as OPi5Pro's committed DEB).

- [ ] **Step 1: Pull the Armbian U-Boot OCI artifact and extract the DEB**

```bash
# Pull the container image (no Docker daemon needed — use skopeo or oras)
# If neither is available, use nix-shell:
nix-shell -p skopeo --run "skopeo copy docker://ghcr.io/armbian/os/uboot-radxa-cm5-io-vendor:2017.09-S8e7d-P60ca-Hedea-Vded9-B138f-R448a oci:/tmp/cm5-uboot-oci"

# Extract the DEB from the OCI image layers:
mkdir -p /tmp/cm5-uboot-extract
cd /tmp/cm5-uboot-extract
# Find the layer tarballs and extract
for layer in /tmp/cm5-uboot-oci/blobs/sha256/*; do
  file "$layer" | grep -q "gzip" && tar -tzf "$layer" 2>/dev/null | grep -q "\.deb" && tar -xzf "$layer" 2>/dev/null && echo "extracted from $layer"
done
find /tmp/cm5-uboot-extract -name "*.deb"
```

Expected: A file like `linux-u-boot-radxa-cm5-io-vendor_2017.09-S8e7d-P60ca-Hedea-Vded9-B138f-R448a_arm64.deb`

- [ ] **Step 2: Verify the DEB contains the expected boot files**

```bash
dpkg -c /tmp/cm5-uboot-extract/linux-u-boot-*.deb
```

Expected output includes lines like:
```
./usr/lib/linux-u-boot-vendor-radxa-cm5-io/idbloader.img
./usr/lib/linux-u-boot-vendor-radxa-cm5-io/u-boot.itb
```

Note the exact directory name inside the DEB (e.g. `linux-u-boot-vendor-radxa-cm5-io`) — you'll need it in Task 2.

- [ ] **Step 3: Create the package directory and copy the DEB**

```bash
mkdir -p /path/to/repo/pkgs/u-boot-radxa-cm5-io
cp /tmp/cm5-uboot-extract/linux-u-boot-*.deb pkgs/u-boot-radxa-cm5-io/
```

- [ ] **Step 4: Commit**

```bash
git add pkgs/u-boot-radxa-cm5-io/
git commit -m "Add prebuilt U-Boot DEB for Radxa CM5 IO"
```

---

## Task 2: Write the U-Boot Nix package (DEB extraction)

**Files:**
- Create: `pkgs/u-boot-radxa-cm5-io/default.nix`

This mirrors `pkgs/u-boot-opi5pro/default.nix` exactly, adjusted for the CM5 filenames.

- [ ] **Step 1: Create `pkgs/u-boot-radxa-cm5-io/default.nix`**

```nix
{stdenv, lib, fetchzip, dpkg, ...}:
  stdenv.mkDerivation rec {
      pname = "linux-u-boot-radxa-cm5-io-vendor";
      version = "2017.09";
      src = ./.;

      buildInputs = [
        dpkg
      ];

      dontConfigure = true;
      dontBuild = true;

      installPhase = ''
        runHook preInstall

        set -x
        mkdir -p $out/unpack
        dpkg -x linux-u-boot-radxa-cm5-io-vendor_*.deb $out/unpack
        mv $out/unpack/usr/lib/linux-u-boot-vendor-radxa-cm5-io/u-boot.itb $out/
        mv $out/unpack/usr/lib/linux-u-boot-vendor-radxa-cm5-io/idbloader.img $out/
        rm -r $out/unpack
        set +x

        runHook postInstall
      '';
  }

  ## See
  # https://github.com/armbian/build/blob/main/config/boards/radxa-cm5-io.conf
  # https://github.com/armbian/os/pkgs/container/os%2Fuboot-radxa-cm5-io-vendor
```

> **Note:** The glob `linux-u-boot-radxa-cm5-io-vendor_*.deb` handles any version suffix. The path inside the DEB (`linux-u-boot-vendor-radxa-cm5-io`) was verified in Task 1 Step 2. If the actual path inside the DEB differs, update the `mv` lines accordingly.

- [ ] **Step 2: Test that the package builds**

```bash
nix-build -E '(import <nixpkgs> {}).callPackage ./pkgs/u-boot-radxa-cm5-io {}'
ls result/
```

Expected: `result/idbloader.img` and `result/u-boot.itb`

- [ ] **Step 3: Commit**

```bash
git add pkgs/u-boot-radxa-cm5-io/default.nix
git commit -m "Add U-Boot package for Radxa CM5 IO (extracts from Armbian DEB)"
```

---

## Task 3: Write the board core module

**Files:**
- Create: `modules/boards/radxa-cm5-io.nix`

This follows the Rock 5A pattern (`modules/boards/rock5a.nix`). The CM5 IO board uses:
- DTB: `rockchip/rk3588s-radxa-cm5-io.dtb` (confirmed present in Armbian linux-rockchip at the commit already used by this project)
- Serial console: `ttyFIQ0` at 1500000 baud (same as Rock 5A — both are Radxa boards with same Armbian console setup)
- No board-specific firmware package needed (unlike OPi5Pro which uses orangepi-firmware)

- [ ] **Step 1: Create `modules/boards/radxa-cm5-io.nix`**

```nix
# =========================================================================
#      Radxa CM5 IO Board Specific Configuration
# =========================================================================
{rk3588, ...}: let
  pkgsKernel = rk3588.pkgsKernel;
in {
  imports = [
    ./base.nix
    ./dtb-install.nix
  ];

  boot = {
    kernelPackages = pkgsKernel.linuxPackagesFor (pkgsKernel.callPackage ../../pkgs/kernel/vendor.nix {});

    # kernelParams based on Rock 5A and Armbian's extlinux.conf for CM5
    kernelParams = [
      "rootwait"
      "rw"

      "earlycon"
      "consoleblank=0"
      "console=tty0"
      "console=ttyAML0,115200n8"
      "console=ttyS0,1500000n8"
      "console=ttyS2,1500000n8"
      "console=ttyFIQ0,1500000n8"

      "coherent_pool=2M"
      "irqchip.gicv3_pseudo_nmi=0"

      "splash"
      "plymouth.ignore-serial-consoles"

      # docker optimizations
      "cgroup_enable=cpuset"
      "cgroup_memory=1"
      "cgroup_enable=memory"
      "swapaccount=1"
    ];
  };

  hardware = {
    deviceTree = {
      # https://github.com/armbian/linux-rockchip/blob/rk-6.1-rkr5.1/arch/arm64/boot/dts/rockchip/rk3588s-radxa-cm5-io.dts
      name = "rockchip/rk3588s-radxa-cm5-io.dtb";
      overlays = [];
    };

    firmware = [];
  };
}
```

- [ ] **Step 2: Commit**

```bash
git add modules/boards/radxa-cm5-io.nix
git commit -m "Add Radxa CM5 IO board core module"
```

---

## Task 4: Write the SD image module

**Files:**
- Create: `modules/sd-image/radxa-cm5-io.nix`

This mirrors `modules/sd-image/orangepi5pro.nix` (which uses the same sd-image-aarch64.nix base and two-stage U-Boot embedding). The CM5 has no SPI NOR flash on the Lite variant, so U-Boot must be embedded in the image.

- [ ] **Step 1: Create `modules/sd-image/radxa-cm5-io.nix`**

```nix
{
  lib,
  config,
  pkgs,
  rk3588,
  ...
}: let
  rootPartitionUUID = "14e19a7b-0ae0-484d-9d54-43bd6fdc20c7";
  uboot = pkgs.callPackage ../../pkgs/u-boot-radxa-cm5-io {};
in {
  imports = [
    "${rk3588.nixpkgs}/nixos/modules/installer/sd-card/sd-image-aarch64.nix"
  ];

  boot = {
    kernelParams = [
      "root=UUID=${rootPartitionUUID}"
      "rootfstype=ext4"
    ];

    loader = {
      grub.enable = lib.mkForce false;
      generic-extlinux-compatible.enable = lib.mkForce true;
    };
  };

  sdImage = {
    inherit rootPartitionUUID;
    compressImage = true;

    populateFirmwareCommands = ''
      ${config.boot.loader.generic-extlinux-compatible.populateCmd} -c ${config.system.build.toplevel} -d ./firmware
    '';
    firmwarePartitionOffset = 32;
    firmwarePartitionName = "BOOT";
    firmwareSize = 200; # MiB

    populateRootCommands = ''
      mkdir -p ./files/boot
      mkdir -p ./files/boot/firmware
    '';

    # https://opensource.rock-chips.com/wiki_Boot_option
    # idbloader.img (SPL) at sector 64 (0x40)
    # u-boot.itb at sector 16384 (0x4000)
    postBuildCommands = ''
      dd if=${uboot}/idbloader.img of=$img seek=64 conv=fsync,notrunc
      dd if=${uboot}/u-boot.itb of=$img seek=16384 conv=fsync,notrunc
    '';
  };
}
```

- [ ] **Step 2: Commit**

```bash
git add modules/sd-image/radxa-cm5-io.nix
git commit -m "Add Radxa CM5 IO SD image module"
```

---

## Task 5: Register the board in flake.nix

**Files:**
- Modify: `flake.nix`

Three places need updating: `nixosModules.boards`, `packages` sdImage entries, and `packages` sdImage-cross entries. The UEFI entries are auto-generated from `nixosModules.boards` so no extra work there.

- [ ] **Step 1: Add to `nixosModules.boards` in `flake.nix`**

In `flake.nix`, inside the `boards = {` block (around line 55), add after the `rock5a` entry:

```nix
          # Radxa CM5 on CM5 IO Board
          radxa-cm5-io = {
            core = import ./modules/boards/radxa-cm5-io.nix;
            sd-image = ./modules/sd-image/radxa-cm5-io.nix;
          };
```

- [ ] **Step 2: Add sdImage package aliases in `flake.nix`**

In the `packages = {` block (around line 174), add after the `sdImage-rock5a` and `sdImage-rock5a-cross` lines:

```nix
        sdImage-radxa-cm5-io = self.nixosConfigurations.radxa-cm5-io.config.system.build.sdImage;
        sdImage-radxa-cm5-io-cross = self.nixosConfigurations.radxa-cm5-io-cross.config.system.build.sdImage;
```

- [ ] **Step 3: Verify the flake evaluates**

```bash
nix flake check --no-build 2>&1 | head -40
```

Expected: No evaluation errors. (Build errors are fine at this stage — we haven't built yet.)

- [ ] **Step 4: Commit**

```bash
git add flake.nix
git commit -m "Register Radxa CM5 IO board in flake"
```

---

## Task 6: Verify the image builds

- [ ] **Step 1: Build the cross-compiled SD image (faster on x86_64)**

```bash
nix build .#sdImage-radxa-cm5-io-cross
```

Expected: Succeeds, produces `result/` symlink pointing to a `.img.zst` file.

- [ ] **Step 2: Verify U-Boot is embedded correctly**

```bash
# Check the idbloader.img is present at sector 64 (byte offset 32768)
dd if=$(zstd -d --stdout result/*.img.zst) bs=512 skip=64 count=1 2>/dev/null | xxd | head -4
```

Expected: Non-zero output (Rockchip header magic `RK` or similar).

- [ ] **Step 3: Commit any fixes, then tag as experimental**

```bash
git add -A
git commit -m "Add experimental Radxa CM5 IO NixOS image"
```

---

## Notes & Known Unknowns

1. **DEB internal path**: The `mv` commands in `pkgs/u-boot-radxa-cm5-io/default.nix` assume the files live at `usr/lib/linux-u-boot-vendor-radxa-cm5-io/`. Verify with `dpkg -c` in Task 1 Step 2 and adjust if different.

2. **Serial console**: The kernel params include multiple console entries copied from Rock 5A. The CM5 IO board's primary debug UART is likely `ttyFIQ0` at 1500000 baud. If the serial console is silent, try `ttyS2,1500000` instead.

3. **CM5 Lite**: The CM5 Lite differs only in RAM/eMMC options; it uses the same IO board and DTB. No separate NixOS module is needed — the same image works for both CM5 and CM5 Lite when booted from SD.

4. **Latest kernel DTB check**: The DTB `rk3588s-radxa-cm5-io.dtb` is confirmed present in `armbian/linux-rockchip` at commit `b908c733...` (the version pinned in `pkgs/kernel/vendor.nix`). No kernel upgrade needed.

5. **No upstream kernel**: The user requested "latest version of Linux" meaning we should use the most current Armbian vendor kernel available, not Radxa's BSP/rsdk. The existing Armbian 6.1 kernel in this repo already supports the CM5. If a newer Armbian kernel branch becomes available, updating `pkgs/kernel/vendor.nix` is a separate task.
