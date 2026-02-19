local helpers = require("tests.helpers")
local default_keymaps = helpers.default_keymaps.op
local get_cb = helpers.get_cb
local was_called = helpers.was_called

local function reload()
  package.loaded["jujutsu.op_buffer"] = nil
  return require("jujutsu.op_buffer")
end

-- refresh ---------------------------------------------------------------------

describe("op refresh", function()
  local buf

  before_each(function()
    buf = vim.api.nvim_create_buf(false, true)
    vim.bo[buf].modifiable = false
  end)

  after_each(function()
    if vim.api.nvim_buf_is_valid(buf) then
      vim.api.nvim_buf_delete(buf, { force = true })
    end
  end)

  it("returns false outside a jj repo", function()
    local tmp = vim.fn.tempname()
    vim.fn.mkdir(tmp, "p")
    local orig = vim.fn.getcwd()
    vim.cmd("cd " .. tmp)

    local ok = reload().refresh(buf)

    vim.cmd("cd " .. orig)
    vim.fn.delete(tmp, "rf")

    assert.is_false(ok)
  end)

  it("registers expected keymaps", function()
    reload().setup_keymaps(buf, default_keymaps)
    local lhs_set = {}
    for _, km in ipairs(vim.api.nvim_buf_get_keymap(buf, "n")) do
      lhs_set[km.lhs] = true
    end
    assert.truthy(lhs_set["q"])
    assert.truthy(lhs_set["u"])
    assert.truthy(lhs_set["gl"])
    assert.truthy(lhs_set["gb"])
    assert.truthy(lhs_set["go"])
  end)

  if vim.fn.executable("jj") == 1 then
    it("populates buffer with jj op log output", function()
      local ok = reload().refresh(buf)
      assert.is_true(ok)
      local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
      assert.is_true(#lines > 0)
    end)

    it("leaves buffer unmodifiable after a successful refresh", function()
      reload().refresh(buf)
      assert.is_false(vim.bo[buf].modifiable)
    end)
  end
end)

-- operations ------------------------------------------------------------------

describe("op buffer operations", function()
  local buf, calls, orig_system

  before_each(function()
    calls = {}
    orig_system = vim.system
    vim.system = function(cmd, _opts, on_exit)
      table.insert(calls, vim.deepcopy(cmd))
      local stdout = ""
      if cmd[2] == "op" and cmd[3] == "log" then
        stdout = "abc12345 user@test.com 2024-01-01 some operation\n"
      end
      local result = { code = 0, stdout = stdout, stderr = "" }
      if on_exit then
        on_exit(result)
        return
      end
      return { wait = function() return result end }
    end

    buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "abc12345 user@test.com 2024-01-01 some operation" })
    vim.bo[buf].modifiable = false
    reload().setup_keymaps(buf, default_keymaps)
  end)

  after_each(function()
    vim.system = orig_system
    if vim.api.nvim_buf_is_valid(buf) then
      vim.api.nvim_buf_delete(buf, { force = true })
    end
  end)

  it("undo calls jj undo", function()
    get_cb(buf, "u")()
    assert.is_true(was_called(calls, { "jj", "undo" }))
  end)
end)
