.PHONY: test test-shell

test: test-shell

test-shell:
	bash -n files/lvm-vg-metrics.sh tests/test-lvm-vg-metrics.sh
	shellcheck files/lvm-vg-metrics.sh tests/test-lvm-vg-metrics.sh
	bash tests/test-lvm-vg-metrics.sh
