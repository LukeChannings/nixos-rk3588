# SPI TPM (Infineon SLB9670/SLB9672) support for the Compute Blade CM4 carrier board
# with a Radxa CM5 (RK3588S) compute module.
#
# The Compute Blade routes the CM4 SPI0 CE1 bus to its onboard TPM:
#   CM4 GPIO7  (CE1)  → RK3588S SPI0_CS1_M2  (GPIO1_B5)
#   CM4 GPIO11 (SCLK) → RK3588S SPI0_CLK_M2  (GPIO1_B3)
#   CM4 GPIO9  (MISO) → RK3588S SPI0_MISO_M2 (GPIO1_B1)
#   CM4 GPIO10 (MOSI) → RK3588S SPI0_MOSI_M2 (GPIO1_B2)
#
# Equivalent to the Raspberry Pi `tpm-slb9670` dtoverlay + `spi=on` base-dt-param.
_: {
  boot.kernelModules = ["tpm_tis_spi"];

  # systemd's tpm2 initrd module adds tpm-crb to availableKernelModules for
  # all aarch64 targets. That driver requires CONFIG_ACPI which this vendor
  # kernel lacks. The SPI TPM is handled by tpm_tis_spi instead.
  boot.initrd.allowMissingModules = true;

  hardware.deviceTree.overlays = [
    {
      name = "rk3588s-compute-blade-tpm";
      dtsText = ''
        /dts-v1/;
        /plugin/;

        #include <dt-bindings/pinctrl/rockchip.h>

        / {
          compatible = "radxa,cm5-io";

          fragment@0 {
            target = <&spi0>;

            __overlay__ {
              status = "okay";
              #address-cells = <1>;
              #size-cells = <0>;
              pinctrl-names = "default";
              /* Use SPI0_M2 mux — the set routed to the CM4 header */
              pinctrl-0 = <&spi0m2_cs1 &spi0m2_pins>;

              /* DIAGNOSTIC: spidev for raw SPI testing — replace with infineon,slb9670 when done */
              tpm: spidev@1 {
                compatible = "rockchip,spidev";
                reg = <1>; /* CE1 = CM4 GPIO7 */
                spi-max-frequency = <1000000>;
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
