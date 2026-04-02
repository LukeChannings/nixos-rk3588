# =========================================================================
#      Radxa CM5 Lite IO Board Specific Configuration
#
#      The CM5 Lite uses the RK3582 SoC — a scaled-down RK3588S variant
#      with fewer PCIe 3.0 lanes and no Mali GPU.  The IO carrier board
#      is identical to the standard CM5 IO board.
#
#      The rk3582-radxa-cm5-io.dtb is injected into the vendor kernel
#      via a postPatch in pkgs/kernel/vendor.nix.
# =========================================================================
{rk3588, ...}: let
  inherit (rk3588) pkgsKernel;
in {
  imports = [
    ./base.nix
    ./dtb-install.nix
  ];

  boot = {
    kernelPackages = pkgsKernel.linuxPackagesFor rk3588.kernelPackage;

    # Same kernel params as the CM5 IO board
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
      # Injected into the vendor kernel via postPatch in pkgs/kernel/vendor.nix
      name = "rockchip/rk3582-radxa-cm5-io.dtb";
      overlays = [];
    };

    firmware = [];
  };
}
