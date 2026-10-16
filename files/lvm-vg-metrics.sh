#!/bin/bash
# LVM volume and dependency prometheus textfile collector.
# Managed by the otakup0pe.lvm ansible role -- do not edit on the host.
#
# Usage: lvm-vg-metrics.sh [textfile_dir] [expectations_dir] [mapper_dir]
# Writes <textfile_dir>/lvm_vg.prom via tmp+rename so node_exporter never
# reads a partial file.
set -uo pipefail

TEXTFILE_DIR="${1:-/var/lib/node_exporter/textfile_collector}"
EXPECTATIONS_DIR="${2:-/etc/lvm-vg-metrics.d}"
MAPPER_DIR="${3:-/dev/mapper}"
PROM_FILE="${TEXTFILE_DIR}/lvm_vg.prom"
TMP_FILE="$(mktemp "${PROM_FILE}.XXXXXX")" || exit 1
trap 'rm -f "${TMP_FILE}"' EXIT

success=1
declare -A actual_vgs=()
declare -A actual_lvs=()
declare -A expected_vgs=()
declare -A expected_lvs=()
declare -A expected_mappers=()

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
        actual_vgs["${vg_name}"]=1
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

if lv_output="$(lvs --noheadings --separator '|' -o vg_name,lv_name 2>/dev/null)"; then
    while IFS='|' read -r vg_name lv_name; do
        vg_name="${vg_name//[[:space:]]/}"
        lv_name="${lv_name//[[:space:]]/}"
        if [ -n "${vg_name}" ] && [ -n "${lv_name}" ]; then
            actual_lvs["${vg_name}|${lv_name}"]=1
        fi
    done <<< "${lv_output}"
else
    success=0
fi

shopt -s nullglob
for expectations_file in "${EXPECTATIONS_DIR}"/*.conf; do
    while read -r record_type vg_name lv_name mapper_name extra ||
            [ -n "${record_type:-}" ]; do
        if [ -z "${record_type:-}" ] || [[ "${record_type}" = \#* ]]; then
            continue
        fi
        case "${record_type}" in
            vg)
                if [ -n "${vg_name:-}" ] && [ -z "${lv_name:-}" ] &&
                        [[ "${vg_name}" =~ ^[A-Za-z0-9+_.-]+$ ]]; then
                    expected_vgs["${vg_name}"]=1
                else
                    success=0
                fi
                ;;
            lv)
                if [ -n "${vg_name:-}" ] && [ -n "${lv_name:-}" ] &&
                        [ -z "${mapper_name:-}" ] &&
                        [[ "${vg_name}" =~ ^[A-Za-z0-9+_.-]+$ ]] &&
                        [[ "${lv_name}" =~ ^[A-Za-z0-9+_.-]+$ ]]; then
                    expected_lvs["${vg_name}|${lv_name}"]=1
                else
                    success=0
                fi
                ;;
            mapper)
                if [ -n "${vg_name:-}" ] && [ -n "${lv_name:-}" ] &&
                        [ -n "${mapper_name:-}" ] && [ -z "${extra:-}" ] &&
                        [[ "${vg_name}" =~ ^[A-Za-z0-9+_.-]+$ ]] &&
                        [[ "${lv_name}" =~ ^[A-Za-z0-9+_.-]+$ ]] &&
                        [[ "${mapper_name}" =~ ^[A-Za-z0-9+_.-]+$ ]]; then
                    expected_mappers["${vg_name}|${lv_name}|${mapper_name}"]=1
                else
                    success=0
                fi
                ;;
            *)
                success=0
                ;;
        esac
    done < "${expectations_file}"
done

{
    echo '# HELP lvm_expected_vg_present Whether an expected LVM volume group is present.'
    echo '# TYPE lvm_expected_vg_present gauge'
    while IFS= read -r vg_name; do
        [ -n "${vg_name}" ] || continue
        present=0
        if [ -n "${actual_vgs[${vg_name}]+set}" ]; then
            present=1
        fi
        printf 'lvm_expected_vg_present{vg="%s"} %s\n' "${vg_name}" "${present}"
    done < <(printf '%s\n' "${!expected_vgs[@]}" | sort)

    echo '# HELP lvm_expected_lv_present Whether an expected LVM logical volume is present.'
    echo '# TYPE lvm_expected_lv_present gauge'
    while IFS='|' read -r vg_name lv_name; do
        [ -n "${vg_name}" ] || continue
        present=0
        if [ -n "${actual_lvs[${vg_name}|${lv_name}]+set}" ]; then
            present=1
        fi
        printf 'lvm_expected_lv_present{vg="%s",lv="%s"} %s\n' \
            "${vg_name}" "${lv_name}" "${present}"
    done < <(printf '%s\n' "${!expected_lvs[@]}" | sort)

    echo '# HELP lvm_expected_mapper_present Whether an expected device-mapper path is present.'
    echo '# TYPE lvm_expected_mapper_present gauge'
    while IFS='|' read -r vg_name lv_name mapper_name; do
        [ -n "${vg_name}" ] || continue
        present=0
        if [ -e "${MAPPER_DIR}/${mapper_name}" ]; then
            present=1
        fi
        printf 'lvm_expected_mapper_present{vg="%s",lv="%s",mapper="%s"} %s\n' \
            "${vg_name}" "${lv_name}" "${mapper_name}" "${present}"
    done < <(printf '%s\n' "${!expected_mappers[@]}" | sort)

    echo '# HELP lvm_metrics_scrape_success Whether the lvm collector ran cleanly (1) or hit an error (0).'
    echo '# TYPE lvm_metrics_scrape_success gauge'
    echo "lvm_metrics_scrape_success ${success}"
    echo '# HELP lvm_metrics_last_run_timestamp Unix timestamp of the last collector run.'
    echo '# TYPE lvm_metrics_last_run_timestamp gauge'
    echo "lvm_metrics_last_run_timestamp $(date +%s)"
} >> "${TMP_FILE}"

chmod 0644 "${TMP_FILE}"
mv "${TMP_FILE}" "${PROM_FILE}"
trap - EXIT
