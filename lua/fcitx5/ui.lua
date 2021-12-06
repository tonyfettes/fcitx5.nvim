local M = {}
local vim_api = vim.api

---@class ui.context
---@field win number
---@field buf number
---@field cursor number[]

---@class ui.widget
---@field ns_id number
---@field input_ctx nil|ui.context
---@field setup function
---@field attach function
---@field detach function
---@field update function
---@field hide function
---@field cursor_lock boolean

---@class ui.widgets
---@field preedit ui.preedit
---@field candidate ui.candidate

---@class ui
---@field ns_id number
---@field widgets ui.widgets
---@field cursor_lock boolean
---@field input ui.context
---@field setup function
---@field attach function
---@field detach function
---@field update function
---@field commit function
---@field move_cursor function
---@field hide function

---@class ui.config.widget
---@field style string
---@field config table

---@class ui.config.candidate : ui.config.widget
---@field style "'vertical'"|"'horizontal'"
---@field config ui.candidate.vertical.config|ui.candidate.horizontal.config

---@class ui.config.preedit : ui.config.widget
---@field style "'attached'"|"'embedded'"

---@alias ui.config table<string, ui.config.widget>

---Creates a new ui
---@param ns_id number
---@return ui
M.new = function (ns_id)
  ---@type ui
  local new_ui = {
    ns_id = ns_id,
    widgets = {},
    input = {},
    setup = M.setup,
    attach = M.attach,
    detach = M.detach,
    update = M.update,
    commit = M.commit,
    move_cursor = M.move_cursor,
    hide = M.hide,
  }
  return new_ui
end

---@param ui ui
---@param config ui.config
M.setup = function (ui, config)
  for name, widget_config in pairs(config) do
    ---@type ui.widget
    local widget = require('fcitx5.ui.' .. name .. '.' .. widget_config.style)
    widget:setup(widget_config.config)
    assert(ui.widgets[name] == nil)
    ui.widgets[name] = widget
  end
end

---Set attach information of ui
---@param ui ui
---@param win number
M.attach = function (ui, win)
  ui.input = ui.input or {}
  if win == nil or win == 0 then
    win = vim_api.nvim_get_current_win()
  end
  ---@type number
  local buf = vim_api.nvim_win_get_buf(win)
  if ui.input.win ~= win or buf ~= ui.input.buf then
    ui:detach()
    ui.input.win = win
    ui.input.buf = buf
    ---@type number[]
    ui.input.cursor = vim_api.nvim_win_get_cursor(ui.input.win)
    for _, widget in pairs(ui.widgets) do
      widget:attach(ui.input)
    end
  end
end

---@param ui ui
M.detach = function (ui)
  for _, widget in pairs(ui.widgets) do
    widget:hide()
  end
  ui.input = {}
end

---Update ui
---@param ui ui
---@param preedits string[]
---@param cursor number
---@param candidates string[]
---@param candidate_index number
M.update = function (ui, preedits, cursor, candidates, candidate_index)
  for _, widget in pairs(ui.widgets) do
    vim.schedule(function ()
      widget:update(preedits, cursor, candidates, candidate_index)
      if widget.cursor_lock == true then
        ui.cursor_lock = true
      end
    end)
  end
end

---@param ui ui
---@return number, number, number
M.move_cursor = function (ui)
  if ui.cursor_lock == true then
    -- Cancel CursorMovedI introduced by setting preedit
    ui.cursor_lock = false
    return 0, 0, 0
  else
    return ui.widgets.preedit:move_cursor()
  end
end

---Commit string to ui
---@param ui ui
---@param commit_string string
M.commit = function (ui, commit_string)
  vim.schedule(function ()
    local input = ui.input
    local lno, cno = unpack(vim_api.nvim_win_get_cursor(input.win))
    lno = lno - 1
    vim_api.nvim_buf_set_text(input.buf, lno, cno, lno, cno, {commit_string})
    vim_api.nvim_win_set_cursor(input.win, {lno + 1, cno + #commit_string})
    ui.input.cursor = {lno, cno + #commit_string}
    for _, widget in pairs(ui.widgets) do
      widget:hide()
    end
  end)
end

---Hide ui
---@param ui ui
M.hide = function (ui)
  for _, widget in pairs(ui.widgets) do
    widget:hide()
  end
end

return M
