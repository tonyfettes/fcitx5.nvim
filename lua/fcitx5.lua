local M = {}

local vim_api = vim.api
local ctx = require'lgi'.GLib.MainLoop():get_context()

local dbus = require'fcitx5.dbus'
local ui = require'fcitx5.ui'

local initialized = false
local attached = false
local config = {
  ui = {
    separator = '',
    padding = {left = 1, right = 1},
  }
}

local function empty_func()
  error("fcitx5.nvim not initialized")
end

local ns_id = vim_api.nvim_create_namespace('fcitx5.nvim')
local c_ui = ui.new(ns_id, config.ui)

M.setup = function (config_in)
  if config_in and config_in.ui then
    config.ui.separator = config_in.ui.separator or config.ui.separator
    config.ui.padding = config_in.ui.padding or config.ui.padding
  end
  c_ui:config(config.ui)
end

dbus.connect()
dbus.set_commit_cb(function (_, commit_string)
  c_ui:commit(commit_string)
end)
dbus.set_update_ui_cb(function (_, preedits, cursor, aux_up, aux_down, candidates, candidate_index, layout_hint, has_prev, has_next)
  if string.match(vim_api.nvim_get_mode().mode, 'i') ~= nil then
    M.ui_info = {
      preedits = preedits,
      cursor = cursor,
      candidates = candidates,
      candidate_index = candidate_index
    }
    c_ui:update(preedits, cursor, candidates, candidate_index)
  end
end)

---@param byte number
local function process_key(byte)
  local is_accepted = dbus.send_key(byte)
  ctx:iteration()
  if is_accepted then
    vim.v.char = ''
  end
end

local function move_cursor()
  local d_line, d_cursor, d_length = c_ui:move_cursor()
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

M.toggle = function ()
  dbus.toggle()
  c_ui:update({}, 0, {{'', dbus.get_im()}}, -1)
end

M.ig = {}
local function update_ig ()
  M.ig.name = dbus.get_ig()
  M.ig.info = dbus.get_ig_info(M.ig.name)
  M.ig.list = dbus.get_ig_list()
  M.ig.index = 0
  for index, ig_name in ipairs(M.ig.list) do
    if ig_name == M.ig.name then
      M.ig.index = index
    end
  end
end
update_ig()
dbus.set_ig_update_cb(update_ig)

---@param forward boolean
M.enum_im = function (forward)
  local current = M.ig.info.current
  local im_list = M.ig.info.im_list
  local im_size = #im_list
  if forward then
    current = current + 1
  else
    current = current - 1
  end
  if current <= im_size and current > 0 then
    M.ig.info.current = current
    dbus.set_im(im_list[current][1])
  end
end

---@param forward boolean
M.enum_ig = function (forward)
  local index = M.ig.index
  local ig_size = #M.ig.list
  if forward then
    index = index + 1
  else
    index = index - 1
  end
  if index <= ig_size and index > 0 then
    M.ig.index = index
    dbus.set_ig(M.ig.list[index])
  end
end

M.attach = function ()
  if attached == false then
    dbus.focus_in()
    c_ui:attach(vim_api.nvim_get_current_win())
    M.process_key = process_key
    M.move_cursor = move_cursor

    ---@param forward boolean
    M.enum_candidate = function (forward)
      if M.ui_info ~= nil then
        local candidate_index = M.ui_info.candidate_index
        local candidate_size = #M.ui_info.candidates
        if forward then
          candidate_index = candidate_index + 1
        else
          candidate_index = candidate_index - 1
        end
        if candidate_index < candidate_size and candidate_index >= 0 then
          dbus.select_candidate(candidate_index)
          M.ui_info.candidate_index = candidate_index
          c_ui:update(M.ui_info.preedits, M.ui_info.cursor, M.ui_info.candidates, M.ui_info.candidate_index)
        end
      end
    end
    vim.cmd[[
      augroup fcitx5_trigger
        au!
        autocmd InsertCharPre <buffer> lua require'fcitx5'.process_key(string.byte(vim.v.char))
      augroup END
    ]]
    attached = true
  end
end

M.detach = function ()
  if attached == true then
    dbus.focus_out()
    ctx:iteration()
    c_ui:detach()
    M.process_key = empty_func
    M.move_cursor = empty_func
    M.ui_info = nil
    M.enum_candidate = empty_func
    vim.cmd[[
      autocmd! fcitx5_trigger
      augroup! fcitx5_trigger
    ]]
    attached = false
  end
end

M.destroy = function ()
  M.detach()
  if initialized == true then
    dbus.disconnect()
    c_ui:destroy()
    M.toggle = empty_func
    M.ig = nil
    M.enum_im = empty_func
    M.enum_ig = empty_func
    M.attach = empty_func
    M.detach = empty_func
    M.destroy = empty_func
    vim.cmd[[
      autocmd! fcitx5_hook
      augroup! fcitx5_hook
    ]]
    initialized = false
  end
end

vim.cmd[[
  augroup fcitx5_hook
    au!
    autocmd InsertEnter * lua require'fcitx5'.attach()
    autocmd InsertLeave * lua require'fcitx5'.detach()
    autocmd VimLeave * lua require'fcitx5'.destroy()
  augroup END
]]

vim.cmd[[
  hi default link Fcitx5CandidateNormal None
  hi default link Fcitx5CandidateSelected Search
  hi default link Fcitx5PreeditNormal None
  hi default link Fcitx5PreeditUnderline Underline
  hi default link Fcitx5PreeditHighLight IncSearch
  hi default link Fcitx5PreeditDontCommit None
  hi default link Fcitx5PreeditBold Bold
  hi default Fcitx5PreeditStrike gui=strikethrough
  hi default link Fcitx5PreeditItalic Italic
]]

-- If user is current in insert mode, attach to current buffer immediately
if string.match(vim_api.nvim_get_mode().mode, 'i') ~= nil then
  M.attach()
end

initialized = true

return M
