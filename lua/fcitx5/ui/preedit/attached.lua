local vim_api = vim.api
local utils = require'fcitx5.ui.preedit.utils'
local format_preedits = utils.format_preedits
local hl_group_index = utils.highlight_group_index

---@class ui.preedit.attached.draw_ctx : ui.context
---@field win number
---@field buf number
---@field cursor number[]
---@field length number

---@class ui.preedit.attached : ui.preedit
---@field draw_ctx ui.preedit.attached.draw_ctx
local M = {}

---@type number
M.ns_id = vim_api.nvim_create_namespace('fcitx5-preedit-attached')

---@type ui.preedit.attached.draw_ctx
M.draw_ctx = {
  length = 0,
  cursor = { 1, 0 },
}

---@type ui.context
M.input_ctx = {}

M.cursor_lock = false

---@param widget ui.preedit.attached
---@param config ui.config
function M:setup(widget, config)
end

---@param context ui.context
function M:attach(context)
  self.draw_ctx = self.draw_ctx or {}
  self.draw_ctx.win = nil
  self.draw_ctx.buf = self.draw_ctx.buf or nil
  self.input_ctx = context
end

function M:detach()
  self:hide()
  self.input_ctx = {}
end

---@param widget ui.preedit.attached
---@return number bufnr
local function create_buf(widget)
  if widget.draw_ctx.buf == nil then
    widget.draw_ctx.buf = vim_api.nvim_create_buf(false, true)
    vim_api.nvim_buf_set_name(widget.draw_ctx.buf, 'fcitx5-preedit')
    vim_api.nvim_buf_call(widget.draw_ctx.buf, function ()
      vim.cmd([[
        augroup fcitx5_preedit
          au!
          autocmd CursorMovedI <buffer> lua require'fcitx5'.move_cursor()
          autocmd InsertCharPre <buffer> lua require'fcitx5'.process_key(string.byte(vim.v.char))
        augroup END
      ]])
    end)
  end
  return widget.draw_ctx.buf
end

---@param widget ui.preedit.attached
---@param win_width number
---@param cursor number
local function open_win(widget, win_width, cursor)
  if widget.draw_ctx.win == nil then
    local win_config = {
      relative = 'cursor',
      row = 0,
      col = 0,
      width = win_width,
      height = 1,
      style = 'minimal',
      zindex = 300,
    }
    vim_api.nvim_win_call(widget.input_ctx.win, function ()
      widget.draw_ctx.win = vim_api.nvim_open_win(widget.draw_ctx.buf, false, win_config)
      vim_api.nvim_win_set_option(widget.draw_ctx.win, 'winhl', 'NormalFloat:Fcitx5PreeditNormal')
      vim_api.nvim_win_set_option(widget.draw_ctx.win, 'cursorline', true)
    end)
  else
    vim_api.nvim_win_set_width(widget.draw_ctx.win, win_width)
  end
  vim_api.nvim_set_current_win(widget.draw_ctx.win)

  -- Set cursor position
  if cursor >= 0 then
    widget.cursor_lock = true
    vim_api.nvim_win_set_cursor(widget.draw_ctx.win, { 1, cursor })
  end
end

---@param preedits string[]
---@param cursor number
function M:update(preedits, cursor, _, _)

  -- Format input
  local preedit_string, preedit_sep_loc, preedit_hl = format_preedits(preedits)

  -- If buffer are absent, creates them
  local buf = create_buf(self)
  local ns_id = self.ns_id

  -- Set content of buffer
  vim_api.nvim_buf_set_lines(buf, 0, -1, true, {preedit_string})

  -- Set highlight
  for i, hl in ipairs(preedit_hl) do
    for flag, group in pairs(hl_group_index) do
      if bit.band(hl, flag) ~= 0 then
        vim_api.nvim_buf_add_highlight(buf, ns_id, group, 0, preedit_sep_loc[i], preedit_sep_loc[i + 1])
      end
    end
  end

  -- Displays preedit window
  local preedit_width = vim.fn.strwidth(preedit_string)
  if preedit_width ~= 0 then
    open_win(self, preedit_width + 1, cursor)
  else
    self:hide()
  end
end

---@return number line_diff
---@return number cursor_diff
---@return number preedit_diff
function M:move_cursor()
  local line = vim_api.nvim_get_current_line()
  local d_preedit = #line - self.draw_ctx.length
  self.draw_ctx.length = #line

  local lno, cursor = unpack(vim_api.nvim_win_get_cursor(self.draw_ctx.win))
  local d_line = lno - 1
  local d_cursor = cursor - self.draw_ctx.cursor[2]
  self.draw_ctx.cursor[2] = cursor
  return d_line, d_cursor, d_preedit
end

function M:hide()
  local win = (self.draw_ctx or {}).win
  if win ~= nil and vim_api.nvim_win_is_valid(win) then
    vim_api.nvim_win_hide(win)
    self.draw_ctx.win = nil
  end
end

return M
