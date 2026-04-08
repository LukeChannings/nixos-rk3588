# SPI TPM (Infineon SLB9670/SLB9672) support for the Compute Blade CM4 carrier board
# with a Radxa CM5 (RK3588S) compute module.
#
# The Compute Blade routes the CM4 SPI0 CE1 bus to its onboard TPM:
#   CM4 GPIO7  (CE1)  → RK3588S SPI0_CS1_M2  (GPIO1_B5)
#   CM4 GPIO11 (SCLK) → RK3588S SPI0_CLK_M2  (GPIO1_B3)
#   CM4 GPIO9  (MISO) → RK3588S SPI0_MISO_M2 (GPIO1_B1)
#   CM4 GPIO10 (MOSI) → RK3588S SPI0_MOSI_M2 (GPIO1_B2)
#
# The device-tree-overlays package DTB (used as base when any overlay is present)
# already has spi@feb00000 enabled with spi0m2_pins pinctrl, cs-gpios on
# GPIO1_B5, and a tpm@0 child node with compatible = "infineon,slb9670".
#
# The kernel DTB does not have this — it has spi@feb00000 disabled with no tpm
# node. NixOS selects the kernel DTB when overlays = [], so we must have at
# least one overlay to force use of the device-tree-overlays base DTB.
# The overlay itself does nothing except trigger that selection.
_: {
  boot.kernelModules = [
    "tpm_tis_spi"
  ];

  # systemd's tpm2 initrd module adds tpm-crb to availableKernelModules for
  # all aarch64 targets. That driver requires CONFIG_ACPI which this vendor
  # kernel lacks. The SPI TPM is handled by tpm_tis_spi instead.
  boot.initrd.allowMissingModules = true;

  hardware.deviceTree.overlays = [
    {
      name = "rk3588-spi0-tpm-cs1";
      # https://github.com/Joshua-Riek/ubuntu-rockchip/issues/1314
      dtsText = ''
        /dts-v1/;
        /plugin/;

        #include <dt-bindings/gpio/gpio.h>
        #include <dt-bindings/pinctrl/rockchip.h>

        / {
          compatible = "radxa,cm5-rpi-cm4-io";

          fragment@0 {
            target = <&spi0>;

            __overlay__ {
              status = "okay";
              #address-cells = <1>;
              #size-cells = <0>;
              pinctrl-names = "default";
              pinctrl-0 = <&spi0m2_cs1 &spi0m2_pins>;

              tpm@1 {
                compatible = "infineon,slb9670";
                status = "okay";
                reg = <1>;
                spi-max-frequency = <18500000>;
              };
            };
          };
        };
      '';
    }
  ];

  security.tpm2 = {
    enable = true;
    pkcs11.enable = true;
    tctiEnvironment.enable = true;
  };
}
