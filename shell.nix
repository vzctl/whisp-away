{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  buildInputs = with pkgs; [
    # Build tools
    gcc
    cmake
    pkg-config
    gnumake
    
    # Rust
    rustc
    cargo
    
    # Dependencies for whisper-rs
    libclang
    clang
    
    # Dependencies for the app
    dbus.dev
    
    # Optional: for GPU support
    vulkan-headers
    vulkan-loader
    
    # Optional: for OpenVINO
    openvino
    tbb
  ];
  
  shellHook = ''
    echo "Development shell for whisp-away"
    
    # Find whisper-cpp-openvino in the Nix store (prefer 1.7.6)
    WHISPER_CPP=$(ls -d /nix/store/*-whisper-cpp-openvino-1.7.6/lib 2>/dev/null | head -n 1 | xargs dirname)
    if [ -z "$WHISPER_CPP" ]; then
      WHISPER_CPP=$(ls -d /nix/store/*-whisper-cpp-openvino-*/lib 2>/dev/null | head -n 1 | xargs dirname)
    fi
    
    if [ -n "$WHISPER_CPP" ]; then
      echo "Found whisper-cpp-openvino at: $WHISPER_CPP"
      export WHISPER_CPP_LIB_DIR="$WHISPER_CPP/lib"
      export WHISPER_CPP_INCLUDE_DIR="$WHISPER_CPP/include"
      
      # Find OpenVINO in the Nix store
      OPENVINO_PATH=$(ls -d /nix/store/*-openvino-*/runtime 2>/dev/null | head -n 1)
      if [ -n "$OPENVINO_PATH" ]; then
        export OPENVINO_LIB_DIR="$OPENVINO_PATH/lib/intel64"
        export OpenVINO_DIR="$OPENVINO_PATH/cmake"
        echo "Found OpenVINO at: $OPENVINO_PATH"
      fi
      
      # Set library paths for runtime
      export LD_LIBRARY_PATH="$WHISPER_CPP_LIB_DIR:$OPENVINO_LIB_DIR:$LD_LIBRARY_PATH"
      
      echo ""
      echo "Environment configured with OpenVINO support:"
      echo "  WHISPER_CPP_LIB_DIR=$WHISPER_CPP_LIB_DIR"
      echo "  OPENVINO_LIB_DIR=$OPENVINO_LIB_DIR"
    else
      echo "Warning: Could not find whisper-cpp-openvino in /nix/store"
      echo "You may need to build it first with:"
      echo "  cd ~/dev/whisp-away && nix-build -E 'with import <nixpkgs> {}; callPackage ./packaging/nixos/whisper-cpp-openvino.nix {}'"
      echo ""
      echo "Then re-enter the shell with: nix-shell"
    fi
    
    echo ""
    echo "Run 'cargo build --release' to build"
  '';
  
  LIBCLANG_PATH = "${pkgs.libclang.lib}/lib";
  PKG_CONFIG_PATH = "${pkgs.dbus.dev}/lib/pkgconfig";
}