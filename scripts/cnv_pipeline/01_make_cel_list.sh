#!/usr/bin/env bash
set -Eeuo pipefail

CONFIG="${1:?run_config.sh 필요}"
source "$CONFIG"

echo "============================================================"
echo "[01] CEL list 생성"
echo "============================================================"

mkdir -p "$(dirname "$CEL_LIST")"

if [ ! -d "$CEL_DIR" ]; then
  echo "[ERROR] CEL_DIR 폴더가 없습니다:"
  echo "$CEL_DIR"
  exit 1
fi

{
  echo "cel_files"
  find "$CEL_DIR" -maxdepth 1 -type f -iname "*.CEL" | sort
} > "$CEL_LIST"

N=$(awk 'NR>1 && NF>0 {n++} END{print n+0}' "$CEL_LIST")

echo "[OK] CEL_LIST = $CEL_LIST"
echo "[OK] CEL count = $N"

if [ "$N" -eq 0 ]; then
  echo "[ERROR] CEL 파일이 0개입니다."
  exit 1
fi
