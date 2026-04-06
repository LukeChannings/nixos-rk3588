# Infineon SLB9670 TPM

## Raspberry Pi CM5

Overlays found in `/boot/firmware/nixos/default/overlays/`.

Enabled with `/boot/firmware/config.txt`:

```
dtparam=spi=on
dtoverlay=tpm-slb9670
```

Compiled overlay in `/boot/firmware/nixos/default/overlays/tpm-slb9670.dtbo`
Source: https://github.com/raspberrypi/linux/blob/rpi-6.1.y/arch/arm/boot/dts/overlays/tpm-slb9670-overlay.dts

```tpm-slb9670-overlay.dts
/*
 * Device Tree overlay for the Infineon SLB9670 Trusted Platform Module add-on
 * boards, which can be used as a secure key storage and hwrng.
 * available as "Iridium SLB9670" by Infineon and "LetsTrust TPM" by pi3g.
 */

/dts-v1/;
/plugin/;

/ {
	compatible = "brcm,bcm2835";

	fragment@0 {
		target = <&spi0>;
		__overlay__ {
			status = "okay";
		};
	};

	fragment@1 {
		target = <&spidev1>;
		__overlay__ {
			status = "disabled";
		};
	};

	fragment@2 {
		target = <&spi0>;
		__overlay__ {
			/* needed to avoid dtc warning */
			#address-cells = <1>;
			#size-cells = <0>;
			slb9670: slb9670@1 {
				compatible = "infineon,slb9670";
				reg = <1>;	/* CE1 */
				#address-cells = <1>;
				#size-cells = <0>;
				spi-max-frequency = <32000000>;
				status = "okay";
			};

		};
	};
};
```

Enables `/dev/tpm0` and `/dev/tpmrm0`

```bash
dmesg | grep 'tpm'
[    7.040354] systemd[1]: Expecting device /dev/tpmrm0...
[    8.440799] tpm_tis_spi spi0.1: 2.0 TPM (device-id 0x1B, rev-id 22)
```

## Radxa CM5

### Bootloader

Only u-boot is supported for the Radxa CM5 / CM5 Lite.

