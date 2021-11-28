local M = {}
local vim_api = vim.api

---@class ui.input
---@field win number
---@field buf number
---@field cursor number[]

---@class ui.preedit
---@field win number
---@field buf number
---@field cursor number
---@field length number

---@class ui
---@field ns_id number
---@field ext_id number | nil
---@field cursor_lock boolean
---@field input ui.input
---@field preedit ui.preedit
---@field attach function
---@field detach function
---@field destroy function
---@field update function
---@field commit function
---@field move_cursor function
---@field hide function

---Creates a new ui
---@param ns_id number
---@return ui
M.new = function (ns_id)
  ---@type ui
  local new_ui = {
    ns_id = ns_id,
    input = {},
    preedit = {},
    attach = M.attach,
    detach = M.detach,
    update = M.update,
    commit = M.commit,
    move_cursor = M.move_cursor,
    hide = M.hide,
    destroy = M.destroy,
  }
  return new_ui
end

---Set attach information of ui
---@param ui ui
---@param win number
M.attach = function (ui, win)
  assert(win)
  ui.input = ui.input or {}
  if win == 0 then
    ui.input.win = vim_api.nvim_get_current_win()
  else
    ui.input.win = win
  end
  ui.input.buf = vim_api.nvim_win_get_buf(win)
  ui.input.cursor = vim_api.nvim_win_get_cursor(ui.input.win)
  ui.preedit = ui.preedit or {}
  ui.preedit.win = nil
  ui.preedit.buf = ui.preedit.buf or nil
  ui.preedit.cursor = 0
end

---@param ui ui
M.detach = function (ui)
  ui:hide()
  ui.input = {}
end

---Update ui
---@param ui ui
---@param preedits string[]
---@param cursor number
---@param candidates string[]
M.update = function (ui, preedits, cursor, candidates)
  for i, preedit in ipairs(preedits) do
    preedits[i] = preedit[1]
  end
  local preedit_string = table.concat(preedits, "")
  for i, candidate in ipairs(candidates) do
    candidates[i] = table.concat(candidate, ": ")
  end
  local candidates_string = table.concat(candidates, ", ")
  -- print("preedit: " .. preedit_string .. ", cursor: " .. cursor)
  vim.schedule(function ()
    -- If buf is absent, new one
    if ui.preedit.buf == nil then
      ui.preedit.buf = vim_api.nvim_create_buf(false, true)
      vim_api.nvim_buf_set_name(ui.preedit.buf, 'fcitx5-preedit')
      vim.cmd([[
        augroup fcitx5_preedit
          au!
          autocmd CursorMovedI <buffer=]] .. ui.preedit.buf .. [[> lua require'fcitx5'.move_cursor()
          autocmd InsertCharPre <buffer=]] .. ui.preedit.buf .. [[> lua require'fcitx5'.process_key(string.byte(vim.v.char))
        augroup END
      ]])
    end
    local preedit_buf = ui.preedit.buf

    -- Set content of buffer
    -- print("preedit: " .. preedit_string)
    vim_api.nvim_buf_set_lines(preedit_buf, 0, -1, true, {preedit_string})
    ui.preedit.length = #preedit_string
    -- print("candidates: " .. candidates_string)
    vim_api.nvim_buf_set_extmark(preedit_buf, ui.ns_id, 0, 0, {
      id = 1,
      virt_lines = {{{ candidates_string, "None" }}},
    })

    -- Calculate window width
    -- TODO: strwidth/strdisplaywidth
    local strwidth = vim.fn.strwidth
    local win_width = math.max(strwidth(preedit_string), strwidth(candidates_string))

    -- If needs to be displayed
    if win_width ~= 0 then

      win_width = math.max(win_width, 2)

      -- Set window width
      if ui.preedit.win == nil then
        local win_config = {
          relative = 'cursor',
          row = 0,
          col = 0,
          width = win_width,
          height = 2,
          style = 'minimal'
        }
        vim_api.nvim_win_call(ui.input.win, function ()
          ui.preedit.win = vim_api.nvim_open_win(preedit_buf, false, win_config)
        end)
      else
        vim_api.nvim_win_set_width(ui.preedit.win, win_width)
      end
      -- Set cursor position
      -- print("cursor: " .. vim.inspect(cursor))
      if cursor >= 0 then
        ui.cursor_lock = true
        vim_api.nvim_win_set_cursor(ui.preedit.win, { 1, cursor })
        ui.preedit.cursor = cursor
      end
      vim_api.nvim_set_current_win(ui.preedit.win)
    else
      ui:hide()
    end
  end)
end

---@param ui ui
---@return number, number, number
M.move_cursor = function (ui)
  if ui.cursor_lock == true then
    -- Cancel CursorMovedI introduced by setting preedit
    ui.cursor_lock = false
    return 0, 0, 0
  else
    local length = vim_api.nvim_get_current_line()
    local d_preedit_length = #length - ui.preedit.length
    ui.preedit.length = length

    local line, cursor = unpack(vim_api.nvim_win_get_cursor(ui.preedit.win))
    local d_line = line - 1
    local d_cursor = cursor - ui.preedit.cursor
    -- print("prv: " .. ui.preedit.cursor .. ", cur: " .. cursor .. ", delta: " .. delta)
    ui.preedit.cursor = cursor
    return d_line, d_cursor, d_preedit_length
  end
end

---Commit string to ui
---@param ui ui
---@param commit_string string
M.commit = function (ui, commit_string)
  vim.schedule(function ()
    local input = ui.input
    local lno, cno = unpack(vim_api.nvim_win_get_cursor(input.win))
    lno = lno - 1
    -- print("commit_string: " .. commit_string)
    vim_api.nvim_buf_set_text(input.buf, lno, cno, lno, cno, {commit_string})
    vim_api.nvim_win_set_cursor(input.win, {lno + 1, cno + #commit_string})
    -- print("curpos: " .. vim.inspect(vim_api.nvim_win_get_cursor(0)))
    ui:hide()
  end)
end

---Hide ui
---@param ui ui
M.hide = function (ui)
  local preedit_win = ui.preedit.win
  if preedit_win ~= nil and vim_api.nvim_win_is_valid(preedit_win) then
    -- if ui.preedit.length ~= 0 then
    --   ui:commit(vim_api.nvim_buf_get_lines(ui.preedit.buf, 0, 1, true)[1])
    -- end
    vim_api.nvim_win_hide(preedit_win)
    ui.preedit.win = nil
  end
end

---@param ui ui
M.destroy = function (ui)
  ui:detach()
  local preedit_buf = ui.preedit.buf
  if preedit_buf and vim_api.nvim_buf_is_valid(preedit_buf) then
    
    -- print("del_extmark: arg: " .. preedit_buf .. ui.ns_id .. 1)
    vim_api.nvim_buf_del_extmark(preedit_buf, ui.ns_id, 1)
    -- vim_api.nvim_buf_detach(preedit_buf)
  end
end

return M
