local M = {}

local vim_api = vim.api
local ctx = require'lgi'.GLib.MainLoop():get_context()

local dbus = require'fcitx5.dbus'
local ui = require'fcitx5.ui'

local initialized = false
local attached = false

---@class config
---@field ui ui.config

local config = {
  ---@type ui.config
  ui = {
    preedit = {
      style = 'embedded',
    },
    candidate = {
      style = 'horizontal',
      config = {
        follow = 'anchor',
        position = 'down',
        separator = '',
        padding = {
          left = ' ',
          right = ' ',
        }
      }
    },
  },
}

local function empty_func()
  error('fcitx5.nvim not initialized')
end

---@param config_in config
M.setup = function (config_in)
  if config_in and config_in.ui then
    config.ui.preedit = config_in.ui.preedit or config.ui.preedit
    config.ui.candidate = config_in.ui.candidate or config.ui.candidate
  end
  ui:setup(config.ui)
end

dbus.connect()
dbus.set_commit_cb(function (_, commit_string)
  ui:commit(commit_string)
  -- Get UpdateClientSideUI signal
  ctx:iteration()
end)
dbus.set_update_ui_cb(function (_, preedits, cursor, aux_up, aux_down, candidates, candidate_index, layout_hint, has_prev, has_next)
  if string.match(vim_api.nvim_get_mode().mode, 'i') ~= nil then
    M.ui_info = {
      preedits = preedits,
      cursor = cursor,
      candidates = candidates,
      candidate_index = candidate_index,
    }
    ui:update(preedits, cursor, candidates, candidate_index)
  end
end)

local function delete_character()
  M.process_key(0xff08)
end

local function confirm()
  M.process_key(0xff0d)
end

---@param byte number
---@return boolean is_accepted
local function process_key(byte)
  local is_accepted = dbus.send_key(byte)
  if is_accepted then
    vim.v.char = ''
  end
  ctx:iteration()
  return is_accepted
end

local function notify_cursor_moved()
  local line, column, preedit = ui:get_cursor_movement()
  print('cursor movement: ' .. vim.inspect({line, column, preedit}))
  -- (+-, *) line
  if line > 0 then
    -- Enter
    for _ = 1, line, 1 do
      M.process_key(0xff0d)
    end
  elseif column > 0 then
    -- Right
    for _ = 1, column, 1 do
      M.process_key(0xff53)
    end
  elseif column < 0 then
    -- Delete
    for _ = -1, preedit, -1 do
      M.process_key(0xff08)
    end
    -- Left
    for _ = -1, column - preedit, -1 do
      M.process_key(0xff51)
    end
  end
  -- ctx:iteration()
end

M.toggle = function ()
  dbus.toggle()
  ui:update({}, 0, {{'', dbus.get_im()}}, -1)
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
    ui:attach(vim_api.nvim_get_current_win(), vim_api.nvim_get_current_buf())
    M.process_key = process_key
    M.notify_cursor_moved = notify_cursor_moved

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
          ui:update(M.ui_info.preedits, M.ui_info.cursor, M.ui_info.candidates, M.ui_info.candidate_index)
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
    ui:detach()
    M.process_key = empty_func
    M.get_cursor_movement = empty_func
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
    ui:destroy()
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
