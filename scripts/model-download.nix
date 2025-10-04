{ lib
, pkgs
, writeShellScriptBin
, curl
}:

{
  download-whisper-model = writeShellScriptBin "download-whisper-model" ''
    #!${pkgs.bash}/bin/bash
    
    MODEL_DIR="$HOME/.cache/whisper-cpp/models"
    mkdir -p "$MODEL_DIR"
    
    MODEL="''${1:-medium.en}"
    MODEL_FILE="$MODEL_DIR/ggml-$MODEL.bin"
    
    if [ -f "$MODEL_FILE" ]; then
      echo "Model $MODEL already exists at $MODEL_FILE"
      exit 0
    fi
    
    echo "Downloading Whisper model: $MODEL"
    echo "This may take a while depending on the model size..."
    echo ""
    echo "Model sizes:"
    echo "  tiny.en    ~39 MB"
    echo "  base.en    ~74 MB"
    echo "  small.en   ~244 MB"
    echo "  medium.en  ~769 MB"
    echo "  large-v3   ~1550 MB"
    echo ""
    
    ${curl}/bin/curl -L --progress-bar -o "$MODEL_FILE" \
      "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-$MODEL.bin"
    
    if [ $? -eq 0 ]; then
      echo "✅ Model downloaded successfully to $MODEL_FILE"
    else
      echo "❌ Failed to download model"
      rm -f "$MODEL_FILE"
      exit 1
    fi
  '';
  
  list-whisper-models = writeShellScriptBin "list-whisper-models" ''
    #!${pkgs.bash}/bin/bash
    
    echo "Available Whisper models for download:"
    echo ""
    echo "English-only models (faster, smaller):"
    echo "  tiny.en    - Fastest, least accurate (~39 MB)"
    echo "  base.en    - Fast, reasonable accuracy (~74 MB)"
    echo "  small.en   - Good balance (~244 MB)"
    echo "  medium.en  - Better accuracy (~769 MB)"
    echo ""
    echo "Multilingual models:"
    echo "  tiny       - Fastest multilingual (~39 MB)"
    echo "  base       - Fast multilingual (~74 MB)"
    echo "  small      - Good multilingual (~244 MB)"
    echo "  medium     - Better multilingual (~769 MB)"
    echo "  large-v3   - Best accuracy (~1550 MB)"
    echo ""
    echo "Downloaded models:"
    
    MODEL_DIR="$HOME/.cache/whisper-cpp/models"
    if [ -d "$MODEL_DIR" ]; then
      for model in "$MODEL_DIR"/ggml-*.bin; do
        if [ -f "$model" ]; then
          basename "$model" | sed 's/ggml-//;s/.bin//'
        fi
      done
    else
      echo "  None"
    fi
    
    echo ""
    echo "To download a model, run: download-whisper-model <model-name>"
  '';
}