{ lib
, stdenv
, fetchFromGitHub
, cmake
, openvino
, tbb
, pkg-config
}:

stdenv.mkDerivation rec {
  pname = "whisper-cpp-openvino";
  version = "1.7.3";

  src = fetchFromGitHub {
    owner = "ggerganov";
    repo = "whisper.cpp";
    rev = "v${version}";
    hash = "sha256-XbIoAHcYidoihPQlc0FOR6URB4hm0HnOColPhXp+M2c=";
  };

  nativeBuildInputs = [ 
    cmake 
    pkg-config
  ];
  
  buildInputs = [ 
    openvino
    tbb
  ];

  # Simple, clean CMake configuration based on official docs
  cmakeFlags = [
    "-DWHISPER_OPENVINO=1"
    "-DWHISPER_BUILD_TESTS=OFF"
    "-DWHISPER_BUILD_EXAMPLES=ON"
  ];

  # Set OpenVINO environment for CMake
  preConfigure = ''
    # Export OpenVINO paths for CMake to find
    export OpenVINO_DIR="${openvino}/runtime/cmake"
    export InferenceEngine_DIR="${openvino}/runtime/cmake"
    export TBB_DIR="${tbb}/lib/cmake/tbb"
    
    # Source setupvars equivalent
    export INTEL_OPENVINO_DIR="${openvino}"
    export CMAKE_PREFIX_PATH="${openvino}/runtime/cmake:$CMAKE_PREFIX_PATH"
    
    echo "Building whisper.cpp with OpenVINO support..."
    echo "OpenVINO_DIR: $OpenVINO_DIR"
  '';

  # Fix library linking
  postFixup = ''
    # Ensure directories exist
    mkdir -p $out/bin $out/include
    
    # Install headers (needed for whisper-rs)
    cp -r include/* $out/include/ || true
    cp -r ggml/include/* $out/include/ || true
    
    # The main binary should be installed by CMake as 'main'
    if [ -f "$out/bin/main" ]; then
      mv $out/bin/main $out/bin/whisper-cli-openvino
    elif [ -f "bin/main" ]; then
      cp bin/main $out/bin/whisper-cli-openvino
    else
      echo "Error: Could not find main binary!"
      ls -la bin/ || true
      ls -la $out/bin/ || true
      exit 1
    fi
    
    # Create symlinks for convenience only if the main binary exists
    if [ -f "$out/bin/whisper-cli-openvino" ]; then
      ln -sf whisper-cli-openvino $out/bin/whisper-cpp-openvino
      ln -sf whisper-cli-openvino $out/bin/whisper-openvino
    fi
    
    # CRITICAL: Fix RPATH for libraries FIRST (they need OpenVINO runtime path)
    for lib in $out/lib/*.so* $out/lib/*.so; do
      if [ -f "$lib" ]; then
        echo "Patching RPATH for library: $lib"
        patchelf --set-rpath "$out/lib:${lib.makeLibraryPath [ 
          openvino 
          tbb 
          stdenv.cc.cc.lib 
        ]}:${openvino}/runtime/lib/intel64" "$lib" || true
      fi
    done
    
    # Fix RPATH for binaries
    for bin in $out/bin/*; do
      if [ -f "$bin" ] && [ ! -L "$bin" ]; then
        echo "Patching RPATH for binary: $bin"
        patchelf --set-rpath "$out/lib:${lib.makeLibraryPath [ 
          openvino 
          tbb 
          stdenv.cc.cc.lib 
        ]}:${openvino}/runtime/lib/intel64" "$bin" || true
      fi
    done
    
    # Create wrapper script that sets OpenVINO environment
    for bin in whisper-cli-openvino whisper-cpp-openvino whisper-openvino; do
      if [ -f "$out/bin/$bin" ]; then
        mv "$out/bin/$bin" "$out/bin/.$bin-unwrapped"
        cat > "$out/bin/$bin" <<EOF
#!/bin/sh
export LD_LIBRARY_PATH="${openvino}/runtime/lib/intel64:${tbb}/lib:\$LD_LIBRARY_PATH"
exec "$out/bin/.$bin-unwrapped" "\$@"
EOF
        chmod +x "$out/bin/$bin"
      fi
    done
    
    # Test if the binary works
    echo "Testing whisper-cli-openvino binary..."
    $out/bin/whisper-cli-openvino --help 2>&1 | grep -q "ov-e-device" && \
      echo "✓ OpenVINO support confirmed" || \
      echo "⚠ Warning: OpenVINO flags not found"
  '';

  # Don't strip to preserve symbols
  dontStrip = true;

  meta = with lib; {
    description = "Whisper.cpp with OpenVINO acceleration for Intel GPUs";
    homepage = "https://github.com/ggerganov/whisper.cpp";
    license = licenses.mit;
    platforms = platforms.linux;
  };
}