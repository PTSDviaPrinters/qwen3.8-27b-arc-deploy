# Start Qwen3.8-27B (Q6_K + mmproj-F16) on the Intel Arc Pro B70 via llama.cpp-SYCL
# Edit the two paths below (LLAMA_BIN = your SYCL deploy dir) then run this script.
$ErrorActionPreference = "Stop"

$LLAMA_BIN = "M:\LLMs\llama-b9334-bin-win-sycl-x64"   # <-- point at your llama.cpp-SYCL deploy dir
$MODEL     = "M:\LLM's\.lmstudio\unsloth\Qwen3.8-27B-Q6_K.gguf"
$MMPROJ    = "M:\LLM's\.lmstudio\unsloth\mmproj-F16.gguf"

if (!(Test-Path (Join-Path $LLAMA_BIN "llama-server.exe"))) { throw "llama-server.exe not found in $LLAMA_BIN - check deploy dir / rebuild via build-latest.sh" }
if (!(Test-Path $MODEL) -or !(Test-Path $MMPROJ)) { throw "Model or mmproj missing - run .\scripts\download-qwen38-arc.ps1 first" }

& (Join-Path $LLAMA_BIN "llama-server.exe") `
    -m $MODEL `
    --mmproj $MMPROJ `
    -ngl 99 `
    --host 0.0.0.0 --port 8081 `
    -c 32768 `
    --parallel 2 `
    --alias qwen3.8-27b-q6

if ($LASTEXITCODE -ne 0) { Write-Host "server exited with code $LASTEXITCODE" }
