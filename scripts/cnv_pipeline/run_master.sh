#!/usr/bin/env bash
set -Eeuo pipefail

# ============================================================
# PangenomiX CNV + SNV PRODUCTION MASTER
#
# Validated production build for an input batch containing exactly 96
# Axiom_PangenomiX CEL files.
#
# CNV:
#   The validated CNV analytical/package scripts are preserved.
# SNV:
#   AxAS 96orMore Step2 -> target ProbeSet base_call export.
#   Golden validation result: 19,646 / 19,646 genotype calls matched AxAS.
#
# Usage:
#   bash run_master.sh <CEL_DIR> [RUN_NAME] [TEMPLATE_FILES_DIR] [PROBESET_LIST]
# ============================================================

if [ "$#" -lt 1 ]; then
  echo "[USAGE]"
  echo "bash run_master.sh <CEL_DIR> [RUN_NAME] [TEMPLATE_FILES_DIR] [PROBESET_LIST]"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE="$(cd "${SCRIPT_DIR}/../.." && pwd)"

CEL_DIR="${1%/}"
RUN_NAME="${2:-$(basename "$CEL_DIR")_$(date '+%Y%m%d_%H%M%S')}"
TEMPLATE_FILES_DIR="${3:-${BASE}/input/axas_template_files}"
PROBESET_LIST="${4:-${PROBESET_LIST:-${BASE}/snplists/probe_pangenomix_acmg73_verified.txt}}"

# Only optional production controls kept.
RESUME="${RESUME:-0}"
SNV_REFERENCE_RESULT="${SNV_REFERENCE_RESULT:-}"
SNV_ADDITIONAL_SNP_INFORMATION_FILE="${SNV_ADDITIONAL_SNP_INFORMATION_FILE:-}"
SNV_REQUIRED_APT_VERSION="v2.12.0-rc2"
SNV_STRICT_MODE="1"
VALIDATED_INPUT_CEL_COUNT=96

# ------------------------------------------------------------
# 0. Preflight before any analysis starts
# ------------------------------------------------------------
[ -d "$CEL_DIR" ] || { echo "[ERROR] CEL_DIR not found: $CEL_DIR"; exit 1; }
[ -d "$TEMPLATE_FILES_DIR" ] || { echo "[ERROR] TEMPLATE_FILES_DIR not found: $TEMPLATE_FILES_DIR"; exit 1; }
[ -s "$PROBESET_LIST" ] || { echo "[ERROR] PROBESET_LIST not found: $PROBESET_LIST"; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "[ERROR] python3 not found."; exit 1; }

INPUT_CEL_COUNT="$(find "$CEL_DIR" -maxdepth 1 -type f -iname '*.CEL' | wc -l | tr -d ' ')"
if [ "$INPUT_CEL_COUNT" -ne "$VALIDATED_INPUT_CEL_COUNT" ]; then
  echo "[ERROR] Unsupported input CEL count for strict AxAS-equivalent mode."
  echo "[VALIDATED] $VALIDATED_INPUT_CEL_COUNT"
  echo "[ACTUAL]    $INPUT_CEL_COUNT"
  echo "[ACTION] STOP. A different input count needs its own AxAS workflow validation."
  exit 1
fi

if [ -n "$SNV_REFERENCE_RESULT" ] && [ ! -s "$SNV_REFERENCE_RESULT" ]; then
  echo "[ERROR] SNV_REFERENCE_RESULT not found: $SNV_REFERENCE_RESULT"
  exit 1
fi
if [ -n "$SNV_ADDITIONAL_SNP_INFORMATION_FILE" ] && [ ! -s "$SNV_ADDITIONAL_SNP_INFORMATION_FILE" ]; then
  echo "[ERROR] SNV_ADDITIONAL_SNP_INFORMATION_FILE not found: $SNV_ADDITIONAL_SNP_INFORMATION_FILE"
  exit 1
fi

OUT="${BASE}/output/cnv_runs/${RUN_NAME}"
LOG_DIR="${OUT}/logs"
CHECKPOINT_DIR="${OUT}/checkpoints"
TIMES_FILE="${OUT}/pipeline_step_times.tsv"
CONFIG="${OUT}/run_config.sh"

if [ -d "$OUT" ] && [ -n "$(find "$OUT" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ] && [ "$RESUME" != "1" ]; then
  echo "[ERROR] RUN_NAME already exists: $OUT"
  echo "[ACTION] Use a new RUN_NAME, or set RESUME=1 only to resume this exact run."
  exit 1
fi

mkdir -p "$OUT" "$LOG_DIR" "$CHECKPOINT_DIR"
MASTER_LOG="${OUT}/run_master.console.log"
exec > >(tee "$MASTER_LOG") 2>&1

# ------------------------------------------------------------
# Helpers
# ------------------------------------------------------------
find_one_file() {
  local root="$1"; shift
  local pattern hit
  [ -d "$root" ] || return 0
  for pattern in "$@"; do
    hit="$(find "$root" -type f -iname "$pattern" 2>/dev/null | sort | head -1 || true)"
    if [ -n "$hit" ]; then printf '%s\n' "$hit"; return 0; fi
  done
  return 0
}

find_one_dir() {
  local root="$1"; shift
  local pattern hit
  [ -d "$root" ] || return 0
  for pattern in "$@"; do
    hit="$(find "$root" -type d -iname "$pattern" 2>/dev/null | sort | head -1 || true)"
    if [ -n "$hit" ]; then printf '%s\n' "$hit"; return 0; fi
  done
  return 0
}

fmt_seconds() {
  local t="$1"
  printf "%02d:%02d:%02d" $((t/3600)) $(((t%3600)/60)) $((t%60))
}

emit_config() {
  printf '%s=%q\n' "$1" "$2"
}

init_times_file() {
  if [ ! -f "$TIMES_FILE" ]; then
    printf "step\tscript\tlabel\tstatus\tstart_time\tend_time\telapsed_seconds\telapsed_hms\tlog_file\n" > "$TIMES_FILE"
  fi
}

append_time_record() {
  printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n" "$@" >> "$TIMES_FILE"
}

run_step() {
  local step="$1"
  local script="$2"
  local label="$3"
  local checkpoint="${CHECKPOINT_DIR}/${step}_${script%.sh}_SUCCESS"
  local log_file="${LOG_DIR}/${step}_${script}.log"

  echo
  echo "============================================================"
  echo "[$step] $label"
  echo "============================================================"

  if [ -f "$checkpoint" ]; then
    local now
    now="$(date '+%Y-%m-%d %H:%M:%S')"
    echo "[SKIP] completed checkpoint: $checkpoint"
    append_time_record "$step" "$script" "$label" "SKIP" "$now" "$now" "0" "00:00:00" "$log_file"
    return 0
  fi

  [ -f "${SCRIPT_DIR}/${script}" ] || { echo "[ERROR] missing script: ${SCRIPT_DIR}/${script}"; exit 1; }

  local s e elapsed elapsed_hms start_time end_time status
  s="$(date +%s)"
  start_time="$(date '+%Y-%m-%d %H:%M:%S')"

  set +e
  bash "${SCRIPT_DIR}/${script}" "$CONFIG" > "$log_file" 2>&1
  status=$?
  set -e

  e="$(date +%s)"
  end_time="$(date '+%Y-%m-%d %H:%M:%S')"
  elapsed=$((e-s))
  elapsed_hms="$(fmt_seconds "$elapsed")"

  if [ "$status" -ne 0 ]; then
    echo "[FAIL] $label | log=$log_file"
    append_time_record "$step" "$script" "$label" "FAIL" "$start_time" "$end_time" "$elapsed" "$elapsed_hms" "$log_file"
    tail -n 120 "$log_file" || true
    exit "$status"
  fi

  touch "$checkpoint"
  append_time_record "$step" "$script" "$label" "DONE" "$start_time" "$end_time" "$elapsed" "$elapsed_hms" "$log_file"
  echo "[DONE] $label | time=$elapsed_hms | log=$log_file"
}

# ------------------------------------------------------------
# 0-1. APT binaries
# ------------------------------------------------------------
APT_DISHQC="${APT_DISHQC:-$(command -v apt-geno-qc-axiom || true)}"
APT_GT="${APT_GT:-$(command -v apt-genotype-axiom || true)}"
APT_HMM="${APT_HMM:-$(command -v apt-copynumber-axiom-hmm || true)}"
APT_FORMAT="${APT_FORMAT:-$(command -v apt-format-result || true)}"

[ -f "$APT_DISHQC" ] || APT_DISHQC="$(find_one_file "$BASE" 'apt-geno-qc-axiom' 'apt-geno-qc-axiom*')"
[ -f "$APT_GT" ] || APT_GT="$(find_one_file "$BASE" 'apt-genotype-axiom' 'apt-genotype-axiom*')"
[ -f "$APT_HMM" ] || APT_HMM="$(find_one_file "$BASE" 'apt-copynumber-axiom-hmm' 'apt-copynumber-axiom-hmm*')"
[ -f "$APT_FORMAT" ] || APT_FORMAT="$(find_one_file "$BASE" 'apt-format-result' 'apt-format-result*')"

for item in \
  "APT_DISHQC|$APT_DISHQC" \
  "APT_GT|$APT_GT" \
  "APT_HMM|$APT_HMM" \
  "APT_FORMAT|$APT_FORMAT"
do
  name="${item%%|*}"
  value="${item#*|}"
  [ -f "$value" ] || { echo "[ERROR] required APT binary missing: $name = $value"; exit 1; }
done

# ------------------------------------------------------------
# 0-2. PangenomiX library
# ------------------------------------------------------------
LIB_DIR="${LIB_DIR:-$(find_one_dir "$BASE" 'Axiom_PangenomiX.r1' 'Axiom_Pangenomix.r1')}"
[ -d "$LIB_DIR" ] || { echo "[ERROR] Axiom_PangenomiX.r1 library not found."; exit 1; }

DISHQC_XML="${DISHQC_XML:-$(find_one_file "$LIB_DIR" '*apt-geno-qc-axiom*.xml' '*AxiomQC*.xml')}"
CALLRATE_XML="${CALLRATE_XML:-$(find_one_file "$LIB_DIR" '*apt-genotype-axiom*AxiomGT1*.xml' '*AxiomGT1*.apt2.xml')}"
CN_XML="${CN_XML:-$(find_one_file "$LIB_DIR" '*apt-genotype-axiom*AxiomCN_GT1*.xml' '*AxiomCN_GT1*.apt2.xml')}"
HMM_ARG_FILE="${HMM_ARG_FILE:-$(find_one_file "$LIB_DIR" '*apt-copynumber-axiom-hmm*AxiomHMM*.xml' '*AxiomHMM*.apt2.xml')}"
CN_MODELS="${CN_MODELS:-$(find_one_file "$LIB_DIR" '*.cn_models' '*cn_models*')}"
HMM_REGIONS="${HMM_REGIONS:-$(find_one_file "$LIB_DIR" '*.hmm_regions.txt' '*.hmm_regions' '*hmm_regions*')}"
Y_PROBES_FILE="${Y_PROBES_FILE:-$(find_one_file "$LIB_DIR" '*.chrYprobes' '*chrYprobes*')}"
ANNOTATION_FILE="${ANNOTATION_FILE:-${ANNOT_DB:-$(find_one_file "$LIB_DIR" '*.annot.db' '*annot.db')}}"
SNV_STEP2_XML="${LIB_DIR}/Axiom_PangenomiX_96orMore_Step2.r1.apt-genotype-axiom.mm.SnpSpecificPriors.AxiomGT1.apt2.xml"

# Check all SNV prerequisites now, rather than failing after the long CNV run.
required_snv_files=(
  'Axiom_PangenomiX_96orMore_Step2.r1.apt-genotype-axiom.mm.SnpSpecificPriors.AxiomGT1.apt2.xml'
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
for name in "${required_snv_files[@]}"; do
  if [ ! -s "${LIB_DIR}/${name}" ]; then
    echo "[ERROR] Missing required SNV library file: ${LIB_DIR}/${name}"
    missing=1
  fi
done
[ "$missing" -eq 0 ] || exit 1
[ -s "$ANNOTATION_FILE" ] || { echo "[ERROR] annotation DB missing: $ANNOTATION_FILE"; exit 1; }

# ------------------------------------------------------------
# Paths expected by the validated CNV scripts
# ------------------------------------------------------------
CEL_LIST="${OUT}/01_input/cel_list.txt"
DISHQC_DIR="${OUT}/02_dishqc"
DISH_PASS_LIST="${OUT}/03_dishqc_pass/cel_list_dishqc_pass.txt"
DQC_PASS_LIST="$DISH_PASS_LIST"
CALLRATE_DIR="${OUT}/04_callrate"
CALLRATE_PASS_LIST="${OUT}/05_qc_pass/cel_list_qc_pass.txt"
QC_PASS_LIST="$CALLRATE_PASS_LIST"
SUM_DIR="${OUT}/06_cn_summary"
HMM_DIR="${OUT}/07_discovery_hmm"
FINAL_DIR="${OUT}/08_final_tables"
AXAS_DIR="${OUT}/AxAS_Copy_Number_Discovery_batch_${RUN_NAME}"

# New SNV branch
SNV_STEP2_DIR="${OUT}/11_snv_step2"
SNV_EXPORT_DIR="${OUT}/12_snv_export"

# Existing CNV thresholds/settings
DQC_THRESHOLD="${DQC_THRESHOLD:-0.82}"
CALLRATE_THRESHOLD="${CALLRATE_THRESHOLD:-97}"
MAPD_MAX="${MAPD_MAX:-0.35}"
MAPDC_MAX="${MAPDC_MAX:-0.35}"
WAVINESS_SD_MAX="${WAVINESS_SD_MAX:-0.1}"
WAVINESS_SDC_MAX="${WAVINESS_SDC_MAX:-0.1}"
CEL_WIN_PREFIX="${CEL_WIN_PREFIX:-C:\\Users\\Public\\Documents\\AxiomAnalysisSuite\\cel\\}"

export PROBESET_LIST SNV_STEP2_XML SNV_REFERENCE_RESULT SNV_ADDITIONAL_SNP_INFORMATION_FILE
export SNV_REQUIRED_APT_VERSION SNV_STRICT_MODE ANNOTATION_FILE

# ------------------------------------------------------------
# run_config.sh for child scripts
# ------------------------------------------------------------
{
  for kv in \
    "BASE|$BASE" "SCRIPT_DIR|$SCRIPT_DIR" "CEL_DIR|$CEL_DIR" "RUN_NAME|$RUN_NAME" "OUT|$OUT" \
    "LOG_DIR|$LOG_DIR" "CHECKPOINT_DIR|$CHECKPOINT_DIR" "TIMES_FILE|$TIMES_FILE" \
    "TEMPLATE_FILES_DIR|$TEMPLATE_FILES_DIR" "LIB_DIR|$LIB_DIR" "PROBESET_LIST|$PROBESET_LIST" \
    "APT_DISHQC|$APT_DISHQC" "APT_GT|$APT_GT" "APT_HMM|$APT_HMM" "APT_FORMAT|$APT_FORMAT" \
    "DISHQC_XML|$DISHQC_XML" "CALLRATE_XML|$CALLRATE_XML" "CN_XML|$CN_XML" "HMM_ARG_FILE|$HMM_ARG_FILE" \
    "CN_MODELS|$CN_MODELS" "HMM_REGIONS|$HMM_REGIONS" "Y_PROBES_FILE|$Y_PROBES_FILE" \
    "ANNOTATION_FILE|$ANNOTATION_FILE" "CEL_LIST|$CEL_LIST" "DISHQC_DIR|$DISHQC_DIR" \
    "DISH_PASS_LIST|$DISH_PASS_LIST" "DQC_PASS_LIST|$DQC_PASS_LIST" "CALLRATE_DIR|$CALLRATE_DIR" \
    "CALLRATE_PASS_LIST|$CALLRATE_PASS_LIST" "QC_PASS_LIST|$QC_PASS_LIST" "SUM_DIR|$SUM_DIR" \
    "HMM_DIR|$HMM_DIR" "FINAL_DIR|$FINAL_DIR" "AXAS_DIR|$AXAS_DIR" \
    "SNV_STEP2_XML|$SNV_STEP2_XML" "SNV_STEP2_DIR|$SNV_STEP2_DIR" "SNV_EXPORT_DIR|$SNV_EXPORT_DIR" \
    "SNV_REFERENCE_RESULT|$SNV_REFERENCE_RESULT" \
    "SNV_ADDITIONAL_SNP_INFORMATION_FILE|$SNV_ADDITIONAL_SNP_INFORMATION_FILE" \
    "SNV_REQUIRED_APT_VERSION|$SNV_REQUIRED_APT_VERSION" "SNV_STRICT_MODE|$SNV_STRICT_MODE" \
    "DQC_THRESHOLD|$DQC_THRESHOLD" "CALLRATE_THRESHOLD|$CALLRATE_THRESHOLD" "MAPD_MAX|$MAPD_MAX" \
    "MAPDC_MAX|$MAPDC_MAX" "WAVINESS_SD_MAX|$WAVINESS_SD_MAX" \
    "WAVINESS_SDC_MAX|$WAVINESS_SDC_MAX" "CEL_WIN_PREFIX|$CEL_WIN_PREFIX"
  do
    emit_config "${kv%%|*}" "${kv#*|}"
  done
} > "$CONFIG"

# Small audit record; no separate setup/freeze step is required.
{
  printf "key\tvalue\n"
  printf "run_name\t%s\n" "$RUN_NAME"
  printf "start_time\t%s\n" "$(date '+%Y-%m-%d %H:%M:%S')"
  printf "input_cel_dir\t%s\n" "$CEL_DIR"
  printf "input_cel_count\t%s\n" "$INPUT_CEL_COUNT"
  printf "library_dir\t%s\n" "$LIB_DIR"
  printf "probeset_list\t%s\n" "$PROBESET_LIST"
  printf "snv_step2_xml\t%s\n" "$SNV_STEP2_XML"
} > "${OUT}/production_run_manifest.tsv"

init_times_file

echo "============================================================"
echo "PangenomiX CNV + SNV PRODUCTION START"
echo "============================================================"
echo "[RUN_NAME]        $RUN_NAME"
echo "[CEL_DIR]         $CEL_DIR"
echo "[INPUT_CEL_COUNT] $INPUT_CEL_COUNT"
echo "[OUT]             $OUT"
echo "============================================================"

# ------------------------------------------------------------
# Clean sequential workflow: 01 -> 12
# ------------------------------------------------------------
run_step "01" "01_make_cel_list.sh"                          "CEL list 생성"
run_step "02" "02_dishqc.sh"                                 "DishQC 실행"
run_step "03" "03_filter_dishqc.sh"                          "DishQC PASS list 생성"
run_step "04" "04_callrate.sh"                               "QC Call Rate / Step1 Genotyping 실행"
run_step "05" "05_filter_callrate.sh"                        "Call Rate PASS list 생성"
run_step "06" "06_cn_summarization.sh"                       "CN probeset summarization 실행"
run_step "07" "07_discovery_hmm.sh"                          "Discovery HMM 실행"
run_step "08" "08_make_final_tables.sh"                      "최종 CNV table 생성"
run_step "09" "09_package_axas_batch.sh"                     "AxAS CNV batch folder 생성"
run_step "10" "10_apply_mapd_configuration_from_template.sh" "AxAS MAPD/configuration 적용"
run_step "11" "11_snv_step2_genotyping.sh"                   "SNV Step2 AxiomGT1 실행"
run_step "12" "12_export_snv_axas_style.sh"                  "SNV AxAS-equivalent base_call export"

# Optional strict comparison when a real AxAS reference TXT is supplied.
if [ -n "$SNV_REFERENCE_RESULT" ]; then
  echo
  echo "============================================================"
  echo "[VALIDATE] SNV AxAS reference strict 1:1 validation"
  echo "============================================================"

  set +e
  bash "${SCRIPT_DIR}/tools/validate_snv_against_axas.sh" "$CONFIG" "$SNV_REFERENCE_RESULT" \
    > "${LOG_DIR}/SNV_AxAS_reference_validation.log" 2>&1
  validation_status=$?
  set -e

  cat "${LOG_DIR}/SNV_AxAS_reference_validation.log"
  if [ "$validation_status" -ne 0 ]; then
    echo "[FAIL] SNV AxAS validation"
    exit "$validation_status"
  fi
fi

SNV_RESULT="${SNV_EXPORT_DIR}/${RUN_NAME}_snv_axas_style.txt"
SNV_MATRIX="${SNV_EXPORT_DIR}/${RUN_NAME}_snv_genotype_matrix.tsv"

[ -d "$FINAL_DIR" ] || { echo "[ERROR] final CNV directory missing: $FINAL_DIR"; exit 1; }
[ -s "$SNV_RESULT" ] || { echo "[ERROR] final SNV result missing: $SNV_RESULT"; exit 1; }

{
  printf "key\tvalue\n"
  printf "run_name\t%s\n" "$RUN_NAME"
  printf "cnv_final_dir\t%s\n" "$FINAL_DIR"
  printf "snv_result\t%s\n" "$SNV_RESULT"
  printf "snv_genotype_matrix\t%s\n" "$SNV_MATRIX"
  printf "completed_time\t%s\n" "$(date '+%Y-%m-%d %H:%M:%S')"
} > "${OUT}/FINAL_RESULTS.tsv"

echo
echo "============================================================"
echo "[DONE] PRODUCTION PIPELINE COMPLETE"
echo "============================================================"
echo "[CNV] $FINAL_DIR"
echo "[SNV] $SNV_RESULT"
echo "[SNV_MATRIX] $SNV_MATRIX"
if [ -n "$SNV_REFERENCE_RESULT" ]; then
  echo "[SNV_AXAS_VALIDATION] PASS"
else
  echo "[SNV_AXAS_VALIDATION] not requested"
fi
echo "[SUMMARY] ${OUT}/FINAL_RESULTS.tsv"
echo "[MASTER_LOG] $MASTER_LOG"
echo "============================================================"
