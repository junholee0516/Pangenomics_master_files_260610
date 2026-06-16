#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="/BiO/Pangenomics_master_files_260610/output/cnv_runs"
TO="_@_.com"

RUN_DIR="${1:-}"

# 인자를 안 주면 가장 최근 run 폴더 자동 선택
if [[ -z "$RUN_DIR" ]]; then
    RUN_DIR="$(find "$BASE_DIR" -mindepth 1 -maxdepth 1 -type d -printf '%T@ %p\n' \
        | sort -nr \
        | head -n 1 \
        | cut -d' ' -f2-)"
fi

RUN_DIR="${RUN_DIR%/}"
RUN_NAME="$(basename "$RUN_DIR")"

ABNORMAL_FILE="$RUN_DIR/08_final_tables/Discovery_CNV_abnormal_segments.tsv"
TIMES_FILE="$RUN_DIR/pipeline_step_times.tsv"
SENT_FLAG="$RUN_DIR/.abnormal_cnv_email_sent"

if [[ -f "$SENT_FLAG" ]]; then
    echo "[SKIP] 이미 이메일 발송 완료: $RUN_NAME"
    exit 0
fi

if [[ ! -f "$ABNORMAL_FILE" ]]; then
    echo "[SKIP] 파일 없음: $ABNORMAL_FILE"
    exit 0
fi

if [[ ! -f "$TIMES_FILE" ]]; then
    echo "[ERROR] 파일 없음: $TIMES_FILE"
    exit 1
fi

# Discovery_CNV_abnormal_segments.tsv 에 header 제외 실제 데이터가 있는지 확인
if ! awk -F'\t' '
NR > 1 {
    line = $0
    gsub(/[[:space:]]/, "", line)
    if (line != "") {
        found = 1
        exit
    }
}
END {
    exit(found ? 0 : 1)
}
' "$ABNORMAL_FILE"; then
    echo "[SKIP] abnormal CNV 데이터 없음: $ABNORMAL_FILE"
    exit 0
fi

# elapsed_hms 컬럼 전체 합계 + end_time 마지막 값 추출
if ! RESULT="$(awk -F'\t' '
function trim(s) {
    gsub(/^[ \t\r\n]+/, "", s)
    gsub(/[ \t\r\n]+$/, "", s)
    return s
}

function hms_to_sec(t, a, n, h, m, s) {
    t = trim(t)
    if (t == "") return 0

    n = split(t, a, ":")

    if (n == 3) {
        h = a[1]
        m = a[2]
        s = a[3]
    } else if (n == 2) {
        h = 0
        m = a[1]
        s = a[2]
    } else if (n == 1) {
        h = 0
        m = 0
        s = a[1]
    } else {
        return 0
    }

    return int(h) * 3600 + int(m) * 60 + int(s)
}

NR == 1 {
    for (i = 1; i <= NF; i++) {
        col = trim($i)
        if (col == "elapsed_hms") elapsed_col = i
        if (col == "end_time") end_col = i
    }

    if (elapsed_col == "") {
        print "ERROR\telapsed_hms 컬럼 없음"
        exit 2
    }

    if (end_col == "") {
        print "ERROR\tend_time 컬럼 없음"
        exit 3
    }

    next
}

NR > 1 {
    total += hms_to_sec($elapsed_col)

    end_value = trim($end_col)
    if (end_value != "") {
        last_end_time = end_value
    }
}

END {
    h = int(total / 3600)
    m = int((total % 3600) / 60)
    s = total % 60

    printf "%02d:%02d:%02d\t%s\n", h, m, s, last_end_time
}
' "$TIMES_FILE")"; then
    echo "[ERROR] pipeline_step_times.tsv 파싱 실패"
    exit 1
fi

TOTAL_HMS="$(echo "$RESULT" | cut -f1)"
LAST_END_TIME="$(echo "$RESULT" | cut -f2-)"

SUBJECT="${RUN_NAME} 파일이 완료 되었습니다."

BODY="$(cat <<BODY_EOF
${RUN_NAME} 파일이 완료 되었습니다.

걸린시간: ${TOTAL_HMS}
완료시간: ${LAST_END_TIME}

결과 폴더:
${RUN_DIR}

Abnormal CNV 결과 파일:
${ABNORMAL_FILE}
BODY_EOF
)"

if command -v mail >/dev/null 2>&1; then
    echo "$BODY" | mail -s "$SUBJECT" "$TO"
elif command -v mailx >/dev/null 2>&1; then
    echo "$BODY" | mailx -s "$SUBJECT" "$TO"
else
    echo "[ERROR] mail 또는 mailx 명령어가 없습니다."
    exit 1
fi

touch "$SENT_FLAG"

echo "[DONE] 이메일 발송 완료: $TO"
echo "[INFO] 제목: $SUBJECT"
echo "[INFO] 걸린시간: $TOTAL_HMS"
echo "[INFO] 완료시간: $LAST_END_TIME"
