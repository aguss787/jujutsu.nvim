# jujutsu.nvim

A Neovim plugin for the [Jujutsu](https://github.com/jj-vcs/jj) version control system.

## Requirements

- Neovim 0.10+
- [`jj`](https://github.com/jj-vcs/jj) installed and in `$PATH`
- [noice.nvim](https://github.com/folke/noice.nvim) (optional, for progress notifications on fetch/push)

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

Open the bookmark list buffer:

```
:Jj bookmark
```

The log and bookmark buffers share the same window — opening one replaces the other in the same split.

## Shared Keymaps

These keymaps are available in both the log and bookmark buffers:

| Key    | Action                     |
|--------|----------------------------|
| `gl`   | Switch to log buffer       |
| `gb`   | Switch to bookmark buffer  |
| `<C-r>` | Refresh the buffer        |

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
| `bs`   | `jj bookmark set` on revision under cursor          |
| `bd`   | `jj bookmark delete` on revision under cursor       |
| `bm`   | `jj bookmark move` from marked rev(s) to cursor rev |
| `bM`   | `jj bookmark move -B` (allow backwards/sideways)    |
| `bt`   | `jj bookmark track` (appends `@origin` if no `@`)  |
| `bT`   | `jj bookmark untrack` (appends `@origin` if no `@`) |
| `gf`   | `jj git fetch`                                      |
| `gp`   | `jj git push -r` revision(s)                        |
| `gP`   | `jj git push --all --deleted`                       |
| `d`    | Edit revision description                           |
| `p`    | `jj duplicate --onto` marked destination(s)         |
| `P`    | `jj duplicate` with destination mode picker         |

### Marks

Press `m` to mark revisions. Marks are used differently depending on the operation:

- **Source revisions:** `n`, `a` act on all marked revisions instead of the cursor revision.
- **Destination revisions:** `r`, `R`, `p`, `P` use marks as the destination to rebase/duplicate onto. `s` squashes the cursor revision into the single marked destination. `bm`, `bM` move bookmarks from marked revision(s) to the cursor revision.

Press `M` to clear all marks.

### Rebase Mode Picker (`R`)

Opens two selection menus to choose the rebase mode:

- **Source:** `-s` (revision + descendants), `-r` (single revision), `-b` (entire branch)
- **Destination:** `-d` (rebase onto), `--before` (insert before), `--after` (insert after)

### Duplicate Mode Picker (`P`)

Opens a selection menu to choose the destination mode:

- `--onto` (duplicate onto destination), `--insert-after` (insert after), `--insert-before` (insert before)

## Bookmark Buffer Keymaps

| Key | Action                                                    |
|-----|-----------------------------------------------------------|
| `d` | `jj bookmark delete` the bookmark under cursor              |
| `t` | `jj bookmark track` the bookmark under cursor (`@origin`)   |
| `T` | `jj bookmark untrack` the bookmark under cursor (`@origin`) |
| `u` | `jj undo`                                                    |

## Configuration

The log buffer opens in a vertical split (left/right) by default. To use a horizontal split (top/bottom):

```lua
require("jujutsu").setup({
  split = "horizontal",
})
```

All keymaps can be remapped or disabled. Only the keys you specify are overridden; the rest keep their defaults.

```lua
require("jujutsu").setup({
  keymaps = {
    log = {
      edit        = "<CR>",
      mark        = "m",
      clear_marks = "M",
      new         = "n",
      abandon     = "a",
      squash      = "s",
      rebase      = "r",
      rebase_pick = "R",
      undo        = "u",
      bookmark_set = "bs",
      bookmark_delete = "bd",
      bookmark_move = "bm",
      bookmark_move_backwards = "bM",
      bookmark_track = "bt",
      bookmark_untrack = "bT",
      git_fetch   = "gf",
      git_push    = "gp",
      git_push_all = "gP",
      describe    = "d",
      duplicate   = "p",
      duplicate_pick = "P",
      goto_log    = "gl",
      goto_bookmark = "gb",
      refresh     = "<C-r>",
    },
    bookmark = {
      delete      = "d",
      track       = "t",
      untrack     = "T",
      undo        = "u",
      goto_log    = "gl",
      goto_bookmark = "gb",
      refresh     = "<C-r>",
    },
  },
})
```

Set a keymap to `false` to disable it:

```lua
require("jujutsu").setup({
  keymaps = {
    log = {
      abandon = false, -- disable the abandon keymap
    },
  },
})
```
