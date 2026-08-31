#!/usr/bin/env bash
set -Eeuo pipefail

# ============================================================
# 11_snv_step2_genotyping.sh
# Production SNV Step2 genotyping for Axiom_PangenomiX.r1
#
# IMPORTANT
# - CNV directories/files are never modified here.
# - Uses the existing Step 05 Call Rate PASS CEL list.
# - Uses the AxAS 96-or-more Step2 workflow that was verified
#   against the positive_samples Golden dataset.
# - Any mismatch in required runtime conditions causes FAIL.
# ============================================================

CONFIG="${1:?run_config.sh 필요}"
# shellcheck disable=SC1090
source "$CONFIG"

SNV_STEP2_DIR="${SNV_STEP2_DIR:-${OUT}/11_snv_step2}"
SNV_STEP2_XML="${SNV_STEP2_XML:-}"
SNV_STEP2_CEL_LIST="${SNV_STEP2_CEL_LIST:-${CALLRATE_PASS_LIST:-${QC_PASS_LIST:-}}}"
SNV_REQUIRED_APT_VERSION="${SNV_REQUIRED_APT_VERSION:-v2.12.0-rc2}"
SNV_STRICT_MODE="${SNV_STRICT_MODE:-1}"

mkdir -p "$SNV_STEP2_DIR" "$LOG_DIR"

find_one() {
  local root="$1"; shift
  local p hit
  for p in "$@"; do
    hit="$(find "$root" -maxdepth 2 -type f -iname "$p" 2>/dev/null | sort | head -n 1 || true)"
    if [ -n "$hit" ]; then
      printf '%s\n' "$hit"
      return 0
    fi
  done
  return 0
}

if [ -z "$SNV_STEP2_XML" ] || [ ! -s "$SNV_STEP2_XML" ]; then
  SNV_STEP2_XML="$(find_one "$LIB_DIR" \
    'Axiom_PangenomiX_96orMore_Step2.r1.apt-genotype-axiom.mm.SnpSpecificPriors.AxiomGT1.apt2.xml')"
fi

if [ -z "$SNV_STEP2_XML" ] || [ ! -s "$SNV_STEP2_XML" ]; then
  echo "[ERROR] 검증된 96orMore Step2 XML을 찾지 못했습니다."
  exit 1
fi

if [ -z "$SNV_STEP2_CEL_LIST" ] || [ ! -s "$SNV_STEP2_CEL_LIST" ]; then
  echo "[ERROR] Step2 CEL list를 찾지 못했습니다: ${SNV_STEP2_CEL_LIST:-<empty>}"
  exit 1
fi

if [ -z "${APT_GT:-}" ] || [ ! -x "$APT_GT" ]; then
  echo "[ERROR] apt-genotype-axiom 실행 파일을 찾지 못했습니다: ${APT_GT:-<empty>}"
  exit 1
fi

if [ -z "${PROBESET_LIST:-}" ] || [ ! -s "$PROBESET_LIST" ]; then
  echo "[ERROR] PROBESET_LIST를 찾지 못했습니다: ${PROBESET_LIST:-<empty>}"
  exit 1
fi

# ------------------------------------------------------------------
# Verify that Step1 used the same APT version as the Golden run.
# The version is recorded in 04_callrate/AxiomGT1.calls.txt.
# ------------------------------------------------------------------
STEP1_CALLS="${CALLRATE_DIR}/AxiomGT1.calls.txt"
if [ ! -s "$STEP1_CALLS" ]; then
  echo "[ERROR] Step1 calls file not found: $STEP1_CALLS"
  exit 1
fi

STEP1_APT_VERSION="$(grep -m1 '^#%affymetrix-algorithm-param-apt-version=' "$STEP1_CALLS" 2>/dev/null | sed 's/^[^=]*=//' || true)"
if [ "$SNV_STRICT_MODE" = "1" ]; then
  case "$STEP1_APT_VERSION" in
    *"$SNV_REQUIRED_APT_VERSION"*) : ;;
    *)
      echo "[ERROR] apt-genotype-axiom version mismatch."
      echo "[REQUIRED] $SNV_REQUIRED_APT_VERSION"
      echo "[ACTUAL]   ${STEP1_APT_VERSION:-unknown}"
      exit 1
      ;;
  esac
fi

SAMPLE_COUNT="$(awk 'BEGIN{n=0} NR==1 && tolower($1) ~ /^cel/ {next} NF{n++} END{print n}' "$SNV_STEP2_CEL_LIST")"
if [ "$SAMPLE_COUNT" -le 0 ]; then
  echo "[ERROR] Step2 input sample count = 0"
  exit 1
fi

required_library_files=(
  'Axiom_PangenomiX.r1.step2.ps'
  'Axiom_PangenomiX.r1.AxiomGT1.models'
  'Axiom_PangenomiX.r1.AxiomGT1.mmb.multimodels_background'
  'Axiom_PangenomiX.r1.AxiomGT1.mmp.multimodels_pairwise'
  'Axiom_PangenomiX.r1.AxiomGT1.mm.multimodels'
  'Axiom_PangenomiX.r1.cdf'
  'Axiom_PangenomiX.r1.specialSNPs'
  'Axiom_PangenomiX.r1.chrXprobes'
  'Axiom_PangenomiX.r1.chrYprobes'
  'Axiom_PangenomiX.r1.AxiomGT1.sketch'
  'Axiom_PangenomiX.r1.probeset_genotyping_parameters.txt'
)

missing=0
for name in "${required_library_files[@]}"; do
  if [ ! -s "${LIB_DIR}/${name}" ]; then
    echo "[ERROR] Missing Step2 library file: ${LIB_DIR}/${name}"
    missing=1
  fi
done
[ "$missing" -eq 0 ] || exit 1

STEP2_PS="${LIB_DIR}/Axiom_PangenomiX.r1.step2.ps"
TARGET_PRESENT="${SNV_STEP2_DIR}/target_probesets_present_in_step2.txt"
TARGET_EXCLUDED="${SNV_STEP2_DIR}/target_probesets_not_in_step2.txt"

python3 - "$PROBESET_LIST" "$STEP2_PS" "$TARGET_PRESENT" "$TARGET_EXCLUDED" <<'PY'
from __future__ import print_function
import sys
probe_file, step2_file, present_file, excluded_file = sys.argv[1:]

def read_targets(path):
    out=[]; seen=set()
    with open(path, 'r') as f:
        for line in f:
            line=line.strip().replace('\r','')
            if not line or line.startswith('#'):
                continue
            v=line.replace(',', '\t').split()[0].strip('"')
            if v.lower() in ('probeset_id','probe_set_id','probesetid','id'):
                continue
            if v and v not in seen:
                seen.add(v); out.append(v)
    return out

targets=read_targets(probe_file)
step2=set()
with open(step2_file, 'r') as f:
    for line in f:
        v=line.strip().replace('\r','').split('\t')[0]
        if not v or v.startswith('#') or v.lower() in ('probeset_id','probe_set_id','probesetid'):
            continue
        step2.add(v)

present=[x for x in targets if x in step2]
excluded=[x for x in targets if x not in step2]
with open(present_file,'w') as f:
    f.write('probeset_id\n')
    for x in present: f.write(x+'\n')
with open(excluded_file,'w') as f:
    f.write('probeset_id\n')
    for x in excluded: f.write(x+'\n')

print('[INFO] target probesets total    = {}'.format(len(targets)))
print('[INFO] target probesets Step2    = {}'.format(len(present)))
print('[INFO] target probesets excluded = {}'.format(len(excluded)))
PY

APT_LOG="${LOG_DIR}/11_SNV_Step2_AxiomGT1.log"
rm -rf "${SNV_STEP2_DIR}/APTTemp"
rm -f \
  "${SNV_STEP2_DIR}/AxiomGT1.calls.txt" \
  "${SNV_STEP2_DIR}/AxiomGT1.confidences.txt" \
  "${SNV_STEP2_DIR}/AxiomGT1.report.txt" \
  "${SNV_STEP2_DIR}/AxiomGT1.snp-posteriors.txt"
mkdir -p "${SNV_STEP2_DIR}/APTTemp"

cat <<INFO
============================================================
[11] SNV Step2 AxiomGT1 - PRODUCTION
============================================================
[APT_GT]             $APT_GT
[APT_VERSION]        ${STEP1_APT_VERSION:-unknown}
[LIB_DIR]            $LIB_DIR
[STEP2_XML]          $SNV_STEP2_XML
[STEP2_PS]           $STEP2_PS
[CEL_LIST]           $SNV_STEP2_CEL_LIST
[SAMPLE_COUNT]       $SAMPLE_COUNT
[OUT_DIR]            $SNV_STEP2_DIR
============================================================
INFO

set +e
"$APT_GT" \
  --analysis-files-path "$LIB_DIR" \
  --arg-file "$SNV_STEP2_XML" \
  --cel-files "$SNV_STEP2_CEL_LIST" \
  --out-dir "$SNV_STEP2_DIR" \
  --temp-dir "${SNV_STEP2_DIR}/APTTemp" \
  --table-output true \
  --report true \
  --log-file "$APT_LOG"
status=$?
set -e

if [ "$status" -ne 0 ]; then
  echo "[ERROR] SNV Step2 apt-genotype-axiom failed. exit=$status"
  tail -n 120 "$APT_LOG" 2>/dev/null || true
  exit "$status"
fi

CALLS_FILE="${SNV_STEP2_DIR}/AxiomGT1.calls.txt"
if [ ! -s "$CALLS_FILE" ]; then
  echo "[ERROR] Step2 completed but AxiomGT1.calls.txt was not created."
  exit 1
fi

CALLS_SAMPLE_COUNT="$(python3 - "$CALLS_FILE" <<'PY'
from __future__ import print_function
import sys
p=sys.argv[1]
n=-1
with open(p,'r') as f:
    for line in f:
        if line.startswith('probeset_id\t'):
            n=len(line.rstrip('\r\n').split('\t'))-1
            break
print(n)
PY
)"

if [ "$CALLS_SAMPLE_COUNT" -ne "$SAMPLE_COUNT" ]; then
  echo "[ERROR] Step2 sample count mismatch. input=$SAMPLE_COUNT calls=$CALLS_SAMPLE_COUNT"
  exit 1
fi

MANIFEST="${SNV_STEP2_DIR}/step2_manifest.tsv"
{
  printf "key\tvalue\n"
  printf "step2_xml\t%s\n" "$SNV_STEP2_XML"
  printf "step2_ps\t%s\n" "$STEP2_PS"
  printf "cel_list\t%s\n" "$SNV_STEP2_CEL_LIST"
  printf "sample_count\t%s\n" "$SAMPLE_COUNT"
  printf "apt_version\t%s\n" "$STEP1_APT_VERSION"
  printf "calls_file\t%s\n" "$CALLS_FILE"
  printf "apt_log\t%s\n" "$APT_LOG"
} > "$MANIFEST"

echo "[DONE] SNV Step2 completed. samples=$SAMPLE_COUNT"
echo "[CALLS] $CALLS_FILE"
