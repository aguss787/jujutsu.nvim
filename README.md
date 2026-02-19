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
  "aguss787/jujutsu.nvim",
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

Open the operation log buffer:

```
:Jj op
```

The log, bookmark, and op buffers share the same window — opening one replaces the other in the same split.

## Shared Keymaps

These keymaps are available in the log, bookmark, and op buffers:

| Key     | Action                     |
|---------|----------------------------|
| `q`     | Close the buffer           |
| `gl`    | Switch to log buffer       |
| `gb`    | Switch to bookmark buffer  |
| `go`    | Switch to op buffer        |
| `<C-r>` | Refresh the buffer         |

## Log Buffer Keymaps

| Key    | Action                                              |
|--------|-----------------------------------------------------|
| `<CR>` | `jj edit` the revision under cursor                 |
| `m`    | Toggle mark on revision under cursor                |
| `M`    | Clear all marks                                     |
| `<C-n>`| `jj new` from revision(s)                           |
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

Press `m` to mark revisions or bookmarks. Marks are used differently depending on the operation:

- **Source revisions:** `<C-n>`, `a` act on all marked revisions instead of the cursor revision.
- **Destination revisions:** `r`, `R`, `p`, `P` use marks as the destination to rebase/duplicate onto. `s` squashes the cursor revision into the single marked destination. `bm`, `bM` move bookmarks from marked revision(s) to the cursor revision.
- **Bookmark buffer:** `d`, `t`, `T` act on all marked bookmarks instead of the cursor bookmark.

Press `M` to clear all marks.

### Rebase Mode Picker (`R`)

Opens two selection menus to choose the rebase mode:

- **Source:** `-s` (revision + descendants), `-r` (single revision), `-b` (entire branch)
- **Destination:** `-d` (rebase onto), `--before` (insert before), `--after` (insert after)

### Duplicate Mode Picker (`P`)

Opens a selection menu to choose the destination mode:

- `--onto` (duplicate onto destination), `--insert-after` (insert after), `--insert-before` (insert before)

## Bookmark Buffer Keymaps

| Key    | Action                                                    |
|--------|-----------------------------------------------------------|
| `<CR>` | `jj edit` bookmark under cursor and switch to log buffer  |
| `m`    | Toggle mark on bookmark under cursor                      |
| `M`    | Clear all marks                                           |
| `<C-n>`| `jj new` from the bookmark under cursor                   |
| `d`    | `jj bookmark delete` bookmark(s)                          |
| `t`    | `jj bookmark track` bookmark(s) (`@origin`)               |
| `T`    | `jj bookmark untrack` bookmark(s) (`@origin`)             |
| `r`    | Toggle between local only and all remote bookmarks        |
| `gf`   | `jj git fetch`                                            |
| `gp`   | `jj git push -b` the bookmark under cursor                |
| `gP`   | `jj git push --all --deleted`                             |
| `u`    | `jj undo`                                                 |

## Op Buffer Keymaps

| Key    | Action                                         |
|--------|------------------------------------------------|
| `<CR>` | `jj op restore` the operation under cursor     |
| `u`    | `jj undo`                                      |

## Configuration

The log buffer opens in a vertical split (left/right) by default. To use a horizontal split (top/bottom):

```lua
require("jujutsu").setup({
  split = "horizontal",
})
```

The op buffer shows the last 200 operations by default. To change the limit:

```lua
require("jujutsu").setup({
  op_limit = 50,
})
```

All keymaps can be remapped or disabled. Only the keys you specify are overridden; the rest keep their defaults.

```lua
require("jujutsu").setup({
  keymaps = {
    log = {
      edit                    = "<CR>",
      mark                    = "m",
      clear_marks             = "M",
      new                     = "<C-n>",
      abandon                 = "a",
      squash                  = "s",
      rebase                  = "r",
      rebase_pick             = "R",
      undo                    = "u",
      describe                = "d",
      duplicate               = "p",
      duplicate_pick          = "P",
      bookmark_set            = "bs",
      bookmark_delete         = "bd",
      bookmark_move           = "bm",
      bookmark_move_backwards = "bM",
      bookmark_track          = "bt",
      bookmark_untrack        = "bT",
      git_fetch               = "gf",
      git_push                = "gp",
      git_push_all            = "gP",
      quit                    = "q",
      goto_log                = "gl",
      goto_bookmark           = "gb",
      goto_op                 = "go",
      refresh                 = "<C-r>",
    },
    bookmark = {
      edit                    = "<CR>",
      mark                    = "m",
      clear_marks             = "M",
      new                     = "<C-n>",
      delete                  = "d",
      track                   = "t",
      untrack                 = "T",
      toggle_all              = "r",
      git_fetch               = "gf",
      git_push                = "gp",
      git_push_all            = "gP",
      undo                    = "u",
      quit                    = "q",
      goto_log                = "gl",
      goto_bookmark           = "gb",
      goto_op                 = "go",
      refresh                 = "<C-r>",
    },
    op = {
      restore                 = "<CR>",
      undo                    = "u",
      quit                    = "q",
      goto_log                = "gl",
      goto_bookmark           = "gb",
      goto_op                 = "go",
      refresh                 = "<C-r>",
    },
  },
})
```

### GPG Signing

If you use GPG commit signing with jj, operations may block waiting for
a passphrase. Set `cache_gpg` to have the plugin prompt for your
passphrase (if not already cached in gpg-agent) before running jj commands:

- `"on-push"` — check before push operations only
- `"all"` — check before all jj operations

Requires `allow-loopback-pinentry` in `~/.gnupg/gpg-agent.conf`:

```
allow-loopback-pinentry
```

After adding the line, reload the agent: `gpgconf --kill gpg-agent`.

```lua
require("jujutsu").setup({
  cache_gpg = "on-push", -- or "all"
})
```

Recommended: configure jj to only sign on push instead of on every commit.
This avoids repeated passphrase prompts during normal work and batches all
signing into the push step:

```toml
# ~/.jjconfig.toml
[signing]
behavior = "drop"

[git]
sign-on-push = true
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
