{
  buildUBoot,
  fetchFromGitHub,
  rkbin-rk3588,
}:
(buildUBoot {
  version = "next-dev-v2026.01";

  # https://github.com/radxa/u-boot/tree/next-dev-v2026.01
  src = fetchFromGitHub {
    owner = "radxa";
    repo = "u-boot";
    rev = "6f9e3b8828bc7d11b319b18e3b2edd7c12e9180d";
    sha256 = "sha256-4Dv4CnIMJIaceBRd2Hdlyq+nOD9dG5B+SZeU6RkCGao=";
  };

  # https://github.com/radxa/u-boot/blob/next-dev-v2026.01/configs/radxa-cm5-rpi-cm4-io-rk3588s_defconfig
  defconfig = "radxa-cm5-rpi-cm4-io-rk3588s_defconfig";

  extraMeta.platforms = ["aarch64-linux"];
  BL31 = "${rkbin-rk3588}/rk3588_bl31_v1.51.elf";

  buildPhase = ''
    export BL31=${rkbin-rk3588}/rk3588_bl31_v1.51.elf
    make -j20 BL31=$BL31 spl/u-boot-spl.bin u-boot.dtb u-boot.itb

    tools/mkimage -n rk3588 -T rksd -d \
      ${rkbin-rk3588}/rk3588_ddr_lp4_2112MHz_lp5_2736MHz_v1.15.bin:spl/u-boot-spl.bin \
      idbloader.img
  '';

  filesToInstall = [
    "spl/u-boot-spl.bin"

    "u-boot.itb"
    "idbloader.img"
  ];
}).overrideAttrs
(_oldAttrs: {
  patches = []; # remove all patches, which is not compatible with thead-u-boot

  # Replaced wholesale rather than appended to. nixpkgs' buildUBoot ends its
  # postPatch with a dtc 1.8 workaround that rewrites -Wno-graph_child_address
  # to -Eno-node_name_not_empty in scripts/Makefile.lib and
  # dts/upstream/Makefile, using --replace-fail. This fork carries that flag
  # in neither file (and has no dts/upstream at all), so the substitution
  # aborts the build before a single object is compiled.
  #
  # Nothing else in the stock postPatch is lost: it otherwise only runs the
  # two patchShebangs calls repeated below, plus a loop over
  # pythonScriptsToInstall, which is empty here because this package does not
  # set it.
  #
  # If the fork ever gains binman "@<name>-SEQ" template nodes, dtc will start
  # rejecting them as node_name_not_empty and the upstream workaround will
  # need reinstating against whatever file then carries DTC_FLAGS.
  postPatch = ''
    patchShebangs tools
    patchShebangs scripts
    patchShebangs --build arch/arm/mach-rockchip/make_fit_atf.sh arch/arm/mach-rockchip/decode_bl31.py
  '';
})
