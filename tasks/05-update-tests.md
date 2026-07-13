# Task: Update Tests for New Features

## Context

Plugin at `/Users/q/code/experiments/nvim-agent-panel/`. Tests in `tests/`. Currently 16 tests pass.

After tasks 01-04 are done, tests need updating.

## Goal

All new behavior has test coverage, all tests pass.

## Requirements

### New test cases to add:

1. **Navigation** (in `tests/layout_spec.lua`):
   - `focus("sidebar")` → `focus("main")` → `focus("input")` cycles correctly
   - Focus wraps: from input, `Ctrl+l` goes to sidebar (or stops — define behavior)

2. **Input submit** (new `tests/input_spec.lua` or in layout_spec):
   - Set input buffer lines to `{"hello"}`
   - Trigger submit
   - Assert main buffer contains `"hello"` in one of the chat lines

3. **Sidebar selection** (in `tests/layout_spec.lua`):
   - Set sidebar cursor to a valid item line
   - Trigger `<CR>`
   - Assert notification was sent (stub `vim.notify`)

4. **Scroll** (in `tests/layout_spec.lua`):
   - Add content to main, call auto-scroll
   - Assert cursor is at last line

5. **All existing tests still pass**

## Run tests

```bash
cd /Users/q/code/experiments/nvim-agent-panel && LAZY_OFFLINE=1 make test
```

Expected: 0 failures.

## After done

Commit: `test: add coverage for navigation, input, sidebar, scroll`
