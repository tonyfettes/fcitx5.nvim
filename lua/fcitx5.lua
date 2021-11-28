local M = {}
local vim_api = vim.api
local glib = require'lgi'.GLib
local ctx = glib.MainLoop():get_context()

local dbus = require'fcitx5.dbus'
local ui = require'fcitx5.ui'

M.initialized = false
M.attached = false

M.init = function ()
  if M.initialized == false then
    local ns_id = vim_api.nvim_create_namespace('fcitx5.nvim')
    local c_ui = ui.new(ns_id)
    dbus.connect()
    dbus.set_commit_cb(function (_, commit_string)
      c_ui:commit(commit_string)
    end)
    dbus.set_update_ui_cb(function (_, preedits, cursor, aux_up, aux_down, candidates, candidate_index, layout_hint, has_prev, has_next)
      if vim.fn.mode() == 'i' then
        c_ui:update(preedits, cursor, candidates)
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

    M.toggle = dbus.toggle

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
      if M.attached == false then
        dbus.focus_in()
        -- dbus.set_im('rime')
        c_ui:attach(vim_api.nvim_get_current_win())
        M.process_key = process_key
        M.move_cursor = move_cursor
        vim.cmd[[
          augroup fcitx5_trigger
            au!
            autocmd InsertCharPre <buffer> lua require'fcitx5'.process_key(string.byte(vim.v.char))
          augroup END
        ]]
        M.attached = true
      end
    end

    M.detach = function ()
      if M.attached == true then
        dbus.focus_out()
        c_ui:detach()
        M.process_key = nil
        M.move_cursor = nil
        vim.cmd[[
          augroup fcitx5_trigger
            au!
          augroup END
          augroup! fcitx5_trigger
        ]]
        M.attached = false
      end
    end

    M.destroy = function ()
      M.detach()
      if M.initialized == true then
        dbus.disconnect()
        c_ui:destroy()
        M.toggle = nil
        M.ig = nil
        M.enum_im = nil
        M.enum_ig = nil
        M.attach = nil
        M.detach = nil
        M.destroy = function () end
        vim.cmd[[
          augroup fcitx5_hook
            au!
          augroup END
          augroup! fcitx5_hook
        ]]
        M.initialized = false
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
    M.initialized = true
  end
end

M.destroy = function ()
end

return M
