local function reload()
  package.loaded["jujutsu.ansi"] = nil
  return require("jujutsu.ansi")
end

describe("ansi", function()
  local ansi

  before_each(function()
    ansi = reload()
  end)

  it("returns plain text unchanged", function()
    local text, highlights = ansi.parse_line("hello world")
    assert.equal("hello world", text)
    assert.equal(0, #highlights)
  end)

  it("strips ANSI escape sequences", function()
    local text, _ = ansi.parse_line("\027[38;5;5mmaster\027[39m: description")
    assert.equal("master: description", text)
  end)

  it("returns highlight ranges for colored text", function()
    local text, highlights = ansi.parse_line("\027[38;5;5mmaster\027[39m: rest")
    assert.equal("master: rest", text)
    assert.equal(1, #highlights)
    assert.equal(0, highlights[1][1]) -- start col
    assert.equal(6, highlights[1][2]) -- end col
  end)

  it("handles bold attribute", function()
    local _, highlights = ansi.parse_line("\027[1m\027[38;5;5mx\027[0myz")
    assert.equal(1, #highlights)
    assert.truthy(highlights[1][3]:find("Bold"))
  end)

  it("handles reset correctly", function()
    local text, highlights = ansi.parse_line("\027[38;5;5mab\027[0mcd")
    assert.equal("abcd", text)
    assert.equal(1, #highlights)
    assert.equal(0, highlights[1][1])
    assert.equal(2, highlights[1][2])
  end)

  it("renders lines into a buffer", function()
    local buf = vim.api.nvim_create_buf(false, true)
    ansi.render(buf, {
      "\027[38;5;5mmaster\027[39m: abc12345 description",
      "plain line",
    })
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    assert.equal("master: abc12345 description", lines[1])
    assert.equal("plain line", lines[2])
    assert.is_false(vim.bo[buf].modifiable)
    vim.api.nvim_buf_delete(buf, { force = true })
  end)
end)
