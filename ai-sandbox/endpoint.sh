#!/bin/bash
set -e

/opt/llama.cpp/server \
    --model /app/models/llama-2-7b.Q4_K_M.gguf \
    --port 8080 \
    --host 0.0.0.0

