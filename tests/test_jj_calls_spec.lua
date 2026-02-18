local function reload()
  package.loaded["jujutsu.log_buffer"] = nil
  return require("jujutsu.log_buffer")
end

local default_keymaps = {
  edit = "<CR>",
  mark = "m",
  clear_marks = "M",
  new = "n",
  abandon = "a",
  squash = "s",
  rebase = "r",
  rebase_pick = "R",
  undo = "u",
  describe = "d",
  refresh = "<C-r>",
}

-- Fake jj log lines whose revision IDs are extracted by the [@◉○]%s+(%w+) pattern
local LINE1 = "○  rev00001 a@b.com 2024-01-01 first commit"
local LINE2 = "○  rev00002 a@b.com 2024-01-01 second commit"

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
    vim.system = function(cmd, _opts)
      table.insert(calls, vim.deepcopy(cmd))
      local stdout = cmd[2] == "log" and (LINE1 .. "\n") or ""
      return {
        wait = function()
          return { code = 0, stdout = stdout, stderr = "" }
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

  it("describe buffer is closed after saving", function()
    on_line(buf, 1, get_cb(buf, "d"))
    local desc_buf = vim.fn.bufnr("jj://describe/rev00001")
    assert.is_true(desc_buf ~= -1)
    vim.api.nvim_exec_autocmds("BufWriteCmd", { buffer = desc_buf, modeline = false })
    assert.is_false(vim.api.nvim_buf_is_valid(desc_buf))
  end)

  it("clear_marks removes marks so next operation uses cursor revision", function()
    on_line(buf, 2, get_cb(buf, "m")) -- mark rev00002
    on_line(buf, 1, get_cb(buf, "M")) -- clear all marks
    on_line(buf, 1, get_cb(buf, "n")) -- new should use cursor rev, not marked
    assert.is_true(was_called(calls, { "jj", "new", "rev00001" }))
  end)
end)
