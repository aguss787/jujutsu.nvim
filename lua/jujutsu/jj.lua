local M = {}

local progress = require("jujutsu.progress")

---Run a jj subcommand, notify on failure, return the result on success or nil on failure
---@param args string[]
---@return vim.SystemCompleted?
function M.run(args)
  local result = vim.system(vim.list_extend({ "jj" }, args), { text = true }):wait()
  if result.code ~= 0 then
    vim.notify("jj " .. args[1] .. ": " .. (result.stderr or "unknown error"), vim.log.levels.ERROR)
    return nil
  end
  return result
end

---Run a jj subcommand asynchronously with progress notifications
---@param id string progress ID
---@param msg string progress message
---@param args string[] jj subcommand args (without "jj" prefix)
---@param on_success function callback on success
function M.run_async(id, msg, args, on_success)
  progress.start(id, msg)
  vim.system(vim.list_extend({ "jj" }, args), { text = true }, function(result)
    vim.schedule(function()
      if result.code ~= 0 then
        progress.stop(id, " " .. (result.stderr or "unknown error"))
        return
      end
      on_success()
      progress.stop(id, "done")
    end)
  end)
end

return M
