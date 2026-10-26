# Mainline Linux kernel from nixpkgs.
#
# This is the standard upstream kernel, not the Armbian vendor fork.
#
# PINNED TO 7.2. The newest kernel (linuxPackages_latest, currently 7.3) has
# no OpenZFS release that supports it — zfs-kernel-2.4.4-7.3 is marked broken,
# and nixpkgs' base profile enables ZFS — so every mainline configuration
# fails to evaluate on it. 7.2.12 is the newest kernel OpenZFS 2.4.4 builds
# against.
#
# To lift the pin once a ZFS release supports the newer kernel:
#   1. switch back to linuxPackages_latest here,
#   2. re-check `mainlineBoards` in flake.nix against that kernel's
#      arch/arm64/boot/dts/rockchip — orangepi5pro is waiting on this, its
#      rk3588s-orangepi-5-pro.dts landed in 7.3.
#
# Board support status for RK3588/RK3588S in mainline:
#   https://gitlab.collabora.com/hardware-enablement/rockchip-3588/notes-for-rockchip-3588/-/blob/main/mainline-status.md
#
# Only boards with an upstream device tree can use this kernel; see
# `mainlineBoards` in flake.nix for the list and how it was determined.
#
# Unlike pkgs/kernel/vendor.nix this does not shorten the derivation name,
# so the store paths written into extlinux.conf stay long. If U-Boot ever
# rejects them, override the kernel's `name` the way vendor.nix does.
#
# Usage: pass this file as the kernelPackage specialArg in your flake:
#   specialArgs.rk3588.kernelPackage = pkgs.callPackage ./pkgs/kernel/mainline.nix {};
{linuxPackages_7_2, ...}:
linuxPackages_7_2.kernel
