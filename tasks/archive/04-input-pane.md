# Task: Input Pane Behavior

## Context

Plugin at `/Users/q/code/experiments/nvim-agent-panel/`. Input pane is the bottom pane. Currently shows "Ask me anything..." as static text.

Layout in `lua/agent-panel/layout.lua`, pane abstraction in `lua/agent-panel/pane.lua`.

## Goal

Input pane works like a mini command line — submit messages, auto-grow, placeholder.

## Requirements

1. **Placeholder**: show dimmed "Ask me anything..." when buffer is empty
   - Use extmark with `hl_group = "Comment"` and `virt_text_pos = "overlay"`
   - Disappear on entering insert mode or when text exists
   - Reappear when buffer becomes empty
2. **`<CR>` in insert mode** → submit:
   - Get input text from buffer
   - Append to main pane as:
     ```
     ┌─ You ────────────────────────
     │
     │  <input text>
     │
     └──────────────────────────────
     ```
   - Clear input buffer
   - Auto-scroll main to bottom
3. **`<S-CR>` in insert mode** → newline in input (don't submit)
   - Map `<S-CR>` to `<CR>` literally (just insert newline)
4. **`<C-c>` in insert mode** → clear input, go to normal mode
5. **Auto-grow height**: input starts at 3 lines, grows to max 5 as user types
   - Use `TextChangedI` autocmd to count lines in buffer
   - If lines > current height → call `nvim_win_set_config` to increase height
   - If lines decrease → shrink back (min 3)
6. **`<Esc>` in insert mode** → normal mode (already exists, verify)

## Implementation notes

- For `<S-CR>` in terminal: may need to map `<S-CR>` or check if terminal sends different code. Fallback: use `<C-o>o` or just `<CR>` for newline if shift-enter doesn't work.
- Placeholder extmark: set on buffer open, clear on `InsertEnter`, re-check on `InsertLeave` and `TextChanged`
- Auto-grow: recalculate in `layout.lua` update function, or have input pane handle its own resize

## After done

1. Run `cd /Users/q/code/experiments/nvim-agent-panel && LAZY_OFFLINE=1 make test`
2. Commit: `feat: input pane with submit, placeholder, and auto-grow`
