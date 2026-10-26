{
  description = "A minimal NixOS configuration for the RK3588/RK3588S based SBCs";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };

    # Lets `nix-build` / `nix-shell` use the pinned inputs without flake
    # commands copying the whole source tree to the store. See ./default.nix.
    flake-compat = {
      url = "git+https://git.lix.systems/lix-project/flake-compat";
      flake = false;
    };

    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Kept for compatibility with the existing pre-commit workflow. treefmt
    # (see ./treefmt.nix and `just lint`) runs the same Nix tools and is what
    # CI checks; this only backs the git hook.
    pre-commit-hooks = {
      url = "github:cachix/pre-commit-hooks.nix";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-compat.follows = "";
      };
    };
  };

  outputs = inputs @ {
    self,
    nixpkgs,
    flake-parts,
    nixos-generators,
    ...
  }: let
    inherit (nixpkgs) lib;

    # Local system's architecture, the host you are running this flake on.
    localSystem = "x86_64-linux";
    # The native system of the target SBC.
    aarch64System = "aarch64-linux";
    pkgsNative = import nixpkgs {system = aarch64System;};

    # Cross-compilation toolchain for building on the local system.
    pkgsCross = import nixpkgs {
      inherit localSystem;
      crossSystem = aarch64System;
    };

    vendorKernel = pkgs: pkgs.callPackage ./pkgs/kernel/vendor.nix {};
    mainlineKernel = pkgs: pkgs.callPackage ./pkgs/kernel/mainline.nix {};

    # Boards with an upstream device tree, and so a usable mainline kernel.
    # Checked against arch/arm64/boot/dts/rockchip in Linux v7.2, which is
    # what pkgs/kernel/mainline.nix is pinned to (see the note there):
    #
    #   orangepi5        rk3588s-orangepi-5.dts
    #   orangepi5b       rk3588s-orangepi-5b.dts
    #   orangepi5plus    rk3588-orangepi-5-plus.dts
    #   rock5a           rk3588s-rock-5a.dts
    #
    # Each matches the DTB name its board module already sets, so the mainline
    # variants need no device-tree override.
    #
    # orangepi5pro is absent only because of the pin: rk3588s-orangepi-5-pro.dts
    # landed in 7.3. Add it when mainline.nix moves past 7.2.
    #
    # radxa-cm5-io is absent for a different reason. Mainline does carry
    # rk3588s-radxa-cm5-io, but the board module uses Armbian's
    # rk3588s-radxa-cm5-rpi-cm4-io, which names a different carrier. Enabling
    # it needs a device-tree override and confirmation that the two describe
    # the same hardware - relevant here, where the CM5 sits on a Compute Blade.
    #
    # radxa-cm5-io-lite (RK3582) has no mainline device tree at all; mainline
    # carries rk3582-radxa-e52c, a different board.
    #
    # Feature-level status per SoC and board:
    #   https://gitlab.collabora.com/hardware-enablement/rockchip-3588/notes-for-rockchip-3588/-/blob/main/mainline-status.md
    mainlineBoards = [
      "orangepi5"
      "orangepi5b"
      "orangepi5plus"
      "rock5a"
    ];

    # Abbreviations used in package attribute names.
    boardShortNames = {
      orangepi5 = "opi5";
      orangepi5b = "opi5b";
      orangepi5plus = "opi5plus";
      orangepi5pro = "opi5pro";
      rock5a = "rock5a";
      radxa-cm5-io = "radxa-cm5-io";
      radxa-cm5-io-lite = "radxa-cm5-io-lite";
    };

    boardsWithMainline = lib.filterAttrs (name: _: lib.elem name mainlineBoards);

    # Every supported board: its hardware module, and the sd-image module that
    # pairs with it. This table drives nixosConfigurations and packages; to add
    # a board, add it here and everything else follows.
    #
    # It is a table of module *pairs*, not a module, so it cannot live under
    # flake.nixosModules (flake-parts types those as deferred modules). The
    # pair is published flat instead, as `nixosModules.<board>` and
    # `nixosModules.<board>-sd-image`.
    boards = {
      # Orange Pi 5 SBC
      orangepi5 = {
        core = import ./modules/boards/orangepi5.nix;
        sd-image = ./modules/sd-image/orangepi5.nix;
      };
      # Orange Pi 5b SBC
      orangepi5b = {
        core = import ./modules/boards/orangepi5b.nix;
        sd-image = ./modules/sd-image/orangepi5b.nix;
      };
      # Orange Pi 5 Plus SBC
      orangepi5plus = {
        core = import ./modules/boards/orangepi5plus.nix;
        sd-image = ./modules/sd-image/orangepi5plus.nix;
      };
      # Orange Pi 5 Pro SBC
      orangepi5pro = {
        core = import ./modules/boards/orangepi5pro.nix;
        sd-image = ./modules/sd-image/orangepi5pro.nix;
      };
      # Rock 5 Model A SBC
      rock5a = {
        core = import ./modules/boards/rock5a.nix;
        sd-image = ./modules/sd-image/rock5a.nix;
      };
      # Radxa CM5 on CM5 IO Board
      radxa-cm5-io = {
        core = import ./modules/boards/radxa-cm5-io.nix;
        sd-image = ./modules/sd-image/radxa-cm5-io.nix;
      };
      # Radxa CM5 Lite (RK3582) on CM5 IO Board
      radxa-cm5-io-lite = {
        core = import ./modules/boards/radxa-cm5-io-lite.nix;
        sd-image = ./modules/sd-image/radxa-cm5-io-lite.nix;
      };
    };

    # One board's NixOS system. The four families below differ only in which
    # kernel they build, which platform they build on, and which extra modules
    # they stack on top of the board's own.
    mkBoard = {
      name,
      board,
      system ? aarch64System,
      pkgsKernel ? pkgsNative,
      kernelPackage ? vendorKernel pkgsKernel,
      extraSpecialArgs ? {},
      modules ? [],
    }:
      lib.nixosSystem {
        inherit system;

        specialArgs =
          {
            rk3588 = {
              inherit nixpkgs pkgsKernel kernelPackage;
            };
          }
          // extraSpecialArgs;

        modules =
          [
            ./modules/configuration.nix
            board.core
            {networking.hostName = name;}
          ]
          ++ modules;
      };

    # Derive one package per board from a family of configurations, e.g.
    # `sdImage-opi5-cross` from `nixosConfigurations.orangepi5-cross`.
    boardPackages = {
      prefix,
      configSuffix ? "",
      nameSuffix ? configSuffix,
      boardSet ? boards,
      output,
    }:
      lib.mapAttrs' (
        name: _:
          lib.nameValuePair
          "${prefix}-${boardShortNames.${name}}${nameSuffix}"
          (output self.nixosConfigurations."${name}${configSuffix}")
      )
      boardSet;

    sdImageOf = config: config.config.system.build.sdImage;
    rawEfiImageOf = config: config.config.formats.rk3588-raw-efi;

    # What a configuration is actually for. A `-uefi` configuration's bare
    # system.build.toplevel does not evaluate on its own — nixos-generators
    # contributes the root filesystem and bootloader settings as part of
    # building the format — so check the image each family really produces.
    imageOf = name: config:
      if lib.hasSuffix "-uefi" name
      then rawEfiImageOf config
      else sdImageOf config;

    # Instantiate a derivation without building it. An image takes hours and
    # tens of gigabytes to build, but evaluating it takes seconds and catches
    # the mistakes that matter most here: a board module that no longer
    # evaluates, or a configuration that does not exist at all.
    evalCheck = pkgs: name: drvs:
      pkgs.writeText "eval-${name}" (
        lib.concatMapStringsSep "\n" (
          drv: builtins.unsafeDiscardOutputDependency drv.drvPath
        )
        drvs
      );
  in
    flake-parts.lib.mkFlake {inherit inputs;} {
      imports = [inputs.treefmt-nix.flakeModule];

      systems = [
        "aarch64-darwin"
        "aarch64-linux"
        "x86_64-darwin"
        "x86_64-linux"
      ];

      flake = {
        # Each board contributes two modules: `<board>` (the hardware module)
        # and `<board>-sd-image` (the image definition that goes with it).
        nixosModules =
          (lib.mapAttrs (_name: board: board.core) boards)
          // (lib.mapAttrs' (
              name: board:
                lib.nameValuePair "${name}-sd-image" board.sd-image
            )
            boards)
          // {
            # SPI TPM (Infineon SLB9670/SLB9672) on the Compute Blade CM4 carrier board
            compute-blade-tpm = import ./modules/hardware/compute-blade-tpm.nix;

            formats = {...}: {
              imports = [
                nixos-generators.nixosModules.all-formats
              ];

              nixpkgs.hostPlatform = aarch64System;
              formatConfigs.rk3588-raw-efi = import ./modules/rk3588-raw-efi.nix;
            };
          };

        nixosConfigurations =
          # sdImage - vendor kernel - boot via U-Boot - fully native
          (lib.mapAttrs (
              name: board:
                mkBoard {
                  inherit name board;
                  modules = [
                    board.sd-image
                    {image.baseName = "${name}-sd-image";}
                  ];
                }
            )
            boards)
          # sdImage - mainline kernel - boot via U-Boot - fully native
          // (lib.mapAttrs' (
              name: board:
                lib.nameValuePair "${name}-mainline" (mkBoard {
                  inherit name board;
                  kernelPackage = mainlineKernel pkgsNative;
                  modules = [
                    board.sd-image
                    {image.baseName = "${name}-mainline-sd-image";}
                  ];
                })
            )
            (boardsWithMainline boards))
          # sdImage - vendor kernel - boot via U-Boot - fully cross-compiled
          // (lib.mapAttrs' (
              name: board:
                lib.nameValuePair "${name}-cross" (mkBoard {
                  inherit name board;
                  system = localSystem; # x64
                  pkgsKernel = pkgsCross;
                  modules = [
                    board.sd-image
                    {
                      image.baseName = "${name}-sd-image";

                      # Use the cross-compilation toolchain to build the whole system.
                      nixpkgs.crossSystem.config = "aarch64-unknown-linux-gnu";
                    }
                  ];
                })
            )
            boards)
          # UEFI system, boot via edk2-rk3588 - fully native
          // (lib.mapAttrs' (
              name: board:
                lib.nameValuePair "${name}-uefi" (mkBoard {
                  inherit name board;
                  extraSpecialArgs = {inherit nixos-generators;};
                  modules = [self.nixosModules.formats];
                })
            )
            boards);
      };

      perSystem = {
        config,
        pkgs,
        system,
        ...
      }: {
        treefmt = ./treefmt.nix;

        # The images are aarch64-linux artefacts. The native ones are built on
        # the SBC's own architecture; the `-cross` ones can only be built on
        # x86_64-linux, because that is the localSystem their toolchain is
        # pinned to. Other systems get no packages at all, so that the devShell
        # still works on a darwin workstation.
        packages =
          lib.optionalAttrs (system == aarch64System) (
            (boardPackages {
              prefix = "sdImage";
              output = sdImageOf;
            })
            // (boardPackages {
              prefix = "sdImage";
              configSuffix = "-mainline";
              boardSet = boardsWithMainline boards;
              output = sdImageOf;
            })
            // (boardPackages {
              prefix = "rawEfiImage";
              configSuffix = "-uefi";
              nameSuffix = "";
              output = rawEfiImageOf;
            })
            // (let
              rkbin-rk3588 = pkgs.callPackage ./pkgs/rkbin-rk3588 {};
            in {
              inherit rkbin-rk3588;

              uboot-radxa-cm5-io = pkgs.callPackage ./pkgs/u-boot-radxa-cm5-io/build-from-source.nix {
                inherit rkbin-rk3588;
              };

              kernel-vendor = vendorKernel pkgsNative;
              kernel-mainline = mainlineKernel pkgsNative;
            })
          )
          // lib.optionalAttrs (system == localSystem) (
            (boardPackages {
              prefix = "sdImage";
              configSuffix = "-cross";
              output = sdImageOf;
            })
            // {
              kernel-vendor-cross = vendorKernel pkgsCross;
              kernel-mainline-cross = mainlineKernel pkgsCross;
            }
          );

        # `just test` builds these: one evaluation check per NixOS
        # configuration, one covering every package of this system, plus the
        # treefmt check contributed by treefmt-nix.
        checks =
          (lib.mapAttrs' (
              name: nixosConfig:
                lib.nameValuePair "eval-${name}" (
                  evalCheck pkgs name [(imageOf name nixosConfig)]
                )
            )
            self.nixosConfigurations)
          // {
            # Evaluation does not depend on the host, so check the packages of
            # both build platforms everywhere — including from a darwin
            # workstation, which builds none of them itself.
            eval-packages = evalCheck pkgs "packages" (
              lib.concatMap (s: lib.attrValues self.packages.${s}) [
                aarch64System
                localSystem
              ]
            );

            pre-commit-check = inputs.pre-commit-hooks.lib.${system}.run {
              src = ./.;
              hooks = {
                # nix
                deadnix.enable = true;
                alejandra.enable = true;
                statix.enable = true;
              };
            };
          };

        devShells =
          {
            default = pkgs.mkShell {
              inherit (config.checks.pre-commit-check) shellHook;

              packages = [
                pkgs.just
                config.treefmt.build.wrapper
              ];
            };
          }
          // lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
            fhsEnv =
              # the code here is mainly copied from:
              #   https://nixos.wiki/wiki/Linux_kernel#Embedded_Linux_Cross-compile_xconfig_and_menuconfig
              (pkgs.buildFHSUserEnv {
                name = "kernel-build-env";
                targetPkgs = pkgs_: (
                  with pkgs_;
                    [
                      # we need theses packages to make `make menuconfig` work.
                      pkg-config
                      ncurses
                      # arm64 cross-compilation toolchain
                      pkgsCross.gccStdenv.cc
                      # native gcc
                      gcc
                    ]
                    ++ pkgs.linux.nativeBuildInputs
                );
                runScript = pkgs.writeScript "init.sh" ''
                  # set the cross-compilation environment variables.
                  export CROSS_COMPILE=aarch64-unknown-linux-gnu-
                  export ARCH=arm64
                  export PKG_CONFIG_PATH="${pkgs.ncurses.dev}/lib/pkgconfig:"
                  exec bash
                '';
              })
              .env;
          };
      };
    };
}
