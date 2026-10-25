{
  lib,
  pkgs,
  ...
}: {
  projectRootFile = "flake.nix";

  # alejandra, not nixfmt: this repo is a fork of ryan4yin/nixos-rk3588 and is
  # alejandra-formatted upstream, so switching formatters would conflict with
  # every merge from upstream. The pre-commit hooks run the same three Nix
  # tools (see flake.nix).
  programs = {
    alejandra.enable = true;
    deadnix.enable = true;

    statix = {
      enable = true;
      # `nix-build -A` only auto-calls a `{ ... }:` default.nix, not `_:`.
      # Mirrored in ./statix.toml, which is what the pre-commit hook reads.
      disabled-lints = ["empty_pattern"];
    };

    just.enable = true;
    shfmt.enable = true;
    yamllint.enable = true;
    actionlint.enable = true;
  };

  settings = {
    formatter.actionlint.options = [
      "-config-file"
      ".forgejo/actionlint.yaml"
    ];

    # Binary blobs and the vendored kernel config are not ours to format.
    global.excludes = [
      "pkgs/kernel/rk35xx_vendor_config"
      "*.deb"
      "*.bin"
      "*.itb"
      "*.img"
    ];

    formatter.forgejo-schema = {
      command = lib.getExe (
        pkgs.writeShellApplication {
          name = "forgejo-schema-validate";
          runtimeInputs = [pkgs.forgejo-runner];
          text = ''
            for f in "$@"; do
              case "$f" in
                */action.yaml | */action.yml)
                  forgejo-runner validate --action --path "$f" ;;
                *)
                  forgejo-runner validate --workflow --path "$f" ;;
              esac
            done
          '';
        }
      );
      includes = [
        ".forgejo/workflows/*.yaml"
        ".forgejo/workflows/*.yml"
        ".forgejo/**/action.yaml"
        ".forgejo/**/action.yml"
      ];
    };
  };
}
