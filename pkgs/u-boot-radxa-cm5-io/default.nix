{
  stdenv,
  dpkg,
  ...
}:
stdenv.mkDerivation rec {
  pname = "linux-u-boot-radxa-cm5-io-vendor";
  version = "2017.09";
  src = ./.;

  nativeBuildInputs = [
    dpkg
  ];

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    set -x
    mkdir -p $out/unpack
    dpkg -x linux-u-boot-radxa-cm5-io-vendor_*.deb $out/unpack
    mv $out/unpack/usr/lib/linux-u-boot-vendor-radxa-cm5-io/u-boot.itb $out/
    mv $out/unpack/usr/lib/linux-u-boot-vendor-radxa-cm5-io/idbloader.img $out/
    rm -r $out/unpack
    set +x

    runHook postInstall
  '';
}
## See
# https://github.com/armbian/build/blob/main/config/boards/radxa-cm5-io.conf
# https://github.com/armbian/os/pkgs/container/os%2Fuboot-radxa-cm5-io-vendor

