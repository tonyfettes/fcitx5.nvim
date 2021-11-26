local M = {}
local vim_api = vim.api

local ns_id = nil
local ext_id = nil

M.set_namespace = function (ns_id_in)
  ns_id = ns_id_in
end

M.show = function (bufnr, position, preedit, candidates)
  local opts = {
    id = 1,
    virt_text = {{ preedit, "Comment" }},
    virt_text_pos = 'overlay',
    virt_lines = {{{candidates, "Comment"}}}
  }
  local lno, cno = unpack(position)
  ext_id = vim_api.nvim_buf_set_extmark(bufnr, ns_id, lno, cno, opts)
end

M.clear = function (bufnr)
  if ns_id and ext_id then
    vim_api.nvim_buf_del_extmark(bufnr, ns_id, ext_id)
  end
end

return M
