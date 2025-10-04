{ lib
, stdenv
, fetchFromGitHub
, cmake
, openblas
, pkg-config
}:

stdenv.mkDerivation rec {
  pname = "whisper-cpp-cpu-only";
  version = "1.7.3";

  src = fetchFromGitHub {
    owner = "ggerganov";
    repo = "whisper.cpp";
    rev = "v${version}";
    hash = "sha256-XbIoAHcYidoihPQlc0FOR6URB4hm0HnOColPhXp+M2c=";
  };

  nativeBuildInputs = [ cmake pkg-config ];
  
  buildInputs = [ openblas ];

  # Enable CPU optimizations only (no GPU acceleration)
  cmakeFlags = [
    "-DWHISPER_BUILD_SERVER=OFF"
    "-DWHISPER_BUILD_EXAMPLES=ON"
    "-DWHISPER_BUILD_TESTS=OFF"
    
    # Disable all GPU acceleration
    "-DWHISPER_OPENVINO=OFF"
    "-DGGML_VULKAN=OFF"
    "-DGGML_CUDA=OFF"
    
    # CPU optimizations
    "-DWHISPER_AVX=ON"
    "-DWHISPER_AVX2=ON"
    "-DWHISPER_FMA=ON"
    "-DWHISPER_F16C=ON"
    "-DGGML_AVX=ON"
    "-DGGML_AVX2=ON"
    "-DGGML_FMA=ON"
    "-DGGML_F16C=ON"
    
    # Use OpenBLAS for matrix operations
    "-DWHISPER_BLAS=ON"
    "-DWHISPER_BLAS_VENDOR=OpenBLAS"
    
    # Native arch optimizations
    "-DGGML_NATIVE=ON"
    "-DCMAKE_C_FLAGS=-march=native"
    "-DCMAKE_CXX_FLAGS=-march=native"
  ];

  postInstall = ''
    # Create directories
    mkdir -p $out/lib $out/bin $out/include
    
    # Install headers (needed for whisper-rs)
    cp -r ../include/* $out/include/ || true
    cp -r ../ggml/include/* $out/include/ || true
    
    # Install libraries
    cp libwhisper.so* $out/lib/ || true
    cp libggml*.so* $out/lib/ || true
    cp libwhisper.a $out/lib/ || true
    cp libggml*.a $out/lib/ || true
    
    # Install the main whisper binary with CPU optimizations
    cp bin/main $out/bin/whisper-cli-cpu
    cp bin/main $out/bin/whisper-cpp-cpu
    
    # Install other useful binaries
    cp bin/quantize $out/bin/whisper-quantize-cpu || true
    cp bin/bench $out/bin/whisper-bench-cpu || true
    
    # Fix RPATH 
    for lib in $out/lib/*.so*; do
      if [ -f "$lib" ]; then
        patchelf --set-rpath "$out/lib:${lib.makeLibraryPath [ openblas stdenv.cc.cc.lib ]}" "$lib" || true
      fi
    done
    
    for bin in $out/bin/*; do
      if [ -f "$bin" ]; then
        patchelf --set-rpath "$out/lib:${lib.makeLibraryPath [ openblas stdenv.cc.cc.lib ]}" "$bin" || true
        chmod 755 "$bin"
      fi
    done
  '';

  meta = with lib; {
    description = "Whisper.cpp with CPU-only optimizations (AVX2, FMA, OpenBLAS)";
    homepage = "https://github.com/ggerganov/whisper.cpp";
    license = licenses.mit;
    platforms = platforms.linux;
  };
}