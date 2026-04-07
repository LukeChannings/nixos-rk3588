# TPM — Infineon SLB9670 on Compute Blade with Radxa CM5

## Hardware

The Compute Blade routes SPI0 CE1 to its onboard SLB9670 via the M2 mux group:

| CM4 signal | RK3588S pin | GPIO | Linux pin# |
|---|---|---|---|
| GPIO7 (CE1) | SPI0_CS1_M2 | GPIO1_B5 | gpio1-13 (pin 45) |
| GPIO9 (MISO) | SPI0_MISO_M2 | GPIO1_B1 | gpio1-9 (pin 41) |
| GPIO10 (MOSI) | SPI0_MOSI_M2 | GPIO1_B2 | gpio1-10 (pin 42) |
| GPIO11 (SCLK) | SPI0_CLK_M2 | GPIO1_B3 | gpio1-11 (pin 43) |

SPI0 controller: `spi@feb00000`. Clocks: `clk_spi0` = 198 MHz, `pclk_spi0` = 100 MHz.

## Register map

GPIO1B pins live in **BUS_IOC** (`0xfd5f8000`), not PMU2_IOC:

| Register | Address | Content |
|---|---|---|
| BUS_IOC `gpio1b_iomux_sel_l` | `0xfd5f8028` | Controls GPIO1_B0–B3 mux (bits[15:12]=B3, [11:8]=B2, [7:4]=B1, [3:0]=B0) |
| BUS_IOC `gpio1b_iomux_sel_h` | `0xfd5f802c` | Controls GPIO1_B4–B7 mux (bits[7:4]=B5 = CS1) |

Rockchip write-with-mask format: upper 16 bits = write mask, lower 16 bits = data.

`0xfd5f802c` produces a bus error from non-secure world (TZ-locked by bl31-v1.51). `0xfd5f8028` can be read but is also locked.

## Confirmed state (post-boot verified)

### Pinmux (confirmed via `/sys/kernel/debug/pinctrl/pinctrl-rockchip-pinctrl/pinmux-pins`)

```
pin 41 (gpio1-9):  feb00000.spi — function spi0 group spi0m2-pins  [MISO]
pin 42 (gpio1-10): feb00000.spi — function spi0 group spi0m2-pins  [MOSI]
pin 43 (gpio1-11): feb00000.spi — function spi0 group spi0m2-pins  [SCLK]
pin 45 (gpio1-13): MUX UNCLAIMED, gpio1:45                          [CS — GPIO mode]
```

### IOC registers (confirmed via `devmem2`)

- `BUS_IOC 0xfd5f8028 = 0x8880` — GPIO1_B1/B2/B3 all at SPI function 8. This value was present **before** the u-boot patch ran, meaning the vendor u-boot or SPL already sets these pins to SPI function.
- `BUS_IOC 0xfd5f802c` — bus error (TZ-locked). Kernel regmap reads `0x00000000` = GPIO1_B5 in GPIO function (correct for `cs-gpios`).

### CS GPIO (confirmed via `gpioinfo`)

```
gpiochip1 line 13: output active-low consumer="spi0 CS0"
```

GPIO1_B5 is claimed by the SPI framework and driven correctly as chip-select.

### SPI controller

`rockchip-spi feb00000.spi: probed, poll=0, rsd=0, cs-inactive=0, ready=0` — controller probed successfully.

### TPM probe

`tpm_tis_spi: probe of spi0.0 failed with error -110` — ETIMEDOUT on every boot and every manual `modprobe`.

## Raw SPI test result

With `tpm_tis_spi` unloaded and `spidev` bound to `spi0.0`, Python `spidev.xfer2()` was used to perform raw transfers:

- Tested at 100 kHz, 1 MHz, and 10 MHz
- MOSI driven 0xFF (all high) and 0x00 (all low)
- **MISO = 0x00 on every byte in every test**

MISO is not floating (which would give variable or high values due to SPI controller pull-up) — it is stuck at 0. The SLB9670 is not driving its MISO output at all.

**Conclusion: the failure is at the physical hardware level.** The software and firmware configuration is correct. The SLB9670 is either not receiving the SPI clock/CS signals, or is not responding due to a connector/seating issue.

## Software configuration (correct — no changes needed)

### NixOS module: `modules/hardware/compute-blade-tpm.nix`

Uses the `device-tree-overlays` base DTB (selected automatically when `hardware.deviceTree.overlays` is non-empty). The overlay sets:
- `status = "okay"` on `spi@feb00000`
- `pinctrl-names = "default", "high_speed"` both pointing to `spi0m2_pins` (workaround for vendor kernel 6.1 bug where `dev->pins` is NULL at probe unless `high_speed` state exists)
- `num-cs = <1>`, `cs-gpios = <&gpio1 RK_PB5 GPIO_ACTIVE_LOW>`
- `tpm@0 { compatible = "infineon,slb9670"; reg = <0>; spi-max-frequency = <32000000>; }`

### u-boot patch: `pkgs/u-boot-radxa-cm5-io/build-from-source.nix`

Injects two `writel()` calls in `arch_cpu_init()` under `#ifdef CONFIG_SPL_BUILD`, just before `spl_board_sd_iomux_save()`, to set GPIO1_B3 and GPIO1_B5 to SPI function 8 in BUS_IOC before bl31 locks the registers:

```c
writel(0xf0008000, 0xfd5f8028); /* GPIO1_B3 -> SPI0_CLK_M2 (func 8, BUS_IOC) */
writel(0x00f00080, 0xfd5f802c); /* GPIO1_B5 -> SPI0_CS1_M2 (func 8, BUS_IOC) */
```

Note: as of the last boot, `BUS_IOC 0xfd5f8028` was already `0x8880` (SPI function 8) before this patch ran — the vendor SPL appears to initialise these pins already. The patch is a belt-and-suspenders measure; it does not hurt and may matter on other firmware versions.

## SCMI

SCMI protocol 17 (pinctrl) is not active in this firmware (`Failed. SCMI protocol 17 not active`). There is no firmware API to request mux changes from Linux.

## Key fact: same hardware works with RPi CM5

The same Compute Blade carrier + SLB9670 TPM module works correctly with a Raspberry Pi CM5 ("Savage"). This eliminates a bad TPM module or carrier board trace as the cause. The problem is Radxa CM5-specific.

## RPi `tpm-slb9670` overlay (decompiled from working CM5)

Source: `/boot/firmware/nixos/default/overlays/tpm-slb9670.dtbo` (Savage/Saint/Siren)

Requires `dtparam=spi=on` in `config.txt` (enables the SPI0 controller). The overlay itself is minimal:
- fragment@0: enables `spi0` (`status = "okay"`)
- fragment@1: disables `spidev1`
- fragment@2: adds `slb9670@1` on spi0 with `reg = <0x01>` (CE1), `spi-max-frequency = 32000000`

Notable absences: **no `reset-gpios`, no `interrupts`, no pinctrl overrides**. The RPi relies entirely on hardware defaults for reset and pin mux.

### Differences from Radxa overlay

| Property | RPi overlay | Radxa overlay |
|---|---|---|
| TPM node | `slb9670@1`, `reg = <1>` (native CE1) | `tpm@0`, `reg = <0>` (GPIO CS) |
| CS method | SPI controller native CE1 | `cs-gpios = <&gpio1 RK_PB5 GPIO_ACTIVE_LOW>` |
| pinctrl | none (RPi defaults) | explicit `spi0m2_pins` for default + high_speed |
| reset-gpios | none | none |
| interrupts | none | none |

The `reg` / CS difference is expected — the RPi SPI controller has native CE1, while the RK3588S SPI0 needs GPIO-based CS to reach the M2 mux group pin. Both ultimately drive the same physical CM4 CE1 line.

## UEFI considered and ruled out

EDK2 has a [closed PR for CM5 support](https://github.com/edk2-porting/edk2-rk3588/pull/186) but it adds only basic board support (DT, ACPI, platform lib) — no SPI or TPM configuration. The Armbian forum thread (below) showed UEFI actually breaks overlay application, requiring TPM to be baked into the base DTS. Since our overlay is already applying correctly and the failure is at the electrical level (MISO stuck at 0), switching boot firmware would not help.

## Reference: Orange Pi 5 Plus (RK3588) TPM success

[Armbian forum thread](https://forum.armbian.com/topic/56220-orange-pi-5-plus-tpm20-overlay/): user got SLB9670 working on OPi5+ (RK3588) using SPI0 CS1 — same bus/CS as the Compute Blade. They used UEFI boot, which skips U-Boot overlay application entirely, so they had to bake TPM support into the base DTS at build time. No overlay source was shared. This confirms SLB9670 on RK3588 SPI0 CS1 is a known-working configuration — the issue is specific to our pin mux or reset state, not a fundamental SoC/driver incompatibility.

## Root cause: VCCIO1 is 1.8V — voltage level mismatch

### Confirmed from Radxa CM5 V2.21 schematic

The Radxa CM5 module schematic ([radxa_cm5_v2210_schematic.pdf](https://dl.radxa.com/cm5/v2210/radxa_cm5_v2210_schematic.pdf)) shows:

- **VCCIO1 domain = 1.8V** (`VCCIO1_1V8`)
- All GPIO1 bank pins (including SPI0 M2: GPIO1_B1–B5) operate at 1.8V
- The Radxa CM5 carrier board design note explicitly warns: "The GPIO has two types of 1.8V and 3.3V"

### The mismatch

The Compute Blade powers the SLB9670 at 3.3V (CM4-standard power rail). The SLB9670 datasheet ([infineon-slb-9670vq2.0-datasheet-en.pdf](https://www.infineon.com/assets/row/public/documents/30/49/infineon-slb-9670vq2.0-datasheet-en.pdf)) specifies:

| Parameter | Value |
|---|---|
| VDD | 3.3V (3.0–3.6V) or 1.8V (1.65–1.95V) |
| VIH at 3.3V VDD | 0.7 × VDD = **2.31V** |
| VIH at 1.8V VDD | 0.7 × VDD = **1.26V** |
| Max SPI at 3.3V | 43 MHz |
| Max SPI at 1.8V | 22.5 MHz |

With the TPM running at 3.3V VDD but receiving 1.8V SPI signals from the RK3588S:
- RK3588S SPI output high ≈ 1.62V (0.9 × 1.8V)
- TPM VIH threshold = 2.31V
- **1.62V < 2.31V → TPM never sees valid high signals → MISO stuck at 0**

The RPi CM4/CM5 uses 3.3V GPIO on its SPI pins, which is why the same hardware works.

### Theories ruled out

- **RST# pin**: SLB9670 RST# has an internal pull-up (datasheet). RPi overlay does not configure reset-gpios. Not the cause.
- **UEFI boot**: Overlay is applying correctly. Boot firmware irrelevant.
- **Pinmux**: Confirmed correct via `pinmux-pins` debug and devmem2 IOC register reads.
- **SPI controller**: Probes successfully, CS GPIO drives correctly.

### Solutions

The fix requires a **hardware-level voltage translation** between the 1.8V VCCIO1 domain and the 3.3V TPM. Options:

1. **Level shifter**: Add a bidirectional 1.8V↔3.3V level translator (e.g., TXB0104 or BSS138-based) between the CM5 SPI pins and the TPM. Requires hardware modification to the Compute Blade.

2. **Power the TPM at 1.8V**: If the Compute Blade's TPM VDD can be rewired to a 1.8V rail instead of 3.3V, the voltage levels would match. The SLB9670 supports 1.8V operation. However, max SPI speed drops to 22.5 MHz and this requires carrier board modification.

3. **Change VCCIO1 to 3.3V**: If the Radxa CM5 PMIC can be reconfigured to supply 3.3V to VCCIO1 instead of 1.8V. This would require verifying that all other GPIO1 peripherals can tolerate 3.3V, and may not be possible if the PMIC output is fixed.

None of these are software-fixable. This is a fundamental voltage domain incompatibility between the Radxa CM5 (1.8V GPIO1) and the Compute Blade's 3.3V TPM circuit.
