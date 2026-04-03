# =========================================================================
#      Radxa CM5 IO Board Specific Configuration
# =========================================================================
{rk3588, ...}: let
  inherit (rk3588) pkgsKernel;
in {
  imports = [
    ./base.nix
    ./dtb-install.nix
    ../hardware/compute-blade-tpm.nix
  ];

  boot = {
    kernelPackages = pkgsKernel.linuxPackagesFor rk3588.kernelPackage;

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
