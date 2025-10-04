# WhispAway

Voice dictation for Linux using OpenAI's Whisper models. Type with your voice using local speech recognition - no cloud services required.

## Features

- **Instant Typing**: Transcribed text is typed directly at your cursor
- **Dual Backends**: Choose between `whisper.cpp` or `faster-whisper`
- **Hardware Acceleration**: CUDA, Vulkan, OpenVINO, and CPU support
- **Model Preloading**: Daemon mode keeps models in memory for instant transcription
- **System Tray Control**: Start/stop preload daemon using system tray
- **NixOS Integration**: First-class NixOS and Home Manager support

## Installation

### NixOS / Home Manager

```nix
{
  # With NixOS
  imports = [ whisp-away.nixosModules.nixos ];
  # With home-manager
  imports = [ whisp-away.nixosModules.home-manager ];
  
  services.whisp-away = {
    enable = true;
    accelerationType = "vulkan";  # or "cuda", "openvino", "cpu" - requires rebuild
    useCrane = "false" # Enable if you want faster rebuilds when developing
  };
}
```

## Usage

### Keybinds (Recommended)

Configure your keybinds to enable push-to-talk:

For example in Hyprland config, push to talk and release to transcribe:
```conf
# section = the § key on Swedish keyboards (top-left, below Esc)
bind = ,section,exec, whisp-away start
bindr = ,section,exec, whisp-away stop
```

### System Tray (Recommended)

Improve transcription speed by preloading models.

Access from your `desktop apps`, or start from a terminal:

```bash
whisp-away tray                    # Uses default backend ($WA_WHISPER_BACKEND)
whisp-away tray -b faster-whisper  # Use faster-whisper backend
```

The tray icon lets you:
- **Left-click**: Start/stop daemon for preloaded models
- **Right-click**: Open menu with status and options

### Command Line

```bash
# One-shot recording and transcription
whisp-away start              # Start recording
whisp-away stop               # Stop and transcribe

# Specify model or backend
whisp-away stop --model medium.en
whisp-away stop --backend faster-whisper
```

## Models & Performance

| Model | Size | Speed | Quality | Use Case |
|-------|------|-------|---------|----------|
| **tiny.en** | 39 MB | Instant | Basic | Quick notes, testing |
| **base.en** | 74 MB | Fast | Good | Casual dictation |
| **small.en** | 244 MB | Moderate | Better | Daily use (recommended) |
| **medium.en** | 769 MB | Slow | Excellent | Professional transcription |
| **large-v3** | 1550 MB | Slowest | Best | Maximum accuracy, multilingual |

Models download automatically on first use, and are stored in `~/.cache/whisper-cpp/models/` (GGML models for whisper.cpp) and `~/.cache/faster-whisper/` (CTranslate2 models for faster-whisper).

For OpenVINO the GGML models have to be translated into the openVINO format (see docs in the whisper.cpp repo), this hasn't been automized yet.

## Hardware Acceleration

WhispAway supports multiple acceleration types:

| Type | Backend Support | Hardware |
|------|----------------|----------|
| **vulkan** | whisper.cpp | Most GPUs (AMD, NVIDIA, Intel) |
| **cuda** | Both backends | NVIDIA GPUs only |
| **openvino** | whisper.cpp | Intel GPUs and CPUs |
| **cpu** | Both backends | Any CPU (slow) |

**Note**: `faster-whisper` only supports CUDA and CPU. The `whisper.cpp` backend supports all acceleration types.

## Building from Source

### With Nix
```bash
nix build        # Builds with default settings
nix develop      # Enter development shell
```

### With Cargo
```bash
cargo build --release --features vulkan
```

## Configuration

### NixOS Module Options

```nix
services.whisp-away = {
  enable = true;
  defaultModel = "small.en";        # sets WA_WHISPER_MODEL
  defaultBackend = "whisper-cpp";   # sets WA_WHISPER_BACKEND
  accelerationType = "vulkan";      # 
}
```

### Environment Variables

- `WA_WHISPER_MODEL`: Default model (e.g., "small.en")
- `WA_WHISPER_BACKEND`: Default backend ("whisper-cpp" or "faster-whisper")

## Troubleshooting

**Tray icon doesn't appear?**
- Make sure you have a system tray (GNOME needs an extension)
- Check if the app is running: `ps aux | grep whisp-away`

**Transcription is slow?**
- Use a smaller model (tiny.en or base.en)
- Enable GPU acceleration if available
- The daemon pre-loads the model for faster response

**No text appears after recording?**
- Check the notification for errors
- Verify `wtype` is installed for Wayland or `xdotool` for X11
- Test with `whisp-away stop --no-typing` to see raw output

## Project Status

This project is actively maintained and only tested on NixOS. Contributions are welcome!

## License

MIT License

## Credits

- [OpenAI Whisper](https://github.com/openai/whisper) - Original speech recognition models
- [whisper.cpp](https://github.com/ggerganov/whisper.cpp) - C++ implementation
- [faster-whisper](https://github.com/guillaumekln/faster-whisper) - CTranslate2 optimized implementation
- [whisper-rs](https://github.com/tazz4843/whisper-rs) - Rust bindings