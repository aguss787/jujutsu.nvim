local M = {}

package.loaded["jujutsu"] = nil
local jujutsu = require("jujutsu")
jujutsu.setup()
M.default_keymaps = vim.deepcopy(jujutsu.config.keymaps)
M.default_log_keymaps = M.default_keymaps.log
M.default_bookmark_keymaps = M.default_keymaps.bookmark

---Find the callback registered for a normal-mode lhs on buf.
---@param buf integer
---@param lhs string
---@return function
function M.get_cb(buf, lhs)
  for _, km in ipairs(vim.api.nvim_buf_get_keymap(buf, "n")) do
    if km.lhs == lhs then
      return km.callback
    end
  end
  error("no keymap '" .. lhs .. "' on buf " .. buf)
end

---Return true if expected command was among the captured vim.system calls.
---@param calls table[]
---@param expected string[]
---@return boolean
function M.was_called(calls, expected)
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

return M
