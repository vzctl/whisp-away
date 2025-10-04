{ lib
, stdenv
, fetchFromGitHub
, cmake
, vulkan-headers
, vulkan-loader
, shaderc
, openblas
, pkg-config
}:

stdenv.mkDerivation rec {
  pname = "whisper-cpp-vulkan";
  version = "1.7.3";

  src = fetchFromGitHub {
    owner = "ggerganov";
    repo = "whisper.cpp";
    rev = "v${version}";
    hash = "sha256-XbIoAHcYidoihPQlc0FOR6URB4hm0HnOColPhXp+M2c=";
  };

  nativeBuildInputs = [ cmake pkg-config ];
  
  buildInputs = [
    openblas
    vulkan-headers
    vulkan-loader
    shaderc
  ];

  cmakeFlags = [
    "-DWHISPER_BUILD_SERVER=OFF"
    "-DWHISPER_BUILD_EXAMPLES=ON"
    "-DGGML_VULKAN=ON"
    "-DWHISPER_BLAS=ON"
    "-DWHISPER_BLAS_VENDOR=OpenBLAS"
    "-DWHISPER_BUILD_TESTS=OFF"
  ];

  # Set Vulkan environment variables
  Vulkan_INCLUDE_DIR = "${vulkan-headers}/include";
  Vulkan_LIBRARY = "${vulkan-loader}/lib/libvulkan.so";

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
    
    # Install the main whisper binary with Vulkan support
    cp bin/main $out/bin/whisper-cli-vulkan
    cp bin/main $out/bin/whisper-cpp-vulkan
    # Install other useful binaries
    cp bin/quantize $out/bin/whisper-quantize-vulkan || true
    cp bin/bench $out/bin/whisper-bench-vulkan || true
    
    # Fix RPATH for libraries
    for lib in $out/lib/*.so*; do
      if [ -f "$lib" ]; then
        patchelf --set-rpath "$out/lib:${lib.makeLibraryPath [ vulkan-loader openblas stdenv.cc.cc.lib ]}" "$lib" || true
      fi
    done
    
    # Fix RPATH for binaries
    for bin in $out/bin/*; do
      if [ -f "$bin" ]; then
        patchelf --set-rpath "$out/lib:${lib.makeLibraryPath [ vulkan-loader openblas stdenv.cc.cc.lib ]}" "$bin" || true
        chmod 755 "$bin"
      fi
    done
  '';

  meta = with lib; {
    description = "Whisper.cpp with Vulkan GPU acceleration";
    homepage = "https://github.com/ggerganov/whisper.cpp";
    license = licenses.mit;
    platforms = platforms.linux;
  };
}