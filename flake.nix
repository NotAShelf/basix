{
  description = "Base16/Base24 schemes for Nix";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs?ref=nixos-unstable";
    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };
  };

  outputs = {nixpkgs, ...}: let
    systems = ["x86_64-linux" "aarch64-linux" "aarch64-darwin"];
    forAllSystems = nixpkgs.lib.genAttrs systems;

    # FWIW this could also be lib.extend but lib.extend itself claims that
    # it should not be used, so we do this instead.
    nixpkgsLib = nixpkgs.lib;
    basixLib = import ./lib.nix {lib = nixpkgsLib;};

    schemeData = {
      base16 = basixLib.evalSchemeData ./json/base16;
      base24 = basixLib.evalSchemeData ./json/base24;
    };

    pkgsFor = forAllSystems (system: import nixpkgs {inherit system;});

    mkThemeAttrSet = pkgs: schemes: let
      mkGtkTheme = pkgs.callPackage ./packages/gtk/package.nix {inherit basixLib;};
      mkQtctTheme = pkgs.callPackage ./packages/qtct/package.nix {inherit basixLib;};
      mkKvantumTheme = pkgs.callPackage ./packages/kvantum/package.nix {inherit basixLib;};
    in
      nixpkgsLib.mapAttrs (slug: scheme:
        pkgs.symlinkJoin {
          name = "basix-theme-${basixLib.sanitizeSlug slug}";
          paths = [
            (mkGtkTheme {inherit slug scheme;})
            (mkQtctTheme {inherit slug scheme;})
            (mkKvantumTheme {inherit slug scheme;})
          ];
        })
      schemes;

    themePackages = forAllSystems (system: {
      base16 = mkThemeAttrSet pkgsFor.${system} schemeData.base16;
      base24 = mkThemeAttrSet pkgsFor.${system} schemeData.base24;
    });

    packages = forAllSystems (system: let
      pkgs = pkgsFor.${system};
      perSystemThemes = themePackages.${system};
    in {
      # Converts YAML -> JSON
      convert-scheme = pkgs.callPackage ./packages/convert-scheme/package.nix {};

      # Theme collections
      themes-base16 = pkgs.symlinkJoin {
        name = "basix-themes-base16";
        paths = nixpkgsLib.attrValues perSystemThemes.base16;
      };

      themes-base24 = pkgs.symlinkJoin {
        name = "basix-themes-base24";
        paths = nixpkgsLib.attrValues perSystemThemes.base24;
      };

      themes-all = pkgs.symlinkJoin {
        name = "basix-themes-all-${system}";
        paths = (nixpkgsLib.attrValues perSystemThemes.base16) ++ (nixpkgsLib.attrValues perSystemThemes.base24);
      };
    });
  in {
    inherit schemeData themePackages packages;
    lib = basixLib;
  };
}
