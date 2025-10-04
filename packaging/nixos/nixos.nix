{ config, lib, pkgs, craneLib ? null, ... }:

with lib;

let
  cfg = config.services.whisp-away;
  
  # Automatically detect if we should use crane based on its availability
  effectiveUseCrane = cfg.useCrane && craneLib != null;
  
  whisp-away = pkgs.callPackage ../../build.nix {
    inherit (cfg) accelerationType;
    inherit (pkgs) rustPlatform;
    inherit craneLib;
    useCrane = effectiveUseCrane;
  };
  
in {
  options.services.whisp-away = {
    enable = mkEnableOption "voice input tools with Whisper speech recognition";
    
    defaultBackend = mkOption {
      type = types.enum [ "faster-whisper" "whisper-cpp" ];
      default = "whisper-cpp";
      description = ''
        Default backend for the tray to manage:
        - faster-whisper: Python-based with GPU support via CTranslate2
        - whisper-cpp: C++ implementation with various acceleration options
        Note: The tray UI allows switching between backends at runtime.
      '';
    };
    
    defaultModel = mkOption {
      type = types.str;
      default = "base.en";
      description = ''
        Default Whisper model. Can be overridden per-command or via WA_WHISPER_MODEL env var.
        Common options:
        - tiny.en: Fastest, least accurate (~39 MB)
        - base.en: Fast, reasonable accuracy (~74 MB)
        - small.en: Good balance (~244 MB)
        - medium.en: Better accuracy (~769 MB)
        - large-v3: Best accuracy (~1550 MB)
      '';
    };
    
    accelerationType = mkOption {
      type = types.enum [ "openvino" "vulkan" "cpu" "cuda" ];
      default = "vulkan";
      description = ''
        Type of acceleration to use for whisper.cpp:
        - openvino: Intel GPU/CPU acceleration via OpenVINO
        - cuda: NVIDIA GPU acceleration via CUDA
        - vulkan: GPU acceleration via Vulkan API
        - cpu: CPU-only (no GPU acceleration)
      '';
    };
    
    useCrane = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Use crane build system for better dependency caching during development.
        Will automatically fall back to rustPlatform if crane is not available.
        Set to false to force rustPlatform usage even when crane is available.
      '';
    };
  };
  
  config = mkIf cfg.enable {
    # System-wide package installation
    environment.systemPackages = [ whisp-away ];
    
    # Environment variables
    environment.sessionVariables = {
      WA_WHISPER_MODEL = cfg.defaultModel;
      WA_WHISPER_BACKEND = cfg.defaultBackend;
      WA_WHISPER_SOCKET = "/tmp/whisp-away-daemon.sock";
    } // optionalAttrs (cfg.accelerationType == "cuda") {
      CUDA_VISIBLE_DEVICES = "0";
      LD_LIBRARY_PATH = "${pkgs.cudaPackages.cudatoolkit}/lib:${pkgs.cudaPackages.cudnn}/lib:\${LD_LIBRARY_PATH}";
    };
    
    # Create cache directories using systemd tmpfiles
    systemd.user.tmpfiles.rules = [
      "d %h/.cache/faster-whisper 0755 %u %u -"
      "d %h/.cache/whisper-cpp 0755 %u %u -"
      "d %h/.cache/whisper-cpp/models 0755 %u %u -"
    ];
  };
}