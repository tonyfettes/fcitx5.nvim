local vim_api = vim.api

---@class position
---@field [1] number
---@field [2] number

---@class ui.context
---@field win number
---@field buf number

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
---@field get_cursor_movement function
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

---@type ui
local M = {}

M.widgets = {}

M.input = {}

---@param config ui.config
function M:setup(config)
  for name, widget_config in pairs(config) do
    ---@type ui.widget
    local widget = require('fcitx5.ui.' .. name .. '.' .. widget_config.style)
    widget:setup(widget_config.config)
    assert(self.widgets[name] == nil)
    self.widgets[name] = widget
  end
end

---Set attach information of ui
---@param win number
---@param buf number
function M:attach(win, buf)
  self.input = self.input or {}
  self.input.win = win
  self.input.buf = buf
  for _, widget in pairs(self.widgets) do
    widget:attach(self.input)
  end
end

function M:detach()
  for _, widget in pairs(self.widgets) do
    widget:detach()
  end
  self.input = {}
end

---Update ui
---@param preedits string[]
---@param cursor number
---@param candidates string[]
---@param candidate_index number
function M:update(preedits, cursor, candidates, candidate_index)
  for _, widget in pairs(self.widgets) do
    vim.schedule(function ()
      widget:update(preedits, cursor, candidates, candidate_index)
      if widget.cursor_lock == true then
        self.cursor_lock = true
      end
    end)
  end
end

---@return number, number, number
function M:get_cursor_movement()
  if self.cursor_lock == true then
    -- Cancel CursorMovedI introduced by setting preedit
    self.cursor_lock = false
    return 0, 0, 0
  else
    return self.widgets.preedit:get_cursor_movement()
  end
end

---Commit string to ui
---@param commit_string string
function M:commit(commit_string)
  vim.schedule(function ()
    local input = self.input
    local lno, cno = unpack(self.input.cursor)
    lno = lno - 1
    vim_api.nvim_buf_set_text(input.buf, lno, cno, lno, cno, {commit_string})
    self.input.cursor = {lno + 1, cno + #commit_string}
    vim_api.nvim_win_set_cursor(input.win, self.input.cursor)
  end)
end

function M:hide()
  for _, widget in pairs(self.widgets) do
    widget:hide()
  end
end

return M
