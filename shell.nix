{ pkgs ? import <nixpkgs> {} }:

# Dev shell for working on bashunit itself. Intended to satisfy the full
# quality gate under `nix-shell --pure`:
#
#   nix-shell --pure --run "./bashunit --simple --parallel"
#   nix-shell --pure --run "make sa && make lint"
#
# coreutils, gnugrep, gawk, gnused, findutils and gnumake already arrive with
# mkShell's stdenv, so they are deliberately not repeated here.
#
# To use bashunit rather than develop it, no dev shell is needed:
#   nix-shell -p bashunit --run "bashunit tests/"

pkgs.mkShell {
  buildInputs = [
    pkgs.bashInteractive
    pkgs.git
    pkgs.curl
    # Clock source on Bash < 5, which has no EPOCHREALTIME
    pkgs.perl
    # tput, for terminal width detection; without it every run falls back to
    # the 80 columns the acceptance snapshots assume
    pkgs.ncurses
    # make sa
    pkgs.shellcheck
    # make lint, the formatting authority
    pkgs.editorconfig-checker
  ];
}
