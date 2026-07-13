#!/bin/bash
# LVM volume-group free/size prometheus textfile collector.
# Managed by the otakup0pe.lvm ansible role -- do not edit on the host.
#
# Usage: lvm-vg-metrics.sh [textfile_dir]
# Writes <textfile_dir>/lvm_vg.prom atomically (tmp + rename) so the
# node_exporter textfile collector never reads a partial file.
set -uo pipefail

TEXTFILE_DIR="${1:-/var/lib/node_exporter/textfile_collector}"
PROM_FILE="${TEXTFILE_DIR}/lvm_vg.prom"
TMP_FILE="$(mktemp "${PROM_FILE}.XXXXXX")" || exit 1
trap 'rm -f "${TMP_FILE}"' EXIT

success=1

{
    echo '# HELP lvm_vg_free_bytes Free space in the LVM volume group in bytes.'
    echo '# TYPE lvm_vg_free_bytes gauge'
    echo '# HELP lvm_vg_size_bytes Total size of the LVM volume group in bytes.'
    echo '# TYPE lvm_vg_size_bytes gauge'
} > "${TMP_FILE}"

# --nosuffix --units b => raw bytes; --noheadings => data rows only.
if vg_output="$(vgs --noheadings --nosuffix --units b --separator '|' \
        -o vg_name,vg_free,vg_size 2>/dev/null)"; then
    while IFS='|' read -r vg_name vg_free vg_size; do
        vg_name="${vg_name//[[:space:]]/}"
        vg_free="${vg_free//[[:space:]]/}"
        vg_size="${vg_size//[[:space:]]/}"
        if [ -z "${vg_name}" ]; then
            continue
        fi
        if [[ "${vg_free}" =~ ^[0-9]+$ ]] && [[ "${vg_size}" =~ ^[0-9]+$ ]]; then
            printf 'lvm_vg_free_bytes{vg="%s"} %s\n' "${vg_name}" "${vg_free}" >> "${TMP_FILE}"
            printf 'lvm_vg_size_bytes{vg="%s"} %s\n' "${vg_name}" "${vg_size}" >> "${TMP_FILE}"
        else
            success=0
        fi
    done <<< "${vg_output}"
else
    success=0
fi

{
    echo '# HELP lvm_metrics_scrape_success Whether the lvm vg collector ran cleanly (1) or hit an error (0).'
    echo '# TYPE lvm_metrics_scrape_success gauge'
    echo "lvm_metrics_scrape_success ${success}"
    echo '# HELP lvm_metrics_last_run_timestamp Unix timestamp of the last collector run.'
    echo '# TYPE lvm_metrics_last_run_timestamp gauge'
    echo "lvm_metrics_last_run_timestamp $(date +%s)"
} >> "${TMP_FILE}"

chmod 0644 "${TMP_FILE}"
mv "${TMP_FILE}" "${PROM_FILE}"
trap - EXIT
