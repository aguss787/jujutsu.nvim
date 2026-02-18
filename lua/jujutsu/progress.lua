local M = {}

---@type table<string, any>
local active = {}

---Show a noice LSP-style progress notification (falls back to vim.notify without noice)
---@param id string unique key for this progress
---@param msg string message to display
function M.start(id, msg)
  local ok, Message = pcall(require, "noice.message")
  if not ok then
    vim.notify(msg, vim.log.levels.INFO)
    return
  end
  local Format = require("noice.text.format")
  local Manager = require("noice.message.manager")

  local message = Message("lsp", "progress")
  message.opts.progress = {
    client_id = "jujutsu",
    client = "jj",
    id = id,
    message = msg,
  }
  active[id] = message

  local function update()
    if active[id] then
      Manager.add(Format.format(message, "lsp_progress"))
      vim.defer_fn(update, 200)
    end
  end
  update()
end

---Finish a progress notification with a final status message
---@param id string the same key passed to start
---@param msg string final status message
function M.stop(id, msg)
  local message = active[id]
  active[id] = nil
  if not message then
    vim.notify(msg, vim.log.levels.INFO)
    return
  end
  local Format = require("noice.text.format")
  local Manager = require("noice.message.manager")
  local Router = require("noice.message.router")

  message.opts.progress.message = msg
  Manager.add(Format.format(message, "lsp_progress"))
  Router.update()
  Manager.remove(message)
end

return M
