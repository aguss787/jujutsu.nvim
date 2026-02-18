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

-- setup_keymaps ---------------------------------------------------------------

describe("setup_keymaps", function()
  local buf

  before_each(function()
    buf = vim.api.nvim_create_buf(false, true)
  end)

  after_each(function()
    if vim.api.nvim_buf_is_valid(buf) then
      vim.api.nvim_buf_delete(buf, { force = true })
    end
  end)

  it("registers all expected keymaps", function()
    reload().setup_keymaps(buf, default_keymaps)

    local lhs_set = {}
    for _, km in ipairs(vim.api.nvim_buf_get_keymap(buf, "n")) do
      lhs_set[km.lhs] = true
    end

    assert.truthy(lhs_set["<CR>"])
    assert.truthy(lhs_set["m"])
    assert.truthy(lhs_set["M"])
    assert.truthy(lhs_set["n"])
    assert.truthy(lhs_set["a"])
    assert.truthy(lhs_set["u"])
    assert.truthy(lhs_set["d"])
  end)

  it("does not leak keymaps into global scope", function()
    reload().setup_keymaps(buf, default_keymaps)

    local global_lhs = {}
    for _, km in ipairs(vim.api.nvim_get_keymap("n")) do
      global_lhs[km.lhs] = true
    end

    assert.falsy(global_lhs["m"])
    assert.falsy(global_lhs["M"])
    assert.falsy(global_lhs["u"])
  end)

  it("can be called multiple times without erroring", function()
    local lb = reload()
    assert.has_no.errors(function()
      lb.setup_keymaps(buf, default_keymaps)
      lb.setup_keymaps(buf, default_keymaps)
    end)
  end)
end)

-- refresh ---------------------------------------------------------------------

describe("refresh", function()
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

  it("leaves buffer unmodifiable after a failed refresh", function()
    local tmp = vim.fn.tempname()
    vim.fn.mkdir(tmp, "p")
    local orig = vim.fn.getcwd()
    vim.cmd("cd " .. tmp)

    reload().refresh(buf)

    vim.cmd("cd " .. orig)
    vim.fn.delete(tmp, "rf")

    assert.is_false(vim.bo[buf].modifiable)
  end)

  if vim.fn.executable("jj") == 1 then
    it("populates buffer with jj log output", function()
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
