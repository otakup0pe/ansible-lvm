.PHONY: lint test test-shell test-ubuntu2004 test-ubuntu2204 test-ubuntu2404 test-debian12 test-debian13 test-all test-clean clean distclean

VENV := .venv
BIN := $(VENV)/bin
export PATH := $(CURDIR)/$(BIN):$(PATH)

$(VENV): requirements-dev.txt
	python3 -m venv $(VENV)
	$(BIN)/pip install --upgrade pip
	$(BIN)/pip install -r requirements-dev.txt
	@touch $(VENV)

lint: $(VENV)
	$(BIN)/yamllint -c .yamllint defaults tasks handlers templates meta molecule .github
	$(BIN)/ansible-lint -c .ansible-lint defaults tasks handlers templates meta molecule

test: lint test-shell test-all

test-shell:
	bash -n files/lvm-vg-metrics.sh tests/test-lvm-vg-metrics.sh
	shellcheck files/lvm-vg-metrics.sh tests/test-lvm-vg-metrics.sh
	bash tests/test-lvm-vg-metrics.sh

test-ubuntu2004: $(VENV)
	MOLECULE_OS=ubuntu MOLECULE_VERSION=2004 $(BIN)/molecule test

test-ubuntu2204: $(VENV)
	MOLECULE_OS=ubuntu MOLECULE_VERSION=2204 $(BIN)/molecule test

test-ubuntu2404: $(VENV)
	MOLECULE_OS=ubuntu MOLECULE_VERSION=2404 $(BIN)/molecule test

test-debian12: $(VENV)
	MOLECULE_OS=debian MOLECULE_VERSION=12 $(BIN)/molecule test

test-debian13: $(VENV)
	MOLECULE_OS=debian MOLECULE_VERSION=13 $(BIN)/molecule test

test-all: test-ubuntu2004 test-ubuntu2204 test-ubuntu2404 test-debian12 test-debian13

test-clean: clean

clean:
	$(BIN)/molecule destroy 2>/dev/null || true

distclean: clean
	rm -rf $(VENV)
