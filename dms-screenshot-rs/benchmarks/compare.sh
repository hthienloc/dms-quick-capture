#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NEW_BIN="${NEW_BIN:-$ROOT_DIR/target/release/dms-screenshot-rs}"
OLD_BIN="${OLD_BIN:-dms}"
MODE="${MODE:-full}"
ITERATIONS="${ITERATIONS:-10}"
WARMUPS="${WARMUPS:-2}"
OUTPUT_DIR="${OUTPUT_DIR:-${TMPDIR:-/tmp}/dms-screenshot-benchmark}"

if ! command -v "$OLD_BIN" >/dev/null 2>&1; then
    echo "Old backend not found: $OLD_BIN" >&2
    exit 1
fi
if [[ ! -x "$NEW_BIN" ]]; then
    echo "New backend binary not found: $NEW_BIN" >&2
    echo "Build it with: cargo build --release" >&2
    exit 1
fi
if ! [[ "$ITERATIONS" =~ ^[1-9][0-9]*$ && "$WARMUPS" =~ ^[0-9]+$ ]]; then
    echo "ITERATIONS must be positive and WARMUPS must be non-negative" >&2
    exit 1
fi
if [[ "$MODE" != "full" && "$MODE" != "last" ]]; then
    echo "MODE must be full or last" >&2
    exit 1
fi
if [[ "$MODE" == "last" ]]; then
    STATE_FILE="${XDG_CACHE_HOME:-${HOME}/.cache}/dms/screenshot-state.json"
    if [[ ! -s "$STATE_FILE" ]]; then
        echo "Saved last region not found: $STATE_FILE" >&2
        exit 1
    fi
fi
mkdir -p "$OUTPUT_DIR"

run_backend() {
    local backend="$1"
    local filename="$2"
    if [[ "$backend" == "old" ]]; then
        "$OLD_BIN" screenshot "$MODE" \
            --no-clipboard --no-notify --dir "$OUTPUT_DIR" \
            --filename "$filename" --json >/dev/null
    else
        "$NEW_BIN" "$MODE" \
            --no-clipboard --no-notify --dir "$OUTPUT_DIR" \
            --filename "$filename" --json >/dev/null
    fi
}

measure_backend() {
    local backend="$1"
    local samples_file="$2"
    local i start end
    : > "$samples_file"

    for ((i = 1; i <= WARMUPS; i++)); do
        run_backend "$backend" "warmup-${backend}-${i}.png"
    done

    for ((i = 1; i <= ITERATIONS; i++)); do
        start="$(date +%s%N)"
        run_backend "$backend" "sample-${backend}-${i}.png"
        end="$(date +%s%N)"
        printf '%s\n' "$((end - start))" >> "$samples_file"
    done
}

summarize() {
    awk '
        { values[NR] = $1; sum += $1; if (NR == 1 || $1 < min) min = $1 }
        END {
            n = NR
            for (i = 1; i <= n; i++) for (j = i + 1; j <= n; j++)
                if (values[j] < values[i]) { t = values[i]; values[i] = values[j]; values[j] = t }
            if (n % 2) median = values[(n + 1) / 2]
            else median = (values[n / 2] + values[n / 2 + 1]) / 2
            printf "%.2f %.2f %.2f\n", min / 1000000, median / 1000000, sum / n / 1000000
        }
    ' "$1"
}

OLD_SAMPLES="$OUTPUT_DIR/old.samples"
NEW_SAMPLES="$OUTPUT_DIR/new.samples"
measure_backend old "$OLD_SAMPLES"
measure_backend new "$NEW_SAMPLES"

read -r OLD_MIN OLD_MEDIAN OLD_AVG <<< "$(summarize "$OLD_SAMPLES")"
read -r NEW_MIN NEW_MEDIAN NEW_AVG <<< "$(summarize "$NEW_SAMPLES")"

cat <<EOF
Screenshot backend benchmark
Date: $(date --iso-8601=seconds)
Mode: $MODE$([[ "$MODE" == "last" ]] && printf ' (reference only; backend state mapping may differ)' || true)
Iterations: $ITERATIONS (warmups: $WARMUPS)
Output: $OUTPUT_DIR

| Backend | Min (ms) | Median (ms) | Average (ms) |
|---|---:|---:|---:|
| Old ($OLD_BIN) | $OLD_MIN | $OLD_MEDIAN | $OLD_AVG |
| New ($NEW_BIN) | $NEW_MIN | $NEW_MEDIAN | $NEW_AVG |
EOF
