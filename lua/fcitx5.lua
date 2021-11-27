local M = {}
local vim_api = vim.api
local glib = require'lgi'.GLib
local ctx = glib.MainLoop():get_context()

local dbus = require'fcitx5.dbus'
local ui = require'fcitx5.ui'

M.ns_id = nil
M.ui = nil
M.initialized = false

M.display = function ()
  if M.initialized == false then
    M.init()
  end
  M.ui:attach(vim_api.nvim_get_current_win())
end

M.clear = function ()
  M.ui:hide()
  dbus.focus_out()
end

local keys = {}

---@param byte number
M.process_key = function (byte)
  table.insert(keys, byte)
  -- print("keys: " .. vim.inspect(keys))
  local is_accepted = dbus.send_key(byte)
  ctx:iteration(true)
  if is_accepted then
    vim.v.char = ''
  end
end

M.move_cursor = function ()
  local d_line, d_cursor, d_length = M.ui:move_cursor()
  -- M.process_key(0xff08)
  -- M.process_key(0xff53)
  if d_line > 0 then
    -- Enter
    M.process_key(0xff0d)
  elseif d_cursor > 0 then
    -- Right
    for _ = 1, d_cursor, 1 do
      M.process_key(0xff53)
    end
  elseif d_cursor < 0 then
    -- Delete
    for _ = -1, d_length, -1 do
      M.process_key(0xff08)
    end
    -- Left
    for _ = -1, d_cursor - d_length, -1 do
      M.process_key(0xff51)
    end
  end
end

M.destroy = function ()
  M.ui:destroy()
  dbus.disconnect()
end

M.init = function ()
  if M.initialized == false then
    M.ns_id = vim_api.nvim_create_namespace("fcitx5.nvim")
    M.ui = ui.new(M.ns_id)
    dbus.connect()
    dbus.set_commit_cb(function (_, commit_string)
        M.ui:commit(commit_string)
    end)
    dbus.set_update_ui_cb(function (_, preedits, cursor, aux_up, aux_down, candidates, candidate_index, layout_hint, has_prev, has_next)
      if vim.fn.mode() == 'i' then
        M.ui:update(preedits, cursor, candidates)
      end
    end)
    dbus.focus_in()
    dbus.set_im('rime')
    vim.cmd[[
      augroup fcitx5_hook
        au!
        autocmd InsertEnter * lua require'fcitx5'.display()
        autocmd InsertCharPre * lua require'fcitx5'.process_key(string.byte(vim.v.char))
        autocmd InsertLeave * lua require'fcitx5'.clear()
        autocmd VimLeave * lua require'fcitx5'.destroy()
        autocmd User InsertBs lua require'fcitx5'.backspace()
      augroup END
    ]]
    M.initialized = true
  end
end

return M
