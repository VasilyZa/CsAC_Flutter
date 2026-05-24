#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "Usage: $0 <flutter-linux-bundle-dir> <output-file>" >&2
  exit 2
fi

bundle_dir=$1
output_file=$2
app_name=${APP_NAME:-csac}

if [[ ! -x "$bundle_dir/$app_name" ]]; then
  echo "Missing executable: $bundle_dir/$app_name" >&2
  exit 1
fi

mkdir -p "$(dirname "$output_file")"

cat > "$output_file" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail

app_name="csac"
marker="__CSAC_SELF_EXTRACTING_PAYLOAD_BELOW__"
self_path=$(readlink -f "$0")
payload_line=$(awk -v marker="$marker" '$0 == marker {print NR + 1; exit 0;}' "$self_path")

if [[ -z "${payload_line:-}" ]]; then
  echo "Payload marker not found." >&2
  exit 1
fi

cache_root="${XDG_CACHE_HOME:-$HOME/.cache}/csac"
payload_hash=$(sha256sum "$self_path" | awk '{print $1}')
run_dir="$cache_root/self-contained/$payload_hash"
app_path="$run_dir/bundle/$app_name"

if [[ ! -x "$app_path" ]]; then
  rm -rf "$run_dir"
  mkdir -p "$run_dir"
  tail -n +"$payload_line" "$self_path" | tar -xz -C "$run_dir"
fi

exec "$app_path" "$@"
__CSAC_SELF_EXTRACTING_PAYLOAD_BELOW__
STUB

tar -C "$(dirname "$bundle_dir")" -czf - "$(basename "$bundle_dir")" >> "$output_file"
chmod +x "$output_file"
