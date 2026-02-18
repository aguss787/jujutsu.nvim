local M = {}

local jj = require("jujutsu.jj")

---Fetch `jj bookmark list` output and replace the contents of buf
---@param buf integer
---@return boolean success
function M.refresh(buf)
  local result = jj.run({ "bookmark", "list" })
  if not result then
    return false
  end
  local lines = vim.split(result.stdout, "\n", { plain = true })
  if lines[#lines] == "" then
    table.remove(lines)
  end
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  return true
end

---Set up buffer-local keymaps for the bookmark buffer
---@param buf integer
---@param keymaps table<string, string|false>
function M.setup_keymaps(buf, keymaps)
  if keymaps.refresh and keymaps.refresh ~= false then
    vim.keymap.set("n", keymaps.refresh, function()
      if M.refresh(buf) then
        vim.notify("jj bookmark list: refreshed", vim.log.levels.INFO)
      end
    end, { buffer = buf, desc = "Refresh the bookmark list buffer" })
  end
end

return M
