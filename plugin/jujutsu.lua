if vim.g.loaded_jujutsu then
  return
end
vim.g.loaded_jujutsu = 1

vim.api.nvim_create_user_command("Jj", function(args)
  local subcmd = args.args
  if subcmd == "" or subcmd == "log" then
    require("jujutsu").log()
  elseif subcmd == "bookmark" then
    require("jujutsu").bookmark()
  elseif subcmd == "op" then
    require("jujutsu").op()
  else
    vim.notify("jujutsu: unknown command '" .. subcmd .. "'", vim.log.levels.ERROR)
  end
end, {
  nargs = "?",
  desc = "Jujutsu commands",
  complete = function()
    return { "log", "bookmark", "op" }
  end,
})
