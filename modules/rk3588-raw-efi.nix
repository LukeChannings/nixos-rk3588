{nixos-generators, ...}: let
  # Import raw-efi from nixos-generators
  inherit (nixos-generators.nixosModules) raw-efi;
in {
  # Reuse and extend the raw-efi format
  imports = [raw-efi];
}
