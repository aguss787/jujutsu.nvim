local M = {}

local ns = vim.api.nvim_create_namespace("jujutsu_ansi")

-- Standard ANSI color palette (used when g:terminal_color_N is not set)
local ansi_defaults = {
  [0] = "#000000",
  "#cc0000",
  "#4e9a06",
  "#c4a000",
  "#3465a4",
  "#75507b",
  "#06989a",
  "#d3d7cf",
  [8] = "#555753",
  "#ef2929",
  "#8ae234",
  "#fce94f",
  "#729fcf",
  "#ad7fa8",
  "#34e2e2",
  "#eeeeec",
}

---@type table<string, boolean>
local hl_defined = {}

---Map 256-color index to a hex color string, preferring g:terminal_color_N
---@param index integer
---@return string
local function color_to_hex(index)
  if index <= 15 then
    return vim.g["terminal_color_" .. index] or ansi_defaults[index]
  elseif index >= 232 then
    local gray = (index - 232) * 10 + 8
    return string.format("#%02x%02x%02x", gray, gray, gray)
  else
    local idx = index - 16
    local vals = { [0] = 0, 0x5f, 0x87, 0xaf, 0xd7, 0xff }
    local b = vals[idx % 6]
    idx = math.floor(idx / 6)
    local g = vals[idx % 6]
    local r = vals[math.floor(idx / 6)]
    return string.format("#%02x%02x%02x", r, g, b)
  end
end

---Get or create a highlight group for the given ANSI attributes
---@param fg integer?
---@param bold boolean
---@return string
local function get_hl_group(fg, bold)
  local name = "JjAnsi" .. (fg or "nil") .. (bold and "Bold" or "")
  if not hl_defined[name] then
    local opts = {}
    if fg then
      opts.fg = color_to_hex(fg)
      opts.ctermfg = fg
    end
    if bold then
      opts.bold = true
    end
    vim.api.nvim_set_hl(0, name, opts)
    hl_defined[name] = true
  end
  return name
end

---Parse a line with ANSI escape sequences
---@param line string
---@return string stripped_text
---@return {[1]: integer, [2]: integer, [3]: string}[] highlights {start_col, end_col, hl_group}
function M.parse_line(line)
  local highlights = {}
  local text = ""
  local fg = nil
  local bold = false
  local pos = 1

  while pos <= #line do
    local esc_start, esc_end, params = line:find("\027%[([%d;]*)m", pos)
    if esc_start then
      if esc_start > pos then
        local chunk = line:sub(pos, esc_start - 1)
        local start_col = #text
        text = text .. chunk
        if fg or bold then
          table.insert(highlights, { start_col, #text, get_hl_group(fg, bold) })
        end
      end
      local nums = {}
      for n in params:gmatch("%d+") do
        table.insert(nums, tonumber(n))
      end
      local i = 1
      while i <= #nums do
        local n = nums[i]
        if n == 0 then
          fg = nil
          bold = false
        elseif n == 1 then
          bold = true
        elseif n == 38 and nums[i + 1] == 5 then
          fg = nums[i + 2]
          i = i + 2
        elseif n == 39 then
          fg = nil
        end
        i = i + 1
      end
      pos = esc_end + 1
    else
      local chunk = line:sub(pos)
      local start_col = #text
      text = text .. chunk
      if fg or bold then
        table.insert(highlights, { start_col, #text, get_hl_group(fg, bold) })
      end
      break
    end
  end

  return text, highlights
end

---Parse ANSI-colored lines, set buffer content, and apply highlights
---@param buf integer
---@param raw_lines string[]
function M.render(buf, raw_lines)
  -- Re-define highlight groups each render to pick up colorscheme changes
  hl_defined = {}
  local plain_lines = {}
  local all_highlights = {}
  for _, line in ipairs(raw_lines) do
    local text, highlights = M.parse_line(line)
    table.insert(plain_lines, text)
    table.insert(all_highlights, highlights)
  end

  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, plain_lines)
  vim.bo[buf].modifiable = false

  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  for lnum, highlights in ipairs(all_highlights) do
    for _, hl in ipairs(highlights) do
      vim.api.nvim_buf_add_highlight(buf, ns, hl[3], lnum - 1, hl[1], hl[2])
    end
  end
end

return M
