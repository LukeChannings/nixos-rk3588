{
  stdenvNoCC,
  fetchFromGitHub,
}:
stdenvNoCC.mkDerivation {
  pname = "rkbin-rk3588";
  version = "0.0.1";

  # https://github.com/armbian/rkbin/tree/master
  src = fetchFromGitHub {
    owner = "armbian";
    repo = "rkbin";
    rev = "5ffd2be7ce6cb58cf7c4bb700bb98a141592ab2f";
    sha256 = "sha256-EgMZyZ96CN1NK2m+QEM+0dKT/He0hbNiko3o2wHvU9k=";
  };

  installPhase = ''
    mkdir $out && cp rk35/rk3588* $out/
  '';
}
