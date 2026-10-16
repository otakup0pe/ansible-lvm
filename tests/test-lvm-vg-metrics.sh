#!/bin/bash
set -euo pipefail

ROLE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COLLECTOR="${ROLE_ROOT}/files/lvm-vg-metrics.sh"
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf "${TEST_ROOT}"' EXIT

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

assert_line() {
    local expected="$1"
    local file="$2"
    grep -Fqx -- "${expected}" "${file}" ||
        fail "missing line: ${expected}"
}

mkdir -p "${TEST_ROOT}/bin" "${TEST_ROOT}/expectations" \
    "${TEST_ROOT}/mapper" "${TEST_ROOT}/textfiles"

cat > "${TEST_ROOT}/bin/vgs" <<'EOF'
#!/bin/bash
if [ "${TEST_VGS_FAIL:-0}" = 1 ]; then
    exit 1
fi
printf '%s\n' "${TEST_VGS_OUTPUT:-}"
EOF

cat > "${TEST_ROOT}/bin/lvs" <<'EOF'
#!/bin/bash
if [ "${TEST_LVS_FAIL:-0}" = 1 ]; then
    exit 1
fi
printf '%s\n' "${TEST_LVS_OUTPUT:-}"
EOF

chmod +x "${TEST_ROOT}/bin/vgs" "${TEST_ROOT}/bin/lvs"

cat > "${TEST_ROOT}/expectations/vg0.conf" <<'EOF'
vg vg0
lv vg0 data-crypto
mapper vg0 data-crypto data
lv vg0 logs-crypto
mapper vg0 logs-crypto logs
EOF

cat > "${TEST_ROOT}/expectations/vg1.conf" <<'EOF'
vg vg1
lv vg1 archive
EOF

touch "${TEST_ROOT}/mapper/data"

export PATH="${TEST_ROOT}/bin:${PATH}"
export TEST_VGS_OUTPUT=$' vg0 |100|200\n ubuntu-vg |300|400'
export TEST_LVS_OUTPUT=$' vg0 |data-crypto\n vg1 |archive'

bash "${COLLECTOR}" "${TEST_ROOT}/textfiles" "${TEST_ROOT}/expectations" \
    "${TEST_ROOT}/mapper"

PROM_FILE="${TEST_ROOT}/textfiles/lvm_vg.prom"
assert_line 'lvm_expected_vg_present{vg="vg0"} 1' "${PROM_FILE}"
assert_line 'lvm_expected_vg_present{vg="vg1"} 0' "${PROM_FILE}"
assert_line 'lvm_expected_lv_present{vg="vg0",lv="data-crypto"} 1' "${PROM_FILE}"
assert_line 'lvm_expected_lv_present{vg="vg0",lv="logs-crypto"} 0' "${PROM_FILE}"
assert_line 'lvm_expected_lv_present{vg="vg1",lv="archive"} 1' "${PROM_FILE}"
assert_line 'lvm_expected_mapper_present{vg="vg0",lv="data-crypto",mapper="data"} 1' "${PROM_FILE}"
assert_line 'lvm_expected_mapper_present{vg="vg0",lv="logs-crypto",mapper="logs"} 0' "${PROM_FILE}"
assert_line 'lvm_metrics_scrape_success 1' "${PROM_FILE}"

export TEST_LVS_FAIL=1
bash "${COLLECTOR}" "${TEST_ROOT}/textfiles" "${TEST_ROOT}/expectations" \
    "${TEST_ROOT}/mapper"
assert_line 'lvm_expected_lv_present{vg="vg0",lv="data-crypto"} 0' "${PROM_FILE}"
assert_line 'lvm_metrics_scrape_success 0' "${PROM_FILE}"

printf 'PASS: lvm metrics collector expectations\n'
