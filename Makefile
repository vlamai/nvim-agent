.PHONY: test test-one lint format check dev clean

test:
	nvim -l tests/minit.lua --minitest $(FILE)

test-one:
	nvim -l tests/minit.lua --minitest tests/$(MODULE)_spec.lua

lint:
	stylua --check lua/ tests/

format:
	stylua lua/ tests/

check: lint test

dev:
	nvim -u repro/repro.lua

clean:
	find . -type d -name '.repro' -exec rm -rf {} +
	find . -type d -name '.tests' -exec rm -rf {} +
