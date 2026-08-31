#!/usr/bin/env bash
set -euo pipefail

CONFIG="${1:?run_config.sh 필요}"
source "$CONFIG"

echo "============================================================"
echo "[09] AxAS Copy Number Discovery batch folder 생성 - PRODUCTION FINAL"
echo "============================================================"

BASE="${BASE:-/BiO/Pangenomics_master_files_260610}"
AXAS_DIR="${AXAS_DIR:-$OUT/AxAS_Copy_Number_Discovery_batch_$RUN_NAME}"
AAS_DATA="$AXAS_DIR/AxiomAnalysisSuiteData"

SRC_07="$OUT/07_discovery_hmm/CNData"
SRC_TEMP="$OUT/Temp"

# 실제 AxAS에서 open 검증된 donor batch.
# binary/schema 구조는 그대로 유지하고 현재 run에 필요한 sample명/plate/well/path만 교체한다.
TEMPLATE_AXAS_BATCH="${TEMPLATE_AXAS_BATCH:-$TEMPLATE_FILES_DIR}"

echo "[INFO] RUN_NAME=$RUN_NAME"
echo "[INFO] OUT=$OUT"
echo "[INFO] AXAS_DIR=$AXAS_DIR"
echo "[INFO] TEMPLATE_AXAS_BATCH=$TEMPLATE_AXAS_BATCH"
echo "[INFO] CEL_LIST=${CEL_LIST:-}"

for f in \
  "$TEMPLATE_AXAS_BATCH/AxiomAnalysisSuiteData/sample_info.bin" \
  "$TEMPLATE_AXAS_BATCH/AxiomAnalysisSuiteData/cel_headers.txt" \
  "$TEMPLATE_AXAS_BATCH/AxiomAnalysisSuiteData/batch_info.xml" \
  "$TEMPLATE_AXAS_BATCH/genotyping_cel_files.txt" \
  "$SRC_07/AxiomHMM.cnv.a5" \
  "$SRC_07/AxiomHMM.report.txt"
do
  if [ ! -s "$f" ]; then
    echo "[ERROR] 필수 파일 없음: $f"
    exit 1
  fi
done

CEL_LIST_FOR_AXAS=""
for f in "${CEL_LIST:-}" "$OUT/01_input/cel_list.txt" "$OUT/input/cel_list.txt" "$OUT/cel_list.txt"; do
  if [ -n "$f" ] && [ -s "$f" ]; then
    CEL_LIST_FOR_AXAS="$f"
    break
  fi
done

if [ -z "$CEL_LIST_FOR_AXAS" ]; then
  echo "[ERROR] current run CEL list를 찾지 못했습니다."
  exit 1
fi

echo
echo "[1] known-good AxAS donor batch 복사"

rm -rf "$AXAS_DIR"
cp -a "$TEMPLATE_AXAS_BATCH" "$AXAS_DIR"

mkdir -p \
  "$AAS_DATA" \
  "$AXAS_DIR/CNData" \
  "$AXAS_DIR/Temp" \
  "$AXAS_DIR/Logs" \
  "$AXAS_DIR/QC" \
  "$AXAS_DIR/snpLists"

rm -f \
  "$AAS_DATA/All_genotypes_by_snps.CHP.bin" \
  "$AAS_DATA/All_genotypes_by_snps.CHP.index.txt"

echo
echo "[2] current run CNData 적용"

cp -f "$SRC_07/AxiomHMM.cnv.a5" \
      "$AXAS_DIR/CNData/AxiomHMM.cnv.a5"

cp -f "$SRC_07/AxiomHMM.report.txt" \
      "$AXAS_DIR/CNData/AxiomHMM.report.txt"

cp -f "$SRC_07/AxiomHMM.report.txt" \
      "$AAS_DATA/current_hmm_metrics.tsv"

echo
echo "[3] current run Temp 적용"

for f in \
  CopyNumber.APT2Input \
  GenoTyping.APT2Input \
  ChangedSCAxiom_PangenomiX.r1.apt-genotype-axiom.AxiomCN_GT1.apt2.xml
do
  found=""
  for d in "$SRC_TEMP" "$OUT/Temp"; do
    if [ -s "$d/$f" ]; then
      found="$d/$f"
      break
    fi
  done

  if [ -n "$found" ]; then
    cp -f "$found" "$AXAS_DIR/Temp/$f"
    echo "[OK] $f"
  else
    echo "[WARN] current run에서 $f 없음 - donor 파일 유지"
  fi
done

echo
echo "[4] current CEL용 AxAS metadata 안전 패치"

python3 - \
  "$CEL_LIST_FOR_AXAS" \
  "$SRC_07/AxiomHMM.report.txt" \
  "$TEMPLATE_AXAS_BATCH/AxiomAnalysisSuiteData/sample_info.bin" \
  "$TEMPLATE_AXAS_BATCH/AxiomAnalysisSuiteData/cel_headers.txt" \
  "$AAS_DATA/sample_info.bin" \
  "$AAS_DATA/cel_headers.txt" \
  "$AXAS_DIR/genotyping_cel_files.txt" \
  "$OUT/axas_sample_name_map.tsv" \
  "$RUN_NAME" <<'PY'
from __future__ import print_function

import csv
import os
import re
import struct
import sys

(
    cel_list_file,
    hmm_report_file,
    donor_sample_info,
    donor_cel_headers,
    out_sample_info,
    out_cel_headers,
    out_genotyping,
    out_map,
    run_name,
) = sys.argv[1:10]

MAX_INPUT_N = 96
EXPECTED_FIELDS = [
    "cel_files",
    "affymetrix-plate-barcode",
    "affymetrix-plate-peg-wellposition",
    "cel_filepath",
    "cel_file_identifier",
    "affymetrix-array-id",
]

def basename_sample(x):
    return str(x).strip().replace("\\", "/").split("/")[-1]

def clean_line(x):
    x = x.strip()
    if x.startswith(u"\ufeff"):
        x = x.lstrip(u"\ufeff")
    return x

def read_cel_list(path):
    out = []
    with open(path, "r") as f:
        for raw in f:
            line = clean_line(raw)
            if not line or line.startswith("#"):
                continue
            if line.lower() == "cel_files":
                continue
            if "\t" in line:
                line = line.split("\t")[0].strip()
            out.append(line)
    return out

def extract_well(name):
    stem = os.path.splitext(basename_sample(name))[0]
    m = re.search(r'(?:^|[_\-.])([A-H](?:0[1-9]|1[0-2]))$', stem, re.I)
    if m:
        return m.group(1).upper()
    toks = re.split(r'[_\-.]+', stem)
    for t in reversed(toks):
        if re.match(r'^[A-H](?:0[1-9]|1[0-2])$', t, re.I):
            return t.upper()
    return ""

def read_hmm_report(path):
    rows = []
    header = None
    with open(path, "r") as f:
        for raw in f:
            line = raw.rstrip("\r\n")
            if not line or line.startswith("#"):
                continue
            parts = line.split("\t")
            if header is None:
                if "cel_files" in parts:
                    header = parts
                continue
            if len(parts) < len(header):
                parts += [""] * (len(header) - len(parts))
            rows.append(dict(zip(header, parts)))

    if header is None:
        return {}, []

    by_base = {}
    ordered = []
    for r in rows:
        base = basename_sample(r.get("cel_files", ""))
        if not base:
            continue
        by_base[base] = r
        ordered.append(base)
    return by_base, ordered

# ----- exact donor sample_info.bin parser/writer -----
def read7(data, pos):
    result = 0
    shift = 0
    while True:
        if pos >= len(data):
            raise ValueError("unexpected EOF while reading 7-bit integer")
        b = data[pos]
        pos += 1
        result |= (b & 0x7f) << shift
        if (b & 0x80) == 0:
            return result, pos
        shift += 7
        if shift > 35:
            raise ValueError("invalid 7-bit integer")

def read_string(data, pos):
    n, pos = read7(data, pos)
    if pos + n > len(data):
        raise ValueError("string exceeds sample_info.bin length")
    s = data[pos:pos+n].decode("utf-8")
    return s, pos + n

def write7(buf, value):
    value = int(value)
    while value >= 0x80:
        buf.append((value | 0x80) & 0xff)
        value >>= 7
    buf.append(value & 0xff)

def write_string(buf, s):
    if s is None:
        s = ""
    b = str(s).encode("utf-8")
    write7(buf, len(b))
    buf.extend(b)

def parse_sample_info(path):
    data = open(path, "rb").read()
    if len(data) < 4:
        raise ValueError("sample_info.bin too short")
    count = struct.unpack("<I", data[:4])[0]
    pos = 4

    fields = []
    for _ in range(6):
        s, pos = read_string(data, pos)
        fields.append(s)

    rows = []
    for _ in range(count):
        vals = []
        for _ in range(6):
            s, pos = read_string(data, pos)
            vals.append(s)
        rows.append(dict(zip(fields, vals)))

    if pos != len(data):
        raise ValueError("sample_info.bin trailing bytes: {}".format(len(data)-pos))

    return data, fields, rows

def serialize_sample_info(fields, rows):
    buf = bytearray()
    buf.extend(struct.pack("<I", len(rows)))
    for field in fields:
        write_string(buf, field)
    for row in rows:
        for field in fields:
            write_string(buf, row.get(field, ""))
    return bytes(buf)

# donor binary must be perfectly understood before any modification
donor_raw, sample_fields, donor_sample_rows = parse_sample_info(donor_sample_info)
if sample_fields != EXPECTED_FIELDS:
    raise SystemExit("[ERROR] donor sample_info field schema unexpected: {}".format(sample_fields))

if serialize_sample_info(sample_fields, donor_sample_rows) != donor_raw:
    raise SystemExit("[ERROR] donor sample_info round-trip mismatch. 안전 중단.")

print("[CHECK] donor sample_info.bin round-trip = EXACT")

# donor cel_headers schema is preserved exactly; no new columns are added
with open(donor_cel_headers, "r", newline="") as f:
    reader = csv.DictReader(f, delimiter="\t")
    header_fields = reader.fieldnames or []
    donor_header_rows = [dict(r) for r in reader]

if "cel_files" not in header_fields:
    raise SystemExit("[ERROR] donor cel_headers.txt에 cel_files column 없음")
if "affymetrix-plate-peg-wellposition" not in header_fields:
    raise SystemExit("[ERROR] donor cel_headers.txt에 well column 없음")

# Previously broken 09 appended these columns even if genuine AxAS did not have them.
# This universal candidate does NOT append anything.
print("[CHECK] donor cel_headers columns = {}".format(len(header_fields)))
print("[CHECK] cel_filepath column present = {}".format("cel_filepath" in header_fields))
print("[CHECK] cel_file_identifier column present = {}".format("cel_file_identifier" in header_fields))

donor_header_by_well = {}
for r in donor_header_rows:
    well = (r.get("affymetrix-plate-peg-wellposition") or "").upper()
    if well:
        donor_header_by_well[well] = r

donor_sample_by_well = {}
for r in donor_sample_rows:
    well = (r.get("affymetrix-plate-peg-wellposition") or "").upper()
    if well:
        donor_sample_by_well[well] = r

if len(donor_sample_by_well) != MAX_INPUT_N:
    raise SystemExit("[ERROR] donor sample_info unique wells != 96: {}".format(len(donor_sample_by_well)))
if len(donor_header_by_well) != MAX_INPUT_N:
    raise SystemExit("[ERROR] donor cel_headers unique wells != 96: {}".format(len(donor_header_by_well)))

# input은 96-CEL plate를 기준으로 한다. 실제 HMM/A5에는 QC PASS subset만 포함될 수 있다.
cel_paths = read_cel_list(cel_list_file)
if len(cel_paths) != MAX_INPUT_N:
    raise SystemExit("[ERROR] 현재 master pipeline은 96 input CEL 전용입니다. input CEL count={}".format(len(cel_paths)))

input_by_base = {}
input_well_by_base = {}
seen_input_well = set()
for path in cel_paths:
    base = basename_sample(path)
    well = extract_well(base)
    if not well:
        raise SystemExit("[ERROR] CEL filename에서 A01-H12 well 확인 불가: {}".format(base))
    if base in input_by_base:
        raise SystemExit("[ERROR] duplicate input CEL basename: {}".format(base))
    if well in seen_input_well:
        raise SystemExit("[ERROR] duplicate input well: {}".format(well))
    input_by_base[base] = path
    input_well_by_base[base] = well
    seen_input_well.add(well)

if seen_input_well != set(donor_sample_by_well):
    missing = sorted(set(donor_sample_by_well) - seen_input_well)
    extra = sorted(seen_input_well - set(donor_sample_by_well))
    raise SystemExit("[ERROR] input well set != donor 96-well layout. missing={} extra={}".format(missing, extra))

# AxiomHMM.report 순서를 A5의 sample 순서로 사용한다.
# QC fail이 있으면 여기서 96보다 작은 subset이 자동 선택된다.
hmm_by_base, hmm_order = read_hmm_report(hmm_report_file)
if not hmm_order:
    raise SystemExit("[ERROR] AxiomHMM.report.txt에서 current sample 목록을 읽지 못했습니다.")

current = []
seen_current = set()
for base in hmm_order:
    if base not in input_by_base:
        continue
    if base in seen_current:
        continue
    seen_current.add(base)
    current.append({
        "path": input_by_base[base],
        "base": base,
        "well": input_well_by_base[base],
    })

if not current:
    raise SystemExit("[ERROR] HMM report sample과 input CEL이 매칭되지 않습니다.")

current_bases = [x["base"] for x in current]
seen_well = set(x["well"] for x in current)

print("[CHECK] input CEL count = {}".format(len(cel_paths)))
print("[CHECK] HMM/A5 packaged sample count = {}".format(len(current)))
print("[CHECK] packaged unique wells = {}".format(len(seen_well)))

bs = "\\"
env_prefix = os.environ.get("AXAS_WINDOWS_CEL_PREFIX", "").strip()
if env_prefix:
    win_prefix = env_prefix.replace("/", bs)
    if not win_prefix.endswith(bs):
        win_prefix += bs
else:
    safe_run = re.sub(r"[^A-Za-z0-9_.-]+", "_", run_name)
    win_prefix = (
        "C:" + bs + "Users" + bs + "Public" + bs + "Documents" + bs +
        "AxiomAnalysisSuite" + bs + safe_run + bs
    )

new_sample_rows = []
new_header_rows = []
mapping_rows = []

for x in current:
    base = x["base"]
    well = x["well"]

    sr = dict(donor_sample_by_well[well])
    hr = dict(donor_header_by_well[well])
    hmm = hmm_by_base.get(base, {})

    plate = (
        hmm.get("affymetrix-plate-barcode", "")
        or hmm.get("affymetrix-array-barcode", "")
        or sr.get("affymetrix-plate-barcode", "")
    )

    donor_base = sr.get("cel_files", "")

    # Only fields required to synchronize current A5/sample identity are changed.
    # Verified donor cel_file_identifier / array-id are preserved.
    sr["cel_files"] = base
    sr["affymetrix-plate-peg-wellposition"] = well
    sr["cel_filepath"] = win_prefix + base
    if plate:
        sr["affymetrix-plate-barcode"] = plate

    # Preserve the genuine cel_headers column schema exactly.
    hr["cel_files"] = base
    hr["affymetrix-plate-peg-wellposition"] = well
    if plate:
        if "affymetrix-plate-barcode" in header_fields:
            hr["affymetrix-plate-barcode"] = plate
        if "affymetrix-array-barcode" in header_fields:
            hr["affymetrix-array-barcode"] = plate

    new_sample_rows.append(sr)
    new_header_rows.append(hr)
    mapping_rows.append((well, base, donor_base, plate))

with open(out_sample_info, "wb") as f:
    f.write(serialize_sample_info(sample_fields, new_sample_rows))

with open(out_cel_headers, "w", newline="") as f:
    writer = csv.DictWriter(
        f,
        fieldnames=header_fields,
        delimiter="\t",
        lineterminator="\r\n",
        extrasaction="ignore",
    )
    writer.writeheader()
    writer.writerows(new_header_rows)

with open(out_genotyping, "w", newline="") as f:
    f.write("cel_files\r\n")
    for x in current:
        f.write(win_prefix + x["base"] + "\r\n")

with open(out_map, "w", newline="") as f:
    f.write("well\tcurrent_cel\tdonor_cel\tplate_barcode\r\n")
    for well, current_base, donor_base, plate in mapping_rows:
        f.write("{}\t{}\t{}\t{}\r\n".format(well, current_base, donor_base, plate))

# strict post-write checks
_, fields2, rows2 = parse_sample_info(out_sample_info)
if fields2 != sample_fields or len(rows2) != len(current):
    raise SystemExit("[ERROR] output sample_info schema/count mismatch")

with open(out_cel_headers, "r", newline="") as f:
    rr = csv.reader(f, delimiter="\t")
    out_rows = list(rr)

if len(out_rows) != len(current) + 1:
    raise SystemExit("[ERROR] output cel_headers line count mismatch")
if out_rows[0] != header_fields:
    raise SystemExit("[ERROR] output cel_headers schema changed")

sample_info_names = [r["cel_files"] for r in rows2]
cel_header_names = [r[header_fields.index("cel_files")] for r in out_rows[1:]]

if sample_info_names != current_bases:
    raise SystemExit("[ERROR] sample_info sample order mismatch")
if cel_header_names != current_bases:
    raise SystemExit("[ERROR] cel_headers sample order mismatch")

print("[OK] sample_info.bin donor binary schema preserved")
print("[OK] cel_headers.txt donor column schema preserved")
print("[OK] current sample names/order synchronized")
print("[OK] Windows prefix = {}".format(win_prefix))
print("[OK] mapping = {}".format(out_map))
PY

echo
echo "[5] Logs 복사"
if [ -d "$OUT/logs" ]; then
  cp -a "$OUT/logs/." "$AXAS_DIR/Logs/" 2>/dev/null || true
fi

echo
echo "[6] AxAS Copy Number Discovery root cleanup"

# 실제 AxAS에서 MAPD by Plate가 정상 표시되도록,
# 최종 AxAS batch root에는 아래 파일을 남기지 않는다.
rm -f \
  "$AXAS_DIR/axas_sample_name_map.tsv" \
  "$AXAS_DIR/AxiomGT1.calls.txt" \
  "$AXAS_DIR/AxiomGT1.confidences.txt" \
  "$AXAS_DIR/AxiomGT1.report.txt" \
  "$AXAS_DIR/AxiomGT1.summary.a5"

echo "[OK] AxAS root cleanup 완료"

echo
echo "[7] 최종 검증"

SRC_A5_SHA="$(sha256sum "$SRC_07/AxiomHMM.cnv.a5" | awk '{print $1}')"
DST_A5_SHA="$(sha256sum "$AXAS_DIR/CNData/AxiomHMM.cnv.a5" | awk '{print $1}')"

echo "[CHECK] A5 source   = $SRC_A5_SHA"
echo "[CHECK] A5 packaged = $DST_A5_SHA"

if [ "$SRC_A5_SHA" != "$DST_A5_SHA" ]; then
  echo "[ERROR] AxiomHMM.cnv.a5 checksum mismatch"
  exit 1
fi

python3 - "$AAS_DATA/sample_info.bin" <<'PY'
from __future__ import print_function
import struct, sys
d = open(sys.argv[1], "rb").read()
count = struct.unpack("<I", d[:4])[0]
print("[CHECK] sample_count={}".format(count))
print("[CHECK] first20={}".format(d[:20]))
if count <= 0 or count > 96:
    raise SystemExit("[ERROR] invalid sample_count")
if d[4:14] != b"\tcel_files":
    raise SystemExit("[ERROR] sample_info header invalid")
PY

echo "[CHECK] cel_headers_lines=$(wc -l < "$AAS_DATA/cel_headers.txt")"
echo "[CHECK] genotyping_lines=$(wc -l < "$AXAS_DIR/genotyping_cel_files.txt")"

SAMPLE_COUNT="$(python3 - "$AAS_DATA/sample_info.bin" <<'PY'
import struct, sys
d=open(sys.argv[1],'rb').read()
print(struct.unpack('<I', d[:4])[0])
PY
)"

if [ "$(wc -l < "$AAS_DATA/cel_headers.txt")" -ne "$((SAMPLE_COUNT + 1))" ]; then
  echo "[ERROR] cel_headers.txt line count mismatch"
  exit 1
fi

if [ "$(wc -l < "$AXAS_DIR/genotyping_cel_files.txt")" -ne "$((SAMPLE_COUNT + 1))" ]; then
  echo "[ERROR] genotyping_cel_files.txt line count mismatch"
  exit 1
fi

if find "$AAS_DATA" -maxdepth 1 -type f \
  \( -name 'All_genotypes_by_snps.CHP.bin' -o -name 'All_genotypes_by_snps.CHP.index.txt' \) \
  -print | grep -q .; then
  echo "[ERROR] stale All_genotypes_by_snps 파일이 남아 있습니다."
  exit 1
fi

echo
echo "[CHECK] MAPD by Plate 방해 root 파일 없음"

FORBIDDEN_FAIL=0
for f in \
  axas_sample_name_map.tsv \
  AxiomGT1.calls.txt \
  AxiomGT1.confidences.txt \
  AxiomGT1.report.txt \
  AxiomGT1.summary.a5
do
  if [ -e "$AXAS_DIR/$f" ]; then
    echo "[ERROR] 남아 있음: $AXAS_DIR/$f"
    FORBIDDEN_FAIL=1
  else
    echo "[OK] 없음: $f"
  fi
done

if [ "$FORBIDDEN_FAIL" -ne 0 ]; then
  echo "[ERROR] AxAS root cleanup 검증 실패"
  exit 1
fi

echo
echo "[INFO] axas_sample_name_map.tsv는 AxAS batch 밖에 저장:"
echo "[INFO] $OUT/axas_sample_name_map.tsv"

echo
echo "============================================================"
echo "[DONE] AxAS production batch 생성 완료"
echo "[DONE] $AXAS_DIR"
echo "[NOTE] 최종 AxAS batch root에서 AxiomGT1 4종 및 axas_sample_name_map.tsv 제거 적용"
echo "============================================================"
