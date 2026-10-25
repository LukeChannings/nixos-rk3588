{
  lib,
  config,
  pkgs,
  rk3588,
  ...
}: let
  rootPartitionUUID = "14e19a7b-0ae0-484d-9d54-43bd6fdc20c7";
  # build-from-source.nix takes rkbin-rk3588 (the Rockchip blobs for BL31 and
  # the DDR init) as an argument; it is not in nixpkgs, so pass it explicitly.
  uboot = pkgs.callPackage ../../pkgs/u-boot-radxa-cm5-io/build-from-source.nix {
    rkbin-rk3588 = pkgs.callPackage ../../pkgs/rkbin-rk3588 {};
  };
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
