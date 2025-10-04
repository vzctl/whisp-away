{
  description = "WhispAway flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    crane = {
      url = "github:ipetkov/crane";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, crane, ... }@inputs:
  let
    system = "x86_64-linux";
    pkgs = nixpkgs.legacyPackages.${system};
    craneLib = crane.mkLib pkgs;
  in
  {
    packages.${system} = rec {
      # Standard nixpkgs-compatible build (for potential upstream contribution)
      whisp-away-package = pkgs.callPackage ./build.nix {
        inherit (pkgs) rustPlatform;
        useCrane = false;
        accelerationType = "vulkan";
      };
      
      # Crane-based build with better caching for development
      whisp-away = pkgs.callPackage ./build.nix {
        inherit craneLib;
        useCrane = true;
        accelerationType = "vulkan";
      };
      
      # Variants with different acceleration (using crane for development)
      whisp-away-cpu = pkgs.callPackage ./build.nix {
        inherit craneLib;
        useCrane = true;
        accelerationType = "cpu";
      };
      
      whisp-away-cuda = pkgs.callPackage ./build.nix {
        inherit craneLib;
        useCrane = true;
        accelerationType = "cuda";
      };
      
      whisp-away-openvino = pkgs.callPackage ./build.nix {
        inherit craneLib;
        useCrane = true;
        accelerationType = "openvino";
      };
      
      default = whisp-away;
    };
    
    nixosModules = {
      # Basic modules (will use rustPlatform)
      home-manager = ./packaging/nixos/home-manager.nix;
      nixos = ./packaging/nixos/nixos.nix;
      
      # Pre-configured modules with crane support
      # These can be used directly: imports = [ whisp-away.nixosModules.home-manager-with-crane ];
      home-manager-with-crane = { config, lib, pkgs, ... }: {
        imports = [ ./packaging/nixos/home-manager.nix ];
        _module.args.craneLib = craneLib;
      };
      
      nixos-with-crane = { config, lib, pkgs, ... }: {
        imports = [ ./packaging/nixos/nixos.nix ];
        _module.args.craneLib = craneLib;
      };
    };
    
    # Example configurations can be added here if needed
    # nixosConfigurations = { };
  };
}
