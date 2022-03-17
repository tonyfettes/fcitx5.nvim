local vim_api = vim.api
local strwidth = vim.fn.strwidth
local max = math.max

---@class ui.candidate.vertical.padding
---@field left string
---@field right string

---@class ui.candidate.vertical.config
---@field follow 'cursor'|'anchor'
---@field separator string
---@field padding ui.candidate.vertical.padding

---@class ui.candidate.vertical : ui.widget
---@field draw_ctx ui.context
---@field config ui.candidate.vertical.config

local M = {}

M.ns_id = vim_api.nvim_create_namespace('fcitx5-candidate-vertical')

---@return ui.candidate.vertical
M.new = function ()
  return {
    ns_id = vim_api.nvim_create_namespace('fcitx5-candidate-vertical'),
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

---@param widget ui.candidate.vertical
---@param config ui.candidate.vertical.config
M.setup = function (widget, config)
  widget.config = config
end

---@param widget ui.candidate.vertical
M.attach = function (widget)
  widget.draw_ctx = widget.draw_ctx or {}
  widget.draw_ctx.win = nil
  widget.draw_ctx.buf = widget.draw_ctx.buf or nil
end

---@param widget ui.candidate.horizontal
---@param context ui.context
M.sync = function (widget, context)
  widget.input_ctx = context
end

M.detach = function (widget)
  widget:hide()
  widget.input_ctx = nil
end

---@param widget ui.candidate.vertical
local function create_buf(widget)
  if widget.draw_ctx.buf == nil then
    widget.draw_ctx.buf = vim_api.nvim_create_buf(false, true)
    vim_api.nvim_buf_set_name(widget.draw_ctx.buf, 'fcitx5-candidate')
  end
  return widget.draw_ctx.buf
end

---@param widget ui.candidate.vertical
---@param geometry ui.candidate.vertical.geometry
local function open_win(widget, geometry)
  if widget.draw_ctx.win == nil then
    local win_config = {
      relative = 'cursor',
      row = 1,
      col = 0,
      width = geometry.width,
      height = geometry.height,
      style = 'minimal',
      zindex = 300,
    }
    vim_api.nvim_win_call(widget.input_ctx.win, function ()
      widget.draw_ctx.win = vim_api.nvim_open_win(widget.draw_ctx.buf, false, win_config)
    end)
  else
    vim_api.nvim_win_set_width(widget.draw_ctx.win, geometry.width)
    vim_api.nvim_win_set_height(widget.draw_ctx.win, geometry.height)
  end
end

---@class ui.candidate.vertical.geometry
---@field height number
---@field width number

---@param candidates string[][]
---@param candidate_index number
---@param separator string
---@param padding ui.candidate.vertical.padding
---@return string[][] hl_candidates
---@return ui.candidate.vertical.geometry geometry
local function format_candidates(candidates, candidate_index, separator, padding)
  ---@type ui.candidate.vertical.geometry
  local geometry = {
    height = #candidates,
    width = 0,
  }
  ---@type string[]
  local hl_candidates = {}
  for i, candidate in ipairs(candidates) do
    ---@type string
    local cated_candidate = padding.left .. table.concat(candidate) .. padding.right
    if i == candidate_index + 1 then
      table.insert(hl_candidates, {cated_candidate, 'Fcitx5CandidateSelected'})
    else
      table.insert(hl_candidates, {cated_candidate, 'Fcitx5CandidateNormal'})
    end
    geometry.width = max(geometry.width, strwidth(cated_candidate))
  end
  return hl_candidates, geometry
end

---@param widget ui.candidate.vertical
---@param candidates string[]
---@param candidate_index number
M.update = function (widget, _, _, candidates, candidate_index)
  local hl_candidates, geometry = format_candidates(candidates, widget.config.separator, widget.config.padding)
  local buf = create_buf(widget)
  for i, hl_candidate in ipairs(hl_candidates) do
    local text, hl = unpack(hl_candidate)
    vim_api.nvim_buf_set_lines(buf, i - 1, i, true, {text})
    vim_api.nvim_buf_add_highlight(buf, widget.ns_id, hl, i - 1, 0, #text)
  end

  -- Displays candidates window
  local padding_width = #widget.config.padding.left + #widget.config.padding.right
  if geometry.width > padding_width then
    open_win(widget, geometry)
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
