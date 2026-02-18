# jujutsu.nvim

A Neovim plugin for the [Jujutsu](https://github.com/jj-vcs/jj) version control system.

## Requirements

- Neovim 0.10+
- [`jj`](https://github.com/jj-vcs/jj) installed and in `$PATH`

## Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "agus/jujutsu.nvim",
  config = function()
    require("jujutsu").setup()
  end,
}
```

## Usage

Open the log buffer:

```
:Jj
:Jj log
```

## Log Buffer Keymaps

| Key    | Action                                              |
|--------|-----------------------------------------------------|
| `<CR>` | `jj edit` the revision under cursor                 |
| `m`    | Toggle mark on revision under cursor                |
| `M`    | Clear all marks                                     |
| `n`    | `jj new` from revision(s)                           |
| `a`    | `jj abandon` revision(s)                            |
| `s`    | `jj squash` into parent, or into single marked rev  |
| `r`    | `jj rebase -s` revision onto marked destination(s)  |
| `R`    | `jj rebase` with source/destination mode picker     |
| `u`    | `jj undo`                                           |
| `d`    | Edit revision description                           |
| `<C-r>` | Refresh the log buffer                             |

### Marks

Press `m` to mark revisions. When marks are set, operations like `n`, `a`, `r`, and `R` act on all marked revisions instead of the one under the cursor. `s` squashes the cursor revision into the single marked destination. Press `M` to clear all marks.

### Rebase Mode Picker (`R`)

Opens two selection menus to choose the rebase mode:

- **Source:** `-s` (revision + descendants), `-r` (single revision), `-b` (entire branch)
- **Destination:** `-d` (rebase onto), `--before` (insert before), `--after` (insert after)

## Configuration

All keymaps can be remapped or disabled. Only the keys you specify are overridden; the rest keep their defaults.

```lua
require("jujutsu").setup({
  keymaps = {
    edit        = "<CR>",
    mark        = "m",
    clear_marks = "M",
    new         = "n",
    abandon     = "a",
    squash      = "s",
    rebase      = "r",
    rebase_pick = "R",
    undo        = "u",
    describe    = "d",
    refresh     = "<C-r>",
  },
})
```

Set a keymap to `false` to disable it:

```lua
require("jujutsu").setup({
  keymaps = {
    abandon = false, -- disable the abandon keymap
  },
})
```
