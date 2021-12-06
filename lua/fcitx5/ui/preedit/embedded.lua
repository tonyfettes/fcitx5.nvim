local vim_api = vim.api
local utils = require'fcitx5.ui.preedit.utils'
local format_preedits = utils.format_preedits
local hl_group_index = utils.highlight_group_index

---@class ui.preedit.embedded.draw_ctx
---@field buf number

---@class ui.preedit.embedded : ui.widget
---@field draw_ctx ui.preedit.embedded.draw_ctx

---@type ui.preedit.embedded
local M = {}

---@type number
M.ns_id = vim_api.nvim_create_namespace('fcitx5-preedit-embedded')

---@type ui.preedit.embedded.draw_ctx
M.draw_ctx = {}

---@type ui.context
M.input_ctx = {}

M.cursor_lock = false

---@param config ui.config
function M:setup(config)
end

---@param context ui.context
function M:attach(context)
  self.draw_ctx = self.draw_ctx or {}
  self.draw_ctx.buf = self.draw_ctx.buf or nil
  self.input_ctx = context
  vim_api.nvim_buf_set_extmark(
    context.buf,
    self.ns_id,
    context.cursor[1] - 1,
    context.cursor[2],
    { id = 1 }
  )
end

function M:detach()
  self:hide()
  self.input_ctx = {}
end

---@param new_cursor number
function M:update(preedits, new_cursor, _, _)

  -- Format input
  local content, sep_loc, hl_flags = format_preedits(preedits)

  -- Uses input buffer
  local buf = self.input_ctx.buf

  -- Listen to movement of cursor
  vim_api.nvim_buf_call(buf, function ()
    vim.cmd[[
      augroup fcitx5_preedit
        au!
        autocmd CursorMovedI <buffer> lua require'fcitx5'.move_cursor()
      augroup END
    ]]
  end)

  -- Set content of buffer
  local cursor = self.input_ctx.cursor
  local anchor = vim_api.nvim_buf_get_extmark_by_id(buf, self.ns_id, 1, {})
  vim_api.nvim_buf_set_text(
    buf,
    cursor[1] - 1,
    cursor[2],
    anchor[1],
    anchor[2],
    {content}
  )

  -- Set highlights
  local ns_id = self.ns_id
  for i, hl in ipairs(hl_flags) do
    for flag, hl_group in pairs(hl_group_index) do
      if bit.band(hl, flag) ~= 0 then
        vim_api.nvim_buf_add_highlight(
          buf,
          ns_id,
          hl_group,
          cursor[1] - 1,
          cursor[2] + sep_loc[i],
          cursor[2] + sep_loc[i + 1]
        )
      end
    end
  end

  if new_cursor >= 0 then
    self.cursor_lock = true
    vim_api.nvim_win_set_cursor(
      self.input_ctx.win,
      { cursor[1], cursor[2] + new_cursor }
    )
  end
end

function M:move_cursor()
end

function M:hide()
-- M.hide = function (widget)
  local buf = (self.draw_ctx or {}).buf
  if buf ~= nil and vim_api.nvim_buf_is_valid(buf) then
    -- Clears out highlights
    vim_api.nvim_buf_clear_namespace(buf, self.ns_id, 0, -1)
  end
end

return M
