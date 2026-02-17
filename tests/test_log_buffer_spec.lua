local T = MiniTest.new_set()

local function reload()
  package.loaded["jujutsu.log_buffer"] = nil
  return require("jujutsu.log_buffer")
end

-- setup_keymaps ---------------------------------------------------------------

T["setup_keymaps"] = MiniTest.new_set()

local function with_buf(fn)
  local buf = vim.api.nvim_create_buf(false, true)
  fn(buf)
  if vim.api.nvim_buf_is_valid(buf) then
    vim.api.nvim_buf_delete(buf, { force = true })
  end
end

T["setup_keymaps"]["registers all expected keymaps"] = function()
  with_buf(function(buf)
    reload().setup_keymaps(buf)

    local lhs_set = {}
    for _, km in ipairs(vim.api.nvim_buf_get_keymap(buf, "n")) do
      lhs_set[km.lhs] = true
    end

    MiniTest.expect.equality(lhs_set["<CR>"], true)
    MiniTest.expect.equality(lhs_set["m"], true)
    MiniTest.expect.equality(lhs_set["M"], true)
    MiniTest.expect.equality(lhs_set["n"], true)
    MiniTest.expect.equality(lhs_set["a"], true)
    MiniTest.expect.equality(lhs_set["u"], true)
    MiniTest.expect.equality(lhs_set["d"], true)
  end)
end

T["setup_keymaps"]["does not leak keymaps into global scope"] = function()
  with_buf(function(buf)
    reload().setup_keymaps(buf)

    local global_lhs = {}
    for _, km in ipairs(vim.api.nvim_get_keymap("n")) do
      global_lhs[km.lhs] = true
    end

    MiniTest.expect.equality(global_lhs["m"], nil)
    MiniTest.expect.equality(global_lhs["M"], nil)
    MiniTest.expect.equality(global_lhs["u"], nil)
  end)
end

T["setup_keymaps"]["can be called multiple times without erroring"] = function()
  with_buf(function(buf)
    local lb = reload()
    MiniTest.expect.no_error(function()
      lb.setup_keymaps(buf)
      lb.setup_keymaps(buf)
    end)
  end)
end

-- refresh ---------------------------------------------------------------------

T["refresh"] = MiniTest.new_set()

T["refresh"]["returns false outside a jj repo"] = function()
  with_buf(function(buf)
    local tmp = vim.fn.tempname()
    vim.fn.mkdir(tmp, "p")
    local orig = vim.fn.getcwd()
    vim.cmd("cd " .. tmp)

    local ok = reload().refresh(buf)

    vim.cmd("cd " .. orig)
    vim.fn.delete(tmp, "rf")

    MiniTest.expect.equality(ok, false)
  end)
end

T["refresh"]["leaves buffer unmodifiable after a failed refresh"] = function()
  with_buf(function(buf)
    vim.bo[buf].modifiable = false
    local tmp = vim.fn.tempname()
    vim.fn.mkdir(tmp, "p")
    local orig = vim.fn.getcwd()
    vim.cmd("cd " .. tmp)

    reload().refresh(buf)

    vim.cmd("cd " .. orig)
    vim.fn.delete(tmp, "rf")

    MiniTest.expect.equality(vim.bo[buf].modifiable, false)
  end)
end

if vim.fn.executable("jj") == 1 then
  T["refresh"]["populates buffer with jj log output"] = function()
    with_buf(function(buf)
      local ok = reload().refresh(buf)
      MiniTest.expect.equality(ok, true)
      local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
      MiniTest.expect.equality(#lines > 0, true)
    end)
  end

  T["refresh"]["leaves buffer unmodifiable after a successful refresh"] = function()
    with_buf(function(buf)
      reload().refresh(buf)
      MiniTest.expect.equality(vim.bo[buf].modifiable, false)
    end)
  end
end

return T
