local vim_api = vim.api
local strwidth = vim.fn.strwidth

---@class ui.candidate.horizontal.padding
---@field left string
---@field right string

---@class ui.candidate.horizontal.config
---@field follow "'cursor'"|"'anchor'"
---@field position "'up'"|"'down'"|"'tail'"
---@field separator string
---@field padding ui.candidate.horizontal.padding

---@class ui.candidate.horizontal : ui.widget
---@field draw_ctx ui.context
---@field config ui.candidate.horizontal.config

local M = {}

M.ns_id = vim_api.nvim_create_namespace('fcitx5-candidate-horizontal')

---@return ui.candidate.horizontal
M.new = function ()
  return {
    ns_id = vim_api.nvim_create_namespace('fcitx5-candidate-horizontal'),
    draw_ctx = nil,
    input_ctx = nil,
    config = nil,
    setup = M.setup,
    attach = M.attach,
    detach = M.detach,
    update = M.update,
    hide = M.hide,
  }
end

---@param widget ui.candidate.horizontal
---@param config ui.candidate.horizontal.config
M.setup = function (widget, config)
  widget.config = config
end

---@param widget ui.candidate.horizontal
---@param context ui.context
M.attach = function (widget, context)
  widget.draw_ctx = widget.draw_ctx or {}
  widget.draw_ctx.win = nil
  widget.draw_ctx.buf = widget.draw_ctx.buf or nil
  widget.input_ctx = context
end

M.detach = function (widget)
  widget:hide()
  widget.input_ctx = nil
end

---@param widget ui.candidate.horizontal
local function create_buf(widget)
  if widget.draw_ctx.buf == nil then
    widget.draw_ctx.buf = vim_api.nvim_create_buf(false, true)
    vim_api.nvim_buf_set_name(widget.draw_ctx.buf, 'fcitx5-candidate')
  end
  return widget.draw_ctx.buf
end

---@param widget ui.candidate.horizontal
---@return number row, number col
local function get_win_pos(widget)
  if widget.config.follow == 'anchor' then
    if widget.config.position == 'up' then
      return -1, 0
    elseif widget.config.position == 'down' then
      return 1, 0
    elseif widget.config.padding == 'tail' then
      return 0, 1
    end
  end
end

---@param widget ui.candidate.horizontal
---@param win_width number
local function open_win(widget, win_width)
  if widget.draw_ctx.win == nil then
    local row, col = get_win_pos(widget)
    local win_config = {
      relative = 'cursor',
      row = row,
      col = col,
      width = win_width,
      height = 1,
      style = 'minimal',
      zindex = 300,
    }
    vim_api.nvim_win_call(widget.input_ctx.win, function ()
      widget.draw_ctx.win = vim_api.nvim_open_win(widget.draw_ctx.buf, false, win_config)
    end)
  else
    vim_api.nvim_win_set_width(widget.draw_ctx.win, win_width)
  end
end

---@param candidates string[][]
---@param separator string
---@param padding ui.candidate.horizontal.padding
---@return string candidates
---@return number[] sep_loc
local function format_candidates(candidates, separator, padding)
  ---@type number[]
  local sep_loc = { 0 }
  local width = 0
  local padding_width = #padding.left + #padding.right
  ---@type string[]
  local cated_list = {}
  for _, candidate in ipairs(candidates) do
    local cated_candidate = table.concat(candidate)
    table.insert(cated_list, cated_candidate)
    width = width + #cated_candidate + padding_width
    table.insert(sep_loc, width)
  end
  ---@type string
  local sep_padded = padding.left .. separator .. padding.right
  ---@type string
  local candidates_string = padding.left .. table.concat(cated_list, sep_padded) .. padding.right
  table.insert(sep_loc, #candidates_string)
  return candidates_string, sep_loc
end

---@param widget ui.candidate.horizontal
---@param candidates string[]
---@param candidate_index number
M.update = function (widget, _, _, candidates, candidate_index)
  local content, sep_loc = format_candidates(candidates, widget.config.separator, widget.config.padding)
  local buf = create_buf(widget)
  vim_api.nvim_buf_set_lines(buf, 0, -1, true, {content})
  vim_api.nvim_buf_add_highlight(
  buf,
  widget.ns_id,
  'Fcitx5CandidateNormal',
  0, 0, #content
  )
  if candidate_index >= 0 and candidate_index < #candidates then
    vim_api.nvim_buf_add_highlight(
    buf,
    widget.ns_id,
    'Fcitx5CandidateSelected',
    0,
    sep_loc[candidate_index + 1],
    sep_loc[candidate_index + 2]
    )
  end

  -- Displays candidates window
  local win_width = strwidth(content)
  local padding_width = #widget.config.padding.left + #widget.config.padding.right
  if win_width > padding_width then
    open_win(widget, win_width)
  else
    widget:hide()
  end
end

M.hide = function (widget)
  local win = (widget.draw_ctx or {}).win
  if win ~= nil and vim_api.nvim_win_is_valid(win) then
    vim_api.nvim_win_hide(win)
    widget.draw_ctx.win = nil
  end
end

return M
