local default_keymaps = require("tests.helpers").default_keymaps

local function reload()
  package.loaded["jujutsu.bookmark_buffer"] = nil
  return require("jujutsu.bookmark_buffer")
end

-- refresh ---------------------------------------------------------------------

describe("bookmark refresh", function()
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

  if vim.fn.executable("jj") == 1 then
    it("populates buffer with jj bookmark list output", function()
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
