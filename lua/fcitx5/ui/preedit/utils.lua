---@class ui.preedit : ui.widget
---@field move_cursor function

local M = {}

M.highlight_group_index = {
  [8] = 'Fcitx5PreeditUnderline',
  [16] = 'Fcitx5PreeditHighLight',
  [32] = 'Fcitx5PreeditDontCommit',
  [64] = 'Fcitx5PreeditBold',
  [128] = 'Fcitx5PreeditStrike',
  [256] = 'Fcitx5PreeditItalic',
}

---@return string, number[], number[]
M.format_preedits = function (preedits)
  local sep_loc = { 0 }
  local width = 0
  local hl = { }
  local unformatted_preedit_list = {}
  for _, preedit in ipairs(preedits) do
    table.insert(unformatted_preedit_list, preedit[1])
    width = width + #preedit[1]
    table.insert(sep_loc, width)
    table.insert(hl, preedit[2])
  end
  local preedit_string = table.concat(unformatted_preedit_list, "")
  table.insert(sep_loc, #preedit_string)
  return preedit_string, sep_loc, hl
end

return M
