{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  buildInputs = [
    pkgs.bashInteractive
    pkgs.git
    pkgs.curl
    pkgs.perl
  ];
}
