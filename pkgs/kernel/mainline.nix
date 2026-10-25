# Mainline Linux kernel from nixpkgs.
#
# Uses pkgs.linuxPackages_latest — the newest stable kernel in nixpkgs.
# This is the standard upstream kernel, not the Armbian vendor fork.
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
{linuxPackages_latest, ...}:
linuxPackages_latest.kernel
