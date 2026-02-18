# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Development Commands

Format Lua code (requires [stylua](https://github.com/JohnnyMorganz/StyLua)):
```sh
stylua lua/ plugin/
```

Generate help tags from within Neovim:
```vim
:helptags doc/
```

Load the plugin into a running Neovim instance for testing:
```vim
:lua vim.opt.rtp:prepend("~/src/jujutsu.nvim")
:source ~/src/jujutsu.nvim/plugin/jujutsu.lua
:lua require("jujutsu").setup()
```

Reload the Lua module after changes (without restarting Neovim):
```vim
:lua package.loaded["jujutsu"] = nil; require("jujutsu").setup()
```

## Architecture

**Entry point:** `plugin/jujutsu.lua` — auto-sourced by Neovim at startup. Contains the plugin guard and registers the `:Jj` user command with subcommand routing. New commands go here.

**Core logic:** `lua/jujutsu/init.lua` — exposes `M.setup()` and feature functions (currently `M.log()`). The pattern is: one public function per feature, called from `plugin/jujutsu.lua`.

**Syntax highlighting:** `syntax/jjlog.vim` — loaded automatically when `vim.bo[buf].filetype = "jjlog"` is set. Defines highlight groups for `jj log` output (graph characters, change IDs, emails, dates, commit IDs, special markers).

**Adding a new subcommand:**
1. Add the function to `lua/jujutsu/init.lua`
2. Add a branch to the `if/elseif` chain in `plugin/jujutsu.lua`
3. Add the subcommand name to the `complete` return table in `plugin/jujutsu.lua`

**Key conventions:**
- Use `vim.system({ "jj", ... }, { text = true }):wait()` for all `jj` invocations
- Log buffers are scratch buffers (`vim.api.nvim_create_buf(false, true)`) with `bufhidden = "wipe"` and `modifiable = false` except during refresh
- Buffer-local keymaps use `{ buffer = buf }` — never set global keymaps from within feature functions
- `refresh_log_buf(buf)` pattern: temporarily set `modifiable = true`, update lines, set back to `false`
- **Do not duplicate code.** Extract repeated logic into constants, helpers, or shared functions. If you find yourself copy-pasting, refactor instead.

## Testing

Run the test suite:
```sh
make test
```

**Every new feature must have tests.** Add them to the appropriate file in `tests/`:
- `test_init_spec.lua` — config and setup behaviour
- `test_log_buffer_spec.lua` — buffer state and keymap registration
- `test_jj_calls_spec.lua` — jj command invocations (mock `vim.system` and assert the exact args)

When adding a new jj operation, add a test to `test_jj_calls_spec.lua` that mocks `vim.system`, triggers the keymap callback via `get_cb(buf, key)()`, and asserts the correct command was captured.

**When fixing a bug, first add a failing test that reproduces the bug, then fix it.** This ensures the bug stays fixed and prevents regressions.

**Update `README.md` after every feature.** Add new keymaps to the keymaps table, update the config example, and document any new behaviour (marks usage, picker modes, etc.).

## Version Control

This repo uses **Jujutsu (`jj`)** for version control (not plain git). Use `jj` commands for all VCS operations:
- `jj log` — view history
- `jj commit -m "msg"` — commit working copy
- `jj describe -r <rev> -m "msg"` — rewrite a commit message
- `jj diff` — show current changes

Commit messages follow **Conventional Commits** (`feat:`, `fix:`, `chore:`, etc.).
