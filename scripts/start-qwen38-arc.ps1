# Start Qwen3.8-27B (Q6_K + mmproj-F16) on the Intel Arc Pro B70 via llama.cpp-SYCL
# Flags VERIFIED on this box 2026-08-17 (text + vision smoke test). ~19 t/s decode.
# For the restart-loop + crash-log variant already staged here, use:
#   M:\LLMs\start-qwen38-arc.ps1
$ErrorActionPreference = "Stop"

$LLAMA_BIN = "M:\LLMs\llama-b10069-bin-win-sycl-x64"
$MODEL     = "M:\LLM's\.lmstudio\unsloth\Qwen3.8-27B-Q6_K.gguf"
$MMPROJ    = "M:\LLM's\.lmstudio\unsloth\mmproj-F16.gguf"

if (!(Test-Path (Join-Path $LLAMA_BIN "llama-server.exe"))) { throw "llama-server.exe not found in $LLAMA_BIN" }
if (!(Test-Path $MODEL) -or !(Test-Path $MMPROJ)) { throw "Model or mmproj missing - run .\scripts\download-qwen38-arc.ps1 first" }

& (Join-Path $LLAMA_BIN "llama-server.exe") `
    -m $MODEL `
    --mmproj $MMPROJ `
    --host 127.0.0.1 --port 8081 `
    -c 262144 `
    -ngl 99 `
    -t 8 `
    --main-gpu 0 `
    --split-mode none `
    --parallel 1 `
    --alias qwen3.8-27b-q6 `
    -ub 1024 `
    -b 1024 `
    --no-mmap `
    --mlock `
    --no-warmup `
    --flash-attn on `
    --jinja `
    --cache-type-k q8_0 `
    --cache-type-v q8_0 `
    --cache-ram 0 `
    --temp 0.6 --top-p 0.95 --top-k 20

if ($LASTEXITCODE -ne 0) { Write-Host "server exited with code $LASTEXITCODE" }
