{ config, lib, pkgs, ... }:

{
  # Enable Graphics (formerly OpenGL)
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    
    # Intel GPU packages for Arc graphics and OpenVINO support
    extraPackages = with pkgs; [
      intel-media-driver  # VAAPI driver for Intel GPUs (Broadwell+ including Arc)
      intel-vaapi-driver  # Legacy VAAPI driver (for older Intel GPUs) 
      vaapiVdpau
      libvdpau-va-gl
      intel-compute-runtime  # OpenCL runtime for Intel GPUs (required for OpenVINO GPU support)
      level-zero  # Intel GPU compute runtime interface
      intel-graphics-compiler  # Intel Graphics Compiler for OpenCL
    ];
    
    extraPackages32 = with pkgs.pkgsi686Linux; [
      intel-media-driver
      intel-vaapi-driver
    ];
  };

  # Environment variables for Intel GPU
  environment.variables = {
    # Use Intel media driver for VAAPI
    LIBVA_DRIVER_NAME = "iHD";
    # Enable Intel GPU for OpenVINO
    OCL_ICD_VENDORS = "${pkgs.intel-compute-runtime}/etc/OpenCL/vendors";
  };

  # System packages for Intel GPU utilities
  environment.systemPackages = with pkgs; [
    intel-gpu-tools  # Intel GPU debugging tools
    libva-utils  # VAAPI info and test utilities
    clinfo  # OpenCL information utility
  ];

  # Enable firmware updates for Intel hardware
  services.fwupd.enable = true;
  
  # Kernel modules for Intel GPU
  boot.kernelModules = [
    "i915"  # Intel graphics driver
  ];
}