local M = {}
local vim_api = vim.api

local ns_id = nil
-- local ext_id = nil

M.set_namespace = function (ns_id_in)
  ns_id = ns_id_in
end

local preedit_buf = nil
local preedit_win = nil
local input_win = nil
local input_pos = nil
local input_buf = nil

M.show = function ()
  input_win = vim_api.nvim_get_current_win()
  input_pos = vim_api.nvim_win_get_cursor(input_win)
  input_pos[1] = input_pos[1] - 1
  print("input_pos: " .. vim.inspect(input_pos))
  input_buf = vim_api.nvim_win_get_buf(input_win)
  if preedit_buf == nil then
    preedit_buf = vim_api.nvim_create_buf(false, true)
    vim_api.nvim_buf_set_name(preedit_buf, 'fcitx5-preedit')
    vim.cmd[[
    augroup fcitx5_preedit_cursor_move
      au!
      autocmd CursorMovedI <buffer> require'fcitx5'.cursor_moved()
    augroup END
    ]]
  end
  preedit_win = nil
end

local preedit = nil
local cursorpos = 0
local candidates = nil

M.update = function (preedit_in, cursorpos_in, candidates_in)
  preedit = preedit_in
  cursorpos = cursorpos_in
  candidates = candidates_in
  vim.schedule(function ()
    vim_api.nvim_buf_set_lines(preedit_buf, 0, -1, true, {preedit, candidates})
    if #preedit ~= 0 then
      local strwidth = vim.fn.strwidth
      local win_width = math.max(strwidth(preedit), strwidth(candidates), 3)
      if preedit_win == nil then
        local win_config = {
          -- relative = 'win',
          -- win = input_win,
          -- bufpos = input_pos,
          relative = 'cursor',
          row = 0,
          col = 0,
          width = win_width,
          height = 2,
          style = 'minimal'
        }
        vim_api.nvim_win_call(input_win, function ()
          preedit_win = vim_api.nvim_open_win(preedit_buf, true, win_config)
          vim_api.nvim_buf_set_lines(preedit_buf, 0, -1, true, {preedit, candidates})
        end)
      else
        vim_api.nvim_win_set_width(preedit_win, win_width)
        vim_api.nvim_set_current_win(preedit_win)
      end
      -- print("cursorpos: " .. vim.inspect(cursorpos))
      vim_api.nvim_win_set_cursor(preedit_win, { 1, cursorpos + 1 })
    else
      M.hide()
    end
  end)
end

local commit_string = ''

M.commit = function (commit_string_in)
  commit_string = commit_string_in
  vim.schedule(function ()
    local lno, cno = unpack(input_pos)
    -- print("input_pos: " .. vim.inspect(input_pos))
    print("commit_string: " .. commit_string)
    vim_api.nvim_buf_set_text(input_buf, lno, cno, lno, cno, {commit_string})
    input_pos[2] = input_pos[2] + #commit_string
    vim_api.nvim_win_set_cursor(input_win, {input_pos[1] + 1, input_pos[2]})
    print("curpos: " .. vim.inspect(vim_api.nvim_win_get_cursor(0)))
    M.hide()
  end)
end

M.hide = function ()
  -- if ns_id and ext_id and preedit_buf then
  --   vim_api.nvim_buf_del_extmark(preedit_buf, ns_id, ext_id)
  -- end
  if preedit_win ~= nil and vim_api.nvim_win_is_valid(preedit_win) then
    vim_api.nvim_win_hide(preedit_win)
    preedit_win = nil
  end

  -- if preedit_win ~= nil and vim_api.nvim_win_is_valid(preedit_win) then
  --   vim_api.nvim_win_close(preedit_win, true)
  --   preedit_win = nil
  -- end
end

M.clear = function ()
end

-- local buf = nvim.nvim_create_buf(false, true)
-- local win = nvim.nvim_open_win(buf, false, {
--   relative = 'cursor',
--   width = 10,
--   height = 1,
--   row = 1,
--   col = 0,
--   focusable = false,
--   style = 'minimal',
-- })
-- nvim.nvim_buf_set_lines(buf, 0, 1, false, {tostring(win)})
-- print(win)

-- local lno = 5
-- local cno = 5
-- local mark_id = vim.api.nvim_buf_set_extmark(bnr, ns_id, lno - 1, cno, opts)

return M
