# List available recipes
default:
    @just --list

# Format the tree
format:
    treefmt

alias fmt := format

# The flake's checks.treefmt output exists for CI, where a store copy
# is acceptable; day to day, lint the live tree instead.

# Lint the working tree directly (no store copy)
lint:
    treefmt --ci

# Every NixOS configuration is covered by an `eval-<name>` check that
# instantiates it without building it, so a board that no longer evaluates
# fails here in seconds rather than halfway through a multi-gigabyte image.
#
# treefmt and pre-commit-check are skipped: both copy the whole working tree
# into the store, which fails in a jj-colocated checkout (.jj is mode 600 and
# the build user cannot read it) and needlessly copies .direnv besides.
# `just lint` runs the same formatters over the live tree, and is what the
# Lint workflow runs; `nix flake check` still covers all of them.

# Run the flake's checks (evaluates every NixOS configuration)
test:
    nix-build --no-out-link -E 'builtins.removeAttrs (builtins.getAttr builtins.currentSystem (import ./. { }).checks) ["treefmt" "pre-commit-check"]'

# There is no `packages.default`: the images are board-specific and huge, so
# ATTR is required. See `nix-build -A packages` or the README for the list.

# Build package ATTR, e.g. `just build sdImage-radxa-cm5-io`
build attr:
    nix-build -A {{ attr }}

# Build every package for this system
build-all:
    nix-build -E 'builtins.getAttr builtins.currentSystem (import ./. { }).packages'

# Create a worktree at .worktrees/<issue>-<slug> on a matching branch, then prime it
worktree issue slug:
    git worktree add .worktrees/{{ issue }}-{{ slug }} -b {{ issue }}-{{ slug }}
    just init-worktree .worktrees/{{ issue }}-{{ slug }}

# Copies .env from the main worktree (gitignored, so absent in fresh
# worktrees), then direnv allow + reload. Zed runs this automatically via
# its create_worktree hook (see .zed/tasks.json).

# Prime a freshly created worktree (or any new checkout)
init-worktree dir=".":
    #!/usr/bin/env bash
    set -euo pipefail
    main="$(git worktree list --porcelain | head -1 | cut -d' ' -f2-)"
    if [ -f "$main/.env" ] && [ ! -e "{{ dir }}/.env" ]; then
      cp "$main/.env" "{{ dir }}/.env"
    fi
    cd "{{ dir }}" && direnv allow && direnv reload
