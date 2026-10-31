{
  lib,
  pkgs,
  ...
}: let
  username = "rk";
  # To generate a hashed password run `mkpasswd -m scrypt`.
  # this is the hash of the password "rk3588"
  hashedPassword = "$y$j9T$V7M5HzQFBIdfNzVltUxFj/$THE5w.7V7rocWFm06Oh8eFkAKkUFb5u6HVZvXyjekK6";
in {
  nix.settings = {
    experimental-features = ["nix-command" "flakes"];
  };

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    git # used by nix flakes
    curl

    fastfetch
    lm_sensors # `sensors`
    btop # monitor system resources

    # Peripherals
    mtdutils
    i2c-tools
    minicom
  ];

  # Enable the OpenSSH daemon.
  services.openssh = {
    enable = lib.mkDefault true;
    settings = {
      X11Forwarding = lib.mkDefault true;
      PasswordAuthentication = lib.mkDefault true;
    };
    openFirewall = lib.mkDefault true;
  };

  # =========================================================================
  #      Users & Groups NixOS Configuration
  # =========================================================================

  # TODO Define a user account. Don't forget to update this!
  users.users."${username}" = {
    inherit hashedPassword;
    isNormalUser = true;
    home = "/home/${username}";
    extraGroups = ["users" "wheel"];
  };

  # Tracks the flake's nixpkgs rather than staying pinned at the release this
  # file was written for. The usual rule — never move stateVersion on a live
  # system — does not apply here: this module is reachable only through
  # `mkBoard`, so it is the floor under a freshly flashed image, and every
  # flash is a first install. Nothing stateful survives the bump.
  #
  # It is deliberately not exported via `nixosModules.<board>`; downstream
  # consumers import the board modules and set their own stateVersion.
  system.stateVersion = "26.11";
}
