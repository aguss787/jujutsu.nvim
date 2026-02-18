local default_keymaps = require("tests.helpers").default_keymaps

local function reload()
  package.loaded["jujutsu.log_buffer"] = nil
  return require("jujutsu.log_buffer")
end

-- Fake jj log lines whose revision IDs are extracted by the node pattern
local LINE1 = "○  rev00001 a@b.com 2024-01-01 first commit"
local LINE2 = "○  rev00002 a@b.com 2024-01-01 second commit"
local LINE_IMMUTABLE = "◆  rev00003 a@b.com 2024-01-01 immutable commit"
local LINE_BRANCHED = "│ ◆  rev00004 a@b.com 2024-01-01 branched commit"

---Find the callback registered for a normal-mode lhs on buf.
---@param buf integer
---@param lhs string
---@return function
local function get_cb(buf, lhs)
  for _, km in ipairs(vim.api.nvim_buf_get_keymap(buf, "n")) do
    if km.lhs == lhs then
      return km.callback
    end
  end
  error("no keymap '" .. lhs .. "' on buf " .. buf)
end

---Execute fn with buf as the current buffer and cursor on linum (1-based).
---@param buf integer
---@param linum integer
---@param fn function
local function on_line(buf, linum, fn)
  vim.api.nvim_buf_call(buf, function()
    vim.api.nvim_win_set_cursor(0, { linum, 0 })
    fn()
  end)
end

---Return true if expected command was among the captured vim.system calls.
---@param calls table[]
---@param expected string[]
---@return boolean
local function was_called(calls, expected)
  for _, call in ipairs(calls) do
    if #call == #expected then
      local match = true
      for i, v in ipairs(expected) do
        if call[i] ~= v then
          match = false
          break
        end
      end
      if match then
        return true
      end
    end
  end
  return false
end

describe("jj operation calls", function()
  local buf
  local calls
  local orig_system

  before_each(function()
    calls = {}
    orig_system = vim.system
    vim.system = function(cmd, _opts, on_exit)
      table.insert(calls, vim.deepcopy(cmd))
      local stdout = ""
      if cmd[2] == "log" then
        stdout = LINE1 .. "\n"
      elseif cmd[2] == "bookmark" and cmd[3] == "list" then
        stdout = "my-bookmark\n"
      end
      local result = { code = 0, stdout = stdout, stderr = "" }
      if on_exit then
        on_exit(result)
        return
      end
      return {
        wait = function()
          return result
        end,
      }
    end

    buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { LINE1, LINE2 })
    vim.bo[buf].modifiable = false
    reload().setup_keymaps(buf, default_keymaps)
  end)

  after_each(function()
    vim.system = orig_system
    if vim.api.nvim_buf_is_valid(buf) then
      vim.api.nvim_buf_delete(buf, { force = true })
    end
  end)

  it("edit calls jj edit with the revision under cursor", function()
    on_line(buf, 1, get_cb(buf, "<CR>"))
    assert.is_true(was_called(calls, { "jj", "edit", "rev00001" }))
  end)

  it("new calls jj new with the revision under cursor when no marks", function()
    on_line(buf, 1, get_cb(buf, "n"))
    assert.is_true(was_called(calls, { "jj", "new", "rev00001" }))
  end)

  it("new calls jj new with all marked revisions", function()
    on_line(buf, 1, get_cb(buf, "m")) -- mark rev00001
    on_line(buf, 2, get_cb(buf, "m")) -- mark rev00002
    on_line(buf, 1, get_cb(buf, "n"))
    local found = false
    for _, call in ipairs(calls) do
      if call[1] == "jj" and call[2] == "new" then
        if vim.tbl_contains(call, "rev00001") and vim.tbl_contains(call, "rev00002") then
          found = true
          break
        end
      end
    end
    assert.is_true(found)
  end)

  it("abandon calls jj abandon with the revision under cursor when no marks", function()
    on_line(buf, 1, get_cb(buf, "a"))
    assert.is_true(was_called(calls, { "jj", "abandon", "rev00001" }))
  end)

  it("abandon calls jj abandon with all marked revisions", function()
    on_line(buf, 1, get_cb(buf, "m")) -- mark rev00001
    on_line(buf, 2, get_cb(buf, "m")) -- mark rev00002
    on_line(buf, 1, get_cb(buf, "a"))
    local found = false
    for _, call in ipairs(calls) do
      if call[1] == "jj" and call[2] == "abandon" then
        if vim.tbl_contains(call, "rev00001") and vim.tbl_contains(call, "rev00002") then
          found = true
          break
        end
      end
    end
    assert.is_true(found)
  end)

  it("squash with no marks calls jj squash -r <rev>", function()
    on_line(buf, 1, get_cb(buf, "s"))
    assert.is_true(was_called(calls, { "jj", "squash", "-r", "rev00001" }))
  end)

  it("squash with one mark calls jj squash --from <rev> --into <dest>", function()
    on_line(buf, 2, get_cb(buf, "m")) -- mark rev00002 as destination
    on_line(buf, 1, get_cb(buf, "s")) -- squash rev00001 into rev00002
    assert.is_true(was_called(calls, { "jj", "squash", "--from", "rev00001", "--into", "rev00002" }))
  end)

  it("rebase calls jj rebase -s <rev> -d <dest>", function()
    on_line(buf, 2, get_cb(buf, "m")) -- mark rev00002 as destination
    on_line(buf, 1, get_cb(buf, "r")) -- rebase rev00001
    assert.is_true(was_called(calls, { "jj", "rebase", "-s", "rev00001", "-d", "rev00002" }))
  end)

  it("undo calls jj undo", function()
    on_line(buf, 1, get_cb(buf, "u"))
    assert.is_true(was_called(calls, { "jj", "undo" }))
  end)

  it("bookmark_set calls jj bookmark set with input name and cursor revision", function()
    local orig_input = vim.ui.input
    vim.ui.input = function(_opts, on_confirm)
      on_confirm("my-bookmark")
    end
    on_line(buf, 1, get_cb(buf, "bs"))
    vim.ui.input = orig_input
    assert.is_true(was_called(calls, { "jj", "bookmark", "set", "my-bookmark", "-r", "rev00001" }))
  end)

  it("bookmark_delete calls jj bookmark delete with the bookmark on cursor revision", function()
    on_line(buf, 1, get_cb(buf, "bd"))
    assert.is_true(was_called(calls, { "jj", "bookmark", "list", "-r", "rev00001", "-T", 'name ++ "\\n"' }))
    assert.is_true(was_called(calls, { "jj", "bookmark", "delete", "my-bookmark" }))
  end)

  it("bookmark_move calls jj bookmark move from marked revision to cursor revision", function()
    on_line(buf, 2, get_cb(buf, "m")) -- mark rev00002 as source
    on_line(buf, 1, get_cb(buf, "bm")) -- move to rev00001
    assert.is_true(was_called(calls, { "jj", "bookmark", "move", "--to", "rev00001", "--from", "rev00002" }))
  end)

  it("bookmark_move_backwards calls jj bookmark move -B from marked revision to cursor revision", function()
    on_line(buf, 2, get_cb(buf, "m")) -- mark rev00002 as source
    on_line(buf, 1, get_cb(buf, "bM")) -- move backwards to rev00001
    assert.is_true(was_called(calls, { "jj", "bookmark", "move", "--to", "rev00001", "-B", "--from", "rev00002" }))
  end)

  it("duplicate calls jj duplicate --onto with cursor revision onto marked destination", function()
    on_line(buf, 2, get_cb(buf, "m")) -- mark rev00002 as destination
    on_line(buf, 1, get_cb(buf, "p")) -- duplicate rev00001 onto rev00002
    assert.is_true(was_called(calls, { "jj", "duplicate", "rev00001", "--onto", "rev00002" }))
  end)

  it("duplicate_pick calls jj duplicate with chosen destination mode", function()
    local orig_select = vim.ui.select
    vim.ui.select = function(_items, _opts, on_choice)
      on_choice(_items[2]) -- pick second option (--insert-after)
    end
    on_line(buf, 2, get_cb(buf, "m")) -- mark rev00002 as destination
    on_line(buf, 1, get_cb(buf, "P")) -- duplicate rev00001
    vim.ui.select = orig_select
    assert.is_true(was_called(calls, { "jj", "duplicate", "rev00001", "--insert-after", "rev00002" }))
  end)

  it("git_fetch calls jj git fetch", function()
    on_line(buf, 1, get_cb(buf, "gf"))
    assert.is_true(was_called(calls, { "jj", "git", "fetch" }))
  end)

  it("git_push calls jj git push", function()
    on_line(buf, 1, get_cb(buf, "gp"))
    assert.is_true(was_called(calls, { "jj", "git", "push" }))
  end)

  it("describe buffer is closed after saving", function()
    on_line(buf, 1, get_cb(buf, "d"))
    local desc_buf = vim.fn.bufnr("jj://describe/rev00001")
    assert.is_true(desc_buf ~= -1)
    vim.api.nvim_exec_autocmds("BufWriteCmd", { buffer = desc_buf, modeline = false })
    assert.is_false(vim.api.nvim_buf_is_valid(desc_buf))
  end)

  it("can mark and operate on immutable (◆) revisions", function()
    vim.bo[buf].modifiable = true
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { LINE1, LINE_IMMUTABLE })
    vim.bo[buf].modifiable = false
    on_line(buf, 2, get_cb(buf, "m")) -- mark immutable rev00003
    on_line(buf, 1, get_cb(buf, "n")) -- new from marks
    assert.is_true(was_called(calls, { "jj", "new", "rev00003" }))
  end)

  it("can mark and operate on branched revisions with graph prefix", function()
    vim.bo[buf].modifiable = true
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { LINE1, LINE_BRANCHED })
    vim.bo[buf].modifiable = false
    on_line(buf, 2, get_cb(buf, "m")) -- mark branched rev00004
    on_line(buf, 1, get_cb(buf, "n")) -- new from marks
    assert.is_true(was_called(calls, { "jj", "new", "rev00004" }))
  end)

  it("clear_marks removes marks so next operation uses cursor revision", function()
    on_line(buf, 2, get_cb(buf, "m")) -- mark rev00002
    on_line(buf, 1, get_cb(buf, "M")) -- clear all marks
    on_line(buf, 1, get_cb(buf, "n")) -- new should use cursor rev, not marked
    assert.is_true(was_called(calls, { "jj", "new", "rev00001" }))
  end)
end)
