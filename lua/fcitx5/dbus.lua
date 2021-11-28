local M = {}

local p = require'dbus_proxy'

local ic = nil
local im = nil
local ctrl = nil

local function ensure_result(ok, err)
  assert(err == nil, tostring(err))
  return ok
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

M.toggle = function ()
  ctrl:Toggle()
end

M.focus_in = function ()
  ic:FocusIn()
end

M.focus_out = function ()
  ic:FocusOut()
end

---@param target_im string
M.set_im = function (target_im)
  ctrl:SetCurrentIM(target_im)
end

---@return string
M.get_im = function ()
  return ensure_result(ctrl:CurrentInputMethod())
end

---@return string
M.get_ig = function ()
  return ensure_result(ctrl:CurrentInputMethodGroup())
end

---@return string[]
M.get_ig_list = function ()
  return ensure_result(ctrl:InputMethodGroups())
end

---@class ig_info
---@field current number
---@field layout string
---@field im_list string[][]

---@param ig string
---@return ig_info
M.get_ig_info = function (ig)
  local layout, im_list = unpack(ensure_result(ctrl:InputMethodGroupInfo(ig)))
  local current_im = M.get_im()
  local current = 0
  for index, im_info in ipairs(im_list) do
    if im_info[1] == current_im then
      current = index
    end
  end
  return {
    current = current,
    layout = layout,
    im_list = im_list
  }
end

---@param cb function
M.set_ig_update_cb = function (cb)
  ctrl:connect_signal(cb, "InputMethodGroupsChanged")
end

---@param name string
M.set_ig = function (name)
  ensure_result(ctrl:SwitchInputMethodGroup(name))
end

---@param char string
---@return boolean
M.send_key = function (char)
  return ensure_result(ic:ProcessKeyEvent(char, 0, 0, false, 0))
end

---@param index number
M.select_candidate = function (index)
  ensure_result(ic:SelectCandidate(index))
end

M.reset = function ()
  ic:Reset()
end

M.disconnect = function ()
  ic:DestroyIC()
end

---@param cb function
M.set_commit_cb = function (cb)
  ic:connect_signal(cb, "CommitString")
end

---@param cb function
M.set_update_ui_cb = function (cb)
  -- proxy, preedit, cursorpos, aux_up, aux_down, candidates, candidate_index, layout_hint, has_prev, has_next
  ic:connect_signal(cb, "UpdateClientSideUI")
end

---@param cb function
M.set_current_im_cb = function (cb)
  ic:connect_signal(cb, "CurrentIM")
end

return M
