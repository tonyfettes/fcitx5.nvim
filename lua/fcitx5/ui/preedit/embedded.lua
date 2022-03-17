local vim_api = vim.api
local utils = require'fcitx5.ui.preedit.utils'
local format_preedits = utils.format_preedits
local hl_group_index = utils.highlight_group_index

---@class ui.preedit.embedded : ui.widget
---@field previous_cursor position

---@type ui.preedit.embedded
local M = {}

---@type number
M.ns_id = vim_api.nvim_create_namespace('fcitx5-preedit-embedded')

---@type ui.context
M.input_ctx = {}

M.cursor_lock = false

---@param config ui.config
function M:setup(config)
end

---@param context ui.context
function M:attach(context)
  self.input_ctx = context

  -- Listen to movement of cursor
  vim_api.nvim_buf_call(self.input_ctx.buf, function ()
    vim.cmd[[
      augroup fcitx5_preedit
        au!
        autocmd CursorMovedI <buffer> lua require'fcitx5'.notify_cursor_moved()
      augroup END
    ]]
  end)
end

function M:detach()
  self:hide()
  if self.input_ctx then
    local buf = self.input_ctx.buf
    if buf and vim_api.nvim_buf_is_valid(self.input_ctx.buf) then
      vim_api.nvim_buf_clear_namespace(buf, self.ns_id, 0, -1)
    end
    self.input_ctx = nil
  end
end

local function set_extmark()
  local extmark = vim_api.nvim_buf_get_extmark_by_id(self.input_ctx.buf, self.ns_id, 1, { details = true })
  if #extmark == 0 then
    local lno, cno = vim_api.nvim_win_get_cursor(self.input_ctx.win)
    vim_api.nvim_buf_set_extmark(buf, self.ns_id, lno - 1, cno, {
    })
  else
    local extmark_detail = extmark[3]
    
  end
  local anchor = vim_api.nvim_buf_get_extmark_by_id(buf, self.ns_id, 1, {})
end

---@param new_cursor number
function M:update(preedits, new_cursor, _, _)
  -- WARNING: Should only be called after attach
  assert(self.input_ctx ~= nil, "Not attached to input context")

  -- Format input
  local content, sep_loc, hl_flags = format_preedits(preedits)

  -- Uses input buffer
  local buf = self.input_ctx.buf

  -- Set content of buffer
  local preedit_range = {
    vim_api.nvim_buf_get_extmark_by_id(buf, self.ns_id, 1, {}),
    vim_api.nvim_buf_get_extmark_by_id(buf, self.ns_id, 2, {})
  }
  if vim.tbl_isempty(preedit_range[1]) then
    local cursor = vim_api.nvim_win_get_cursor(self.input_ctx.win)
    vim_api.nvim_buf_set_extmark(buf, self.ns_id, cursor[1] - 1, cursor[2], {
      id = 1,
      right_gravity = false
    })
    vim_api.nvim_buf_set_extmark(buf, self.ns_id, cursor[1] - 1, cursor[2], {
      id = 2,
      right_gravity = true
    })
  end

  vim_api.nvim_buf_set_text(
    buf,
    preedit_range[1][1],
    preedit_range[1][2],
    preedit_range[2][1],
    preedit_range[2][2],
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
          preedit_range[1][1],
          preedit_range[1][2] + sep_loc[i],
          preedit_range[1][2] + sep_loc[i + 1]
        )
      end
    end
  end

  if new_cursor >= 0 then
    self.cursor_lock = true
    self.previous_cursor = { preedit_range[1][1], preedit_range[1][2] + new_cursor }
    vim_api.nvim_win_set_cursor(
      self.input_ctx.win,
      self.previous_cursor
    )
  end
end

---@return number line_diff
---@return number column_diff
---@return number preedit_diff
function M:get_cursor_movement()
  return 0, 0, 0
--   print('previous cursor: ' .. vim.inspect(self.draw_ctx.cursor))
--   print('current cursor: ' .. vim.inspect(vim_api.nvim_win_get_cursor(self.input_ctx.win)))
--   print('input anchor: ' ..  vim.inspect(self.input_ctx.cursor))
--   print('preedit end: ' ..   vim.inspect(vim_api.nvim_buf_get_extmark_by_id(self.input_ctx.buf, self.ns_id, 1, {})))
--   local lno, cno = unpack(vim_api.nvim_win_get_cursor(self.input_ctx.win))
--   local line_diff = lno - self.draw_ctx.cursor[1]
-- 
--   local column_diff = cno - self.draw_ctx.cursor[2]
-- 
--   local preedit_end = vim_api.nvim_buf_get_extmark_by_id(self.input_ctx.buf, self.ns_id, 1, {})
--   local preedit_diff = 0
--   if preedit_end[1] == self.draw_ctx.cursor[1] then
--     preedit_diff = preedit_end[2] - self.draw_ctx.cursor[2]
--   end
--   return line_diff, column_diff, preedit_diff
end

function M:hide()
  assert(self.input_ctx ~= nil, "Not attached to input context")
  local buf = self.input_ctx.buf
  if buf ~= nil and vim_api.nvim_buf_is_valid(buf) then
    local cursor = self.input_ctx.cursor
    local anchor = vim_api.nvim_buf_get_extmark_by_id(buf, self.ns_id, 1, {})
    -- Clears out preedits
    -- vim_api.nvim_buf_set_text(
    --   buf,
    --   cursor[1] - 1,
    --   cursor[2],
    --   anchor[1],
    --   anchor[2],
    --   {''}
    -- )
    -- Clears out highlights
  end
end

return M
