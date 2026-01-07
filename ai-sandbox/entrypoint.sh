#!/bin/bash
set -e

MODEL_DIR="/app/models"
MODEL_FILE="llama-2-7b.Q4_K_M.gguf"
MODEL_PATH="${MODEL_DIR}/${MODEL_FILE}"
MODEL_URL="https://huggingface.co/TheBloke/Llama-2-7B-GGUF/resolve/main/${MODEL_FILE}"

# Ensure model directory exists
mkdir -p "$MODEL_DIR"

# Download model only if missing
if [ ! -f "$MODEL_PATH" ]; then
    echo "Model not found at $MODEL_PATH"
    echo "Downloading model..."
    wget -O "$MODEL_PATH" "$MODEL_URL"
    echo "Download complete."
else
    echo "Model already present at $MODEL_PATH"
fi

# Launch the llama.cpp server binary
exec /opt/llama.cpp/server \
    --model "$MODEL_PATH" \
    --port 8080 \
    --host 0.0.0.0

