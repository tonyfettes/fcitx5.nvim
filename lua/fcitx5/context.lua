local M = {}
local vim_api = vim.api
local g_ctx = require'lgi'.GLib.MainLoop():get_context()

local dbus = require'fcitx5.dbus'
local ui = require'fcitx5.ui'

---@class context
---@field destroy function
---@field ui ui

---Creates a fcitx5 context
---@param ns number
---@param win number
---@return context
M.new = function (ns, win)
  if win == 0 then
    win = vim_api.nvim_get_current_win()
  end
  local new_ui = ui.new(ns, win)
  local ret = {
    ui = new_ui,
    destroy = M.destroy,
  }
  dbus.connect()
  dbus.set_commit_cb(function (_, commit_string)
    new_ui:commit(commit_string)
  end)
  dbus.set_update_ui_cb(function (_, preedits, cursor, aux_up, aux_down, candidates, candidate_index, layout_hint, has_prev, has_next)
    if vim.fn.mode() == 'i' then
      new_ui:update(preedits, cursor, candidates)
    end
  end)
  vim.cmd[[
    augroup fcitx5_hook
      au!
      autocmd InsertEnter <buffer> lua require'fcitx5'.enter()
      autocmd InsertCharPre <buffer> lua require'fcitx5'.enter()
      autocmd InsertLeave <buffer> lua require'fcitx5'.leave()
      autocmd WinClosed 
    augroup END
  ]]
  return ret
end

M.enter = function ()
  dbus.focus_in()
  dbus.set_im('rime')
end

M.leave = function ()
  dbus.focus_out()
end

---Destroys a fcitx5 context
---@param ctx context
M.destroy = function (ctx)
  dbus.disconnect()
end

return M
