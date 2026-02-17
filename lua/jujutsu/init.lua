local M = {}

---@class JujutsuConfig
---@field field string Example config field

---@type JujutsuConfig
local defaults = {
  field = "value",
}

---@type JujutsuConfig
M.config = {}

---Setup the plugin
---@param opts? JujutsuConfig
M.setup = function(opts)
  M.config = vim.tbl_deep_extend("force", defaults, opts or {})
end

return M
