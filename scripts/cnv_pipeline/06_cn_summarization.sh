#!/usr/bin/env bash
set -Eeuo pipefail

CONFIG="${1:?run_config.sh 필요}"
source "$CONFIG"

# ============================================================
# 04_callrate.sh의 AxAS GenoTyping replay에서 AxiomGT1.summary.a5를
# 이미 생성한 경우, 06에서는 재생성하지 않고 그대로 사용한다.
# ============================================================

SUMMARY_FILE="${SUM_DIR}/AxiomGT1.summary.a5"

# [FIX] 06은 항상 CN_XML 기준 full AxiomGT1.*를 새로 생성합니다.
# 04_callrate 결과를 재사용하지 않습니다.


echo "============================================================"
echo "[06] CN probeset summarization 실행 - 전체 CEL_LIST 기준"
echo "============================================================"

if [ ! -f "$APT_GT" ]; then
  echo "[ERROR] APT_GT 파일이 없습니다: $APT_GT"
  exit 1
fi

if [ ! -f "$CN_XML" ]; then
  echo "[ERROR] CN_XML 파일이 없습니다: $CN_XML"
  exit 1
fi

if [ ! -f "$CEL_LIST" ]; then
  echo "[ERROR] CEL_LIST 파일이 없습니다: $CEL_LIST"
  exit 1
fi

echo "[중요] QC PASS list가 아니라 전체 CEL_LIST로 CN summary를 생성합니다."
echo "[INFO] CN_XML  = $CN_XML"
echo "[INFO] CEL_LIST = $CEL_LIST"
echo "[INFO] SUM_DIR = $SUM_DIR"

rm -rf "$SUM_DIR"
mkdir -p "$SUM_DIR"

"$APT_GT" \
  --analysis-files-path "$LIB_DIR" \
  --arg-file "$CN_XML" \
  --cel-files "$CEL_LIST" \
  --out-dir "$SUM_DIR"

SUMMARY_A5="$(find "$SUM_DIR" -maxdepth 3 -type f -name "*summary.a5" | sort | head -1 || true)"
if [ -z "$SUMMARY_A5" ] || [ ! -f "$SUMMARY_A5" ]; then
  echo "[ERROR] summary.a5를 찾지 못했습니다: $SUM_DIR"
  find "$SUM_DIR" -maxdepth 3 -type f | sort || true
  exit 1
fi

if [ "$SUMMARY_A5" != "$SUM_DIR/AxiomGT1.summary.a5" ]; then
  cp -a "$SUMMARY_A5" "$SUM_DIR/AxiomGT1.summary.a5"
fi

echo "[OK] AxiomGT1.summary.a5 = $SUM_DIR/AxiomGT1.summary.a5"

# report/calls/confidences 파일명을 AxAS 표준 이름으로 정규화
for pair in \
  "report.txt:AxiomGT1.report.txt" \
  "calls.txt:AxiomGT1.calls.txt" \
  "confidences.txt:AxiomGT1.confidences.txt"
do
  suffix="${pair%%:*}"
  target="${pair#*:}"
  found="$(find "$SUM_DIR" -maxdepth 3 -type f -name "*${suffix}" | sort | head -1 || true)"
  if [ -n "$found" ] && [ -f "$found" ] && [ "$found" != "$SUM_DIR/$target" ]; then
    cp -a "$found" "$SUM_DIR/$target"
  fi
done

echo "[CHECK] 06 full AxiomGT1 files"
for f in \
  "$SUM_DIR/AxiomGT1.summary.a5" \
  "$SUM_DIR/AxiomGT1.report.txt" \
  "$SUM_DIR/AxiomGT1.calls.txt" \
  "$SUM_DIR/AxiomGT1.confidences.txt"
do
  if [ ! -s "$f" ]; then
    echo "[ERROR] 06_cn_summary 필수 파일이 없거나 비어 있습니다: $f"
    find "$SUM_DIR" -maxdepth 3 -type f | sort || true
    exit 1
  fi
  ls -lh "$f"
done
