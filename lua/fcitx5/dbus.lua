local M = {}
local ffi = require'ffi'
local lgi = require'lgi'
local glib = lgi.GLib
local gobj = lgi.GObject

local p = require'dbus_proxy'

local ic = nil
local im = nil
local ctrl = nil

local function is_err(ok, err)
  if ok == nil and err ~= nil then
    return true
  else
    return false
  end
end

M.connect = function ()
  ctrl = p.Proxy:new {
    bus = p.Bus.SESSION,
    name = "org.fcitx.Fcitx5",
    path = "/controller",
    interface = "org.fcitx.Fcitx.Controller1"
  }

  im = p.Proxy:new {
    bus = p.Bus.SESSION,
    name = "org.fcitx.Fcitx5",
    path = "/org/freedesktop/portal/inputmethod",
    interface = "org.fcitx.Fcitx.InputMethod1",
  }

  local ok, err
  ok, err = im:CreateInputContext{ { "program", "fcitx5.nvim" } }
  assert(ok, tostring(err))
  if ok == nil and err ~= nil then
    return err
  end

  local ic_path, _ = unpack(ok)

  -- Connect to input context
  ic = p.Proxy:new {
    bus = p.Bus.SESSION,
    name = "org.fcitx.Fcitx5",
    path = ic_path,
    interface = "org.fcitx.Fcitx.InputContext1"
  }

  -- Set ClientSideInputPanel
  -- local capabilities = bit.lshift(1, 39)
  local capabilities = 0xe001800070
  ok, err = ic:SetCapability(capabilities)
  if ok == nil and err ~= nil then
    return err
  end
end

M.focus_in = function ()
  ic:FocusIn()
end

M.set_im = function (target_im)
  ctrl:SetCurrentIM(target_im)
end

M.focus_out = function ()
  ic:FocusOut()
end

M.send_key = function (char)
  local ok, err = ic:ProcessKeyEvent(string.byte(char), 0, 0, false, 0)
  if is_err(ok, err) then
    print("Error: " .. vim.inspect(err))
  else
    return ok
  end
end

M.reset = function ()
  ic:Reset()
end

M.disconnect = function ()
  ic:DestroyIC()
end

M.set_commit_cb = function (cb)
  ic:connect_signal(cb, "CommitString")
end

M.set_update_ui_cb = function (cb)
  -- proxy, preedit, cursorpos, aux_up, aux_down, candidates, candidate_index, layout_hint, has_prev, has_next
  ic:connect_signal(cb, "UpdateClientSideUI")
end

return M
