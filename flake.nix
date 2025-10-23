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

    apps.${system} = {
      update-git-deps = {
        type = "app";
        program = "${pkgs.writeShellScript "update-git-deps" ''
          set -euo pipefail

          echo "Updating git dependency hashes from Cargo.lock..."

          # Parse Cargo.lock for whisper-rs
          REV=$(${pkgs.gnugrep}/bin/grep -A2 'name = "whisper-rs"' Cargo.lock | \
                ${pkgs.gnugrep}/bin/grep -oP '#\K[a-f0-9]+' | head -1)

          if [ -z "$REV" ]; then
            echo "Error: Could not find whisper-rs in Cargo.lock"
            exit 1
          fi

          echo "Found whisper-rs rev: $REV"
          echo "Fetching hash..."

          HASH=$(${pkgs.nix-prefetch-git}/bin/nix-prefetch-git \
            https://codeberg.org/madjinn/whisper-rs.git \
            --rev "$REV" --quiet 2>/dev/null | ${pkgs.jq}/bin/jq -r .hash)

          echo "Hash: $HASH"

          # Update git-deps.nix
          cat > git-deps.nix <<EOF
          # Git dependency hashes
          # Update with: nix run .#update-git-deps
          {
            "whisper-rs" = "$HASH";
          }
          EOF

          echo "✓ Updated git-deps.nix"
        ''}";
      };

      default = self.apps.${system}.update-git-deps;
    };
  };
}
