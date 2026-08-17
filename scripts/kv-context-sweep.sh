#!/bin/bash
# Round 2: use the 256K headroom for KV precision + yarn probe. Fixed pgrep.
BIN="/m/LLMs/llama-b10069-bin-win-sycl-x64/llama-server.exe"
MODEL="M:/LLM's/.lmstudio/unsloth/Qwen3.8-27B-Q6_K.gguf"
MMPROJ="M:/LLM's/.lmstudio/unsloth/mmproj-F16.gguf"
PORT=8081
LOG=/tmp/kvsweep2.log

kill_server() { powershell.exe -NoProfile -Command "Get-Process llama-server -ErrorAction SilentlyContinue | Stop-Process -Force" >/dev/null 2>&1; sleep 4; }
alive() { powershell.exe -NoProfile -Command "if (Get-Process llama-server -ErrorAction SilentlyContinue) { 1 } else { 0 }" 2>/dev/null | tr -d '\r'; }

run_case() {
  local CTX=$1 RAM=$2 KT=$3 VT=$4 ROPE=$5
  kill_server
  echo "===== CASE ctx=$CTX cache_ram=$RAM kv=${KT}/${VT} rope=[$ROPE] ====="
  local ARGS="-m $MODEL --mmproj $MMPROJ --host 127.0.0.1 --port $PORT -c $CTX -ngl 99 -t 8 --main-gpu 0 --split-mode none --parallel 1 -ub 1024 -b 1024 --no-mmap --mlock --no-warmup --flash-attn on --jinja --cache-type-k $KT --cache-type-v $VT --cache-ram $RAM --alias qwen3.8-27b-q6"
  if [ -n "$ROPE" ]; then ARGS="$ARGS $ROPE"; fi
  "$BIN" $ARGS >"$LOG" 2>&1 &
  local OK=0
  for i in $(seq 1 30); do
    if grep -q "listening on http" "$LOG" 2>/dev/null; then OK=1; echo "BOOT_OK after ~$((i*4))s"; break; fi
    if [ "$(alive)" = "0" ]; then echo "BOOT_FAIL (process died)"; break; fi
    sleep 4
  done
  if [ "$OK" != "1" ]; then echo "BOOT_FAIL (no listen in 120s)"; kill_server; return; fi
  local R=$(curl -s -m 120 http://127.0.0.1:$PORT/v1/chat/completions -H "Content-Type: application/json" -d '{"model":"qwen3.8-27b-q6","messages":[{"role":"user","content":"Say OK"}],"max_tokens":16,"temperature":0}')
  echo "$R" | python -c "import json,sys;d=json.load(sys.stdin);print('gen_ok usage:',d.get('usage'))" 2>/dev/null || echo "gen FAILED: ${R:0:150}"
  grep -aiE "n_ctx|KV|rope|context" "$LOG" | grep -viE "print_timing|loading" | tail -6
  sleep 2
  kill_server
}

# 1) 256K with q8_0 KV (better quality KV, pure GPU)
run_case 262144 0 q8_0 q8_0 ""
# 2) 256K with f16 KV (max KV quality, pure GPU)
run_case 262144 0 f16 f16 ""
# 3) push past native: 320K yarn q4_0 pure GPU
run_case 327680 0 q4_0 q4_0 "--rope-scaling linear --rope-scale 1.25"
# 4) 300K yarn q4_0 pure GPU (softer stretch)
run_case 307200 0 q4_0 q4_0 "--rope-scaling linear --rope-scale 1.171875"
echo "SWEEP2-DONE"
