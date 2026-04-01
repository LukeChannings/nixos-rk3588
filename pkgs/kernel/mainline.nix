# Mainline Linux kernel from nixpkgs.
#
# Uses pkgs.linuxPackages_latest — the newest stable kernel in nixpkgs.
# This is the standard upstream kernel, not the Armbian vendor fork.
#
# Board support status for RK3588/RK3588S in mainline:
#   https://gitlab.collabora.com/hardware-enablement/rockchip-3588/notes-for-rockchip-3588/-/blob/main/mainline-status.md
#
# Usage: pass this file as the kernelPackage specialArg in your flake:
#   specialArgs.rk3588.kernelPackage = pkgs.callPackage ./pkgs/kernel/mainline.nix {};
{pkgs, ...}:
pkgs.linuxPackages_latest.kernel
