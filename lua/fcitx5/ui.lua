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

---@class ui.candidates
---@field win number
---@field buf number

---@class ui.padding
---@field left string
---@field right string
---@field width number

---@class ui
---@field ns_id number
---@field ext_id number | nil
---@field cursor_lock boolean
---@field input ui.input
---@field preedit ui.preedit
---@field candidates ui.candidates
---@field separator string
---@field padding ui.padding
---@field attach function
---@field detach function
---@field destroy function
---@field update function
---@field commit function
---@field move_cursor function
---@field hide function


---@class ui.config.padding
---@field left number
---@field right number

---@class ui.config
---@field separator string
---@field padding ui.config.padding
--
---Creates a new ui
---@param ns_id number
---@return ui
M.new = function (ns_id, config)
  ---@type ui
  local new_ui = {
    ns_id = ns_id,
    input = {},
    preedit = {},
    candidates = {},
    separator = config.separator,
    padding = {
      left = string.rep(' ', config.padding.left),
      right = string.rep(' ', config.padding.right),
      width = config.padding.left + config.padding.right
    },
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
  ui.preedit.length = 0

  ui.candidates = ui.candidates or {}
  ui.candidates.win = nil
  ui.candidates.buf = ui.candidates.buf or nil
end

---@param ui ui
M.detach = function (ui)
  ui:hide(ui.preedit)
  ui:hide(ui.candidates)
  ui.input = {}
end

---@return string, number[], number[]
local function format_preedits(preedits)
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

---@param ui ui
---@candidates string[][]
local function format_candidates(ui, candidates)
  local sep_loc = { 0 }
  local width = 0
  local padding_width = ui.padding.width
  local cated_list = {}
  for _, candidate in ipairs(candidates) do
    local cated_candidate = table.concat(candidate)
    table.insert(cated_list, cated_candidate)
    width = width + #cated_candidate + padding_width
    table.insert(sep_loc, width)
  end
  local sep_padded = ui.padding.left .. ui.separator .. ui.padding.right
  local candidates_string = ui.padding.left .. table.concat(cated_list, sep_padded) .. ui.padding.right
  table.insert(sep_loc, #candidates_string)
  return candidates_string, sep_loc
end

---@param ui ui
---@return nil
local function create_preedit_buf(ui)
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
  return ui.preedit.buf
end

---@param ui ui
local function create_candidates_buf(ui)
  if ui.candidates.buf == nil then
    ui.candidates.buf = vim_api.nvim_create_buf(false, true)
    vim_api.nvim_buf_set_name(ui.candidates.buf, 'fcitx5-candidate')
  end
  return ui.candidates.buf
end

---@param ui ui
---@param win_width number
---@param cursor number
local function open_preedit_win(ui, win_width, cursor)
  if ui.preedit.win == nil then
    local win_config = {
      relative = 'cursor',
      row = 0,
      col = 0,
      width = win_width,
      height = 1,
      style = 'minimal'
    }
    vim_api.nvim_win_call(ui.input.win, function ()
      ui.preedit.win = vim_api.nvim_open_win(ui.preedit.buf, false, win_config)
      vim_api.nvim_win_set_option(ui.preedit.win, 'winhl', 'NormalFloat:Fcitx5PreeditNormal')
      vim_api.nvim_win_set_option(ui.preedit.win, 'cursorline', true)
    end)
  else
    vim_api.nvim_win_set_width(ui.preedit.win, win_width)
  end
  vim_api.nvim_set_current_win(ui.preedit.win)

  -- Set cursor position
  if cursor >= 0 then
    ui.cursor_lock = true
    vim_api.nvim_win_set_cursor(ui.preedit.win, { 1, cursor })
    ui.preedit.cursor = cursor
  end
end

---@param ui ui
---@param win_width number
local function open_candidates_win(ui, win_width)
  if ui.candidates.win == nil then
    local win_config = {
      relative = 'cursor',
      row = 1,
      col = 0,
      width = win_width,
      height = 1,
      style = 'minimal'
    }
    vim_api.nvim_win_call(ui.input.win, function ()
      ui.candidates.win = vim_api.nvim_open_win(ui.candidates.buf, false, win_config)
    end)
  else
    vim_api.nvim_win_set_width(ui.candidates.win, win_width)
  end
end

---Update ui
---@param ui ui
---@param preedits string[]
---@param cursor number
---@param candidates string[]
---@param candidate_index number
M.update = function (ui, preedits, cursor, candidates, candidate_index)

  -- Format input
  local preedit_string, preedit_sep_loc, preedit_hl = format_preedits(preedits)
  local candidates_string, candidates_sep_loc = format_candidates(ui, candidates)

  vim.schedule(function ()
    -- If buffer are absent, creates them
    local preedit_buf = create_preedit_buf(ui)
    local candidates_buf = create_candidates_buf(ui)

    -- Set content of buffer
    -- print("preedit: " .. preedit_string)
    vim_api.nvim_buf_set_lines(preedit_buf, 0, -1, true, {preedit_string})
    ui.preedit.length = #preedit_string
    for i, hl in ipairs(preedit_hl) do
      print("hl: " .. hl)
      if bit.band(hl, 8) ~= 0 then
        vim_api.nvim_buf_add_highlight(preedit_buf, ui.ns_id, 'Fcitx5PreeditUnderline', 0, preedit_sep_loc[i], preedit_sep_loc[i + 1])
      end
      if bit.band(hl, 16) ~= 0 then
        vim_api.nvim_buf_add_highlight(preedit_buf, ui.ns_id, 'Fcitx5PreeditHighLight', 0, preedit_sep_loc[i], preedit_sep_loc[i + 1])
      end
      if bit.band(hl, 32) ~= 0 then
        vim_api.nvim_buf_add_highlight(preedit_buf, ui.ns_id, 'Fcitx5PreeditDontCommit', 0, preedit_sep_loc[i], preedit_sep_loc[i + 1])
      end
      if bit.band(hl, 64) ~= 0 then
        vim_api.nvim_buf_add_highlight(preedit_buf, ui.ns_id, 'Fcitx5PreeditBold', 0, preedit_sep_loc[i], preedit_sep_loc[i + 1])
      end
      if bit.band(hl, 128) ~= 0 then
        vim_api.nvim_buf_add_highlight(preedit_buf, ui.ns_id, 'Fcitx5PreeditStrike', 0, preedit_sep_loc[i], preedit_sep_loc[i + 1])
      end
      if bit.band(hl, 256) ~= 0 then
        vim_api.nvim_buf_add_highlight(preedit_buf, ui.ns_id, 'Fcitx5PreeditItalic', 0, preedit_sep_loc[i], preedit_sep_loc[i + 1])
      end
    end
    -- print("candidates: " .. candidates_string)
    vim_api.nvim_buf_set_lines(candidates_buf, 0, -1, true, {candidates_string})
    vim_api.nvim_buf_add_highlight(candidates_buf, ui.ns_id, 'Fcitx5CandidateNormal', 0, 0, #candidates_string)
    if candidate_index >= 0 and candidate_index < #candidates then
      vim_api.nvim_buf_add_highlight(candidates_buf, ui.ns_id, 'Fcitx5CandidateSelected', 0, candidates_sep_loc[candidate_index + 1], candidates_sep_loc[candidate_index + 2])
    end

    -- Calculate window width
    -- TODO: strwidth/strdisplaywidth
    local strwidth = vim.fn.strwidth

    -- Displays preedit window
    local preedit_width = vim.fn.strwidth(preedit_string)
    if preedit_width ~= 0 then
      open_preedit_win(ui, preedit_width + 1, cursor)
    else
      ui:hide(ui.preedit)
    end

    -- Displays candidates window
    local candidates_width = strwidth(candidates_string)
    if candidates_width > ui.padding.width then
      open_candidates_win(ui, candidates_width)
    else
      ui:hide(ui.candidates)
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
    ui.preedit.length = #length

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
    ui:hide(ui.preedit)
    ui:hide(ui.candidates)
  end)
end

---Hide ui
---@param ui ui
---@param widget ui.preedit|ui.candidates
M.hide = function (ui, widget)
  local win = widget.win
  if win ~= nil and vim_api.nvim_win_is_valid(win) then
    -- if ui.preedit.length ~= 0 then
    --   ui:commit(vim_api.nvim_buf_get_lines(ui.preedit.buf, 0, 1, true)[1])
    -- end
    vim_api.nvim_win_hide(win)
    widget.win = nil
  end
end

---@param ui ui
M.destroy = function (ui)
  ui:detach()
  local candidates_buf = ui.preedit.buf
  if candidates_buf and vim_api.nvim_buf_is_valid(candidates_buf) then
    -- print("del_extmark: arg: " .. candidates_buf .. ui.ns_id .. 1)
    vim_api.nvim_buf_del_extmark(candidates_buf, ui.ns_id, 1)
    -- vim_api.nvim_buf_detach(preedit_buf)
  end
end

return M
