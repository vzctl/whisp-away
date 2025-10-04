{ config, lib, pkgs, ... }:

let
  # NVIDIA Persistenced Build Fix (September 2025)
  # =============================================
  # The nvidia-persistenced daemon fails to build due to missing RPC headers.
  # The build requires rpc/rpc.h from libtirpc, but even with proper dependencies,
  # the Makefile doesn't respect NIX build flags properly.
  # 
  # Solution: Replace with a dummy script since persistenced is not essential.
  # The daemon only keeps the driver loaded in memory to avoid initialization delays.
  # GPU functionality (including CUDA and ComfyUI) works fine without it.
  #
  # Original error: nvpd_rpc.h:9:10: fatal error: rpc/rpc.h: No such file or directory
  dummyPersistenced = pkgs.writeShellScriptBin "nvidia-persistenced" ''
    # Dummy nvidia-persistenced - not required for GPU functionality
    # The real daemon just maintains driver state in memory
    exit 0
  '';
in
{
  # Accept NVIDIA license for legacy drivers  
  nixpkgs.config.nvidia.acceptLicense = true;
  
  # Use production driver but with dummy persistenced
  hardware.nvidia.package = lib.mkForce (
    config.boot.kernelPackages.nvidiaPackages.production.overrideAttrs (old: {
      passthru = (old.passthru or {}) // {
        persistenced = dummyPersistenced;
      };
    })
  );
  
  # Enable Graphics (formerly OpenGL)
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    
    # Enable CUDA support
    extraPackages = with pkgs; [
      nvidia-vaapi-driver
      vaapiVdpau
      libvdpau-va-gl
    ];
  };

  # Load NVIDIA driver for Xorg and Wayland
  services.xserver.videoDrivers = [ "nvidia" ];

  # NVIDIA driver configuration
  hardware.nvidia = {
    # Modesetting is required for most Wayland compositors
    modesetting.enable = true;

    # Disable open source kernel module to avoid nvidia-persistenced issues
    # The proprietary driver is more stable
    open = false;

    # Enable the nvidia settings menu
    nvidiaSettings = true;
    
    # Disable forceFullCompositionPipeline to avoid nvidia-persistenced
    forceFullCompositionPipeline = false;

    # package is set above with the fixed persistenced

    # Disable power management to avoid nvidia-persistenced dependency
    powerManagement.enable = false;
    
    # Disable fine-grained power management to avoid nvidia-persistenced
    powerManagement.finegrained = false;
    
    # Explicitly disable nvidia-persistenced daemon to avoid RPC build issues
    # This daemon is not essential for GPU functionality
    nvidiaPersistenced = false;

    # Disable Dynamic Boost - causes nvidia-powerd to fail with "Allocate client failed 106"
    # Not essential for GPU functionality
    dynamicBoost.enable = false;

    # Prime configuration for laptop with both integrated and discrete GPU
    prime = {
      # Enable PRIME synchronization for better performance
      sync.enable = false;  # Set to true if you want to always use NVIDIA
      
      # Or use offload mode to save battery (GPU only activates when needed)
      offload = {
        enable = true;
        enableOffloadCmd = true;  # Adds nvidia-offload command
      };

      # Bus IDs for your GPUs (need to match your hardware)
      # AMD integrated GPU
      amdgpuBusId = "PCI:5:0:0";  # Based on 05:00.0 from lspci
      
      # NVIDIA discrete GPU  
      nvidiaBusId = "PCI:1:0:0";  # Based on 01:00.0 from lspci
    };
  };

  # CUDA support for development and AI workloads
  environment.systemPackages = with pkgs; [
    # Use cudaPackages_12 which is compatible with newer drivers
    cudaPackages_12.cudatoolkit
    cudaPackages_12.cudnn
    
    # Utilities
    nvtopPackages.nvidia  # GPU monitoring tool
    nvidia-container-toolkit  # For Docker/Kubernetes GPU support
  ];

  # Enable NVIDIA container runtime for Kubernetes
  virtualisation.docker = {
    enableNvidia = true;
  };

  # Enable NVIDIA support in containerd for Kubernetes
  virtualisation.containerd = {
    settings = {
      plugins."io.containerd.grpc.v1.cri".containerd = {
        # Don't override the default runtime, just add nvidia as an option  
        runtimes.nvidia = {
          runtime_type = "io.containerd.runc.v2";
          options = {
            BinaryName = "${pkgs.runc}/bin/runc";
          };
        };
      };
    };
  };

  # Completely disable nvidia-persistenced service to avoid build issues
  systemd.services.nvidia-persistenced = {
    enable = false;
    wantedBy = lib.mkForce [];
  };

}