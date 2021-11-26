local M = {}
local loop = vim.loop;
local vim_api = vim.api;
local glib = require'lgi'.GLib
local ctx = glib.MainLoop():get_context()

local dbus = require'fcitx5.dbus'
local ui = require'fcitx5.ui'

local cursorpos = nil

local function update_ui(_, preedits, cursorpos_in, aux_up, aux_down, candidates, candidate_index, layout_hint, has_prev, has_next)
  if vim.fn.mode() == 'i' then
    for i, candidate in ipairs(candidates) do
      candidates[i] = table.concat(candidate, ": ")
    end
    local candidates_string = table.concat(candidates, ", ")
    -- print("candidates: " .. candidates_string)

    -- print("preedits: " .. vim.inspect(preedits))
    for i, preedit in ipairs(preedits) do
      preedits[i] = preedit[1]
    end
    local preedit_string = table.concat(preedits, " ")

    -- print("cursorpos: " .. vim.inspect(cursorpos))
    cursorpos = cursorpos_in
    print("cursorpos: " .. vim.inspect(cursorpos))
    ui.update(preedit_string, cursorpos, candidates_string)
  end
end

M.display = function ()
  ui.show()
end

M.clear = function ()
  dbus.reset()
  ui.hide()
end

local function commit_cb(_, commit_string)
  ui.commit(commit_string)
end

M.process_key = function (char)
  print("char: " .. char)
  local is_accepted = dbus.send_key(char)
  ctx:iteration(true)
  vim.v.char = ''
end

M.cursor_moved = function ()
  local current_pos = vim_api.nvim_win_get_cursor(0)[2] - 1
  local delta = current_pos - cursorpos
  if delta > 0 then
    for _ = 1, delta, 1 do
      M.process_key(0xff53)
    end
  else
    for _ = 1, delta, -1 do
      M.process_key(0xff51)
    end
  end
end

M.destroy = function ()
  dbus.disconnect()
end

M.init = function ()
  local ns_id = vim_api.nvim_create_namespace("fcitx5.lua")
  ui.set_namespace(ns_id)
  dbus.connect()
  dbus.set_commit_cb(commit_cb)
  dbus.set_update_ui_cb(update_ui)
  dbus.focus_in()
  dbus.set_im('rime')
end

vim.cmd[[
augroup fcitx5_hook
  au!
  autocmd InsertEnter * lua require'fcitx5'.display()
  autocmd InsertCharPre * lua require'fcitx5'.process_key(vim.v.char)
  autocmd InsertLeave * lua require'fcitx5'.clear()
  autocmd VimLeave * lua require'fcitx5'.destroy()
augroup END
]]

M.init()

return M
