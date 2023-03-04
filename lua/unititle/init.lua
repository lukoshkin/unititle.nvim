local ut = require'unititle.core'
local api = vim.api
local M = {}


function M.setup (conf)
  conf = conf or {}
  ut.title_section_sep = conf.title_section_sep or ':'
  local aug_ut = api.nvim_create_augroup('Unititle', {clear = true})

  --- Set up 'winbar'.
  if vim.fn.has'nvim-0.8' == 1 then
    api.nvim_create_autocmd({ "BufWinEnter" }, {
      callback = function ()
        local name = api.nvim_buf_get_name(0)
        require'unititle.core'.emphasize_similar(name)
      end,
      group = aug_ut,
    })
    if conf.default_winbar then
      api.nvim_create_autocmd({ "CursorMoved" }, {
        callback = require'unititle.core'.set_default_winbar,
        group = aug_ut,
      })
    end
  else
    vim.notify("'Unititle' requires Nvim >= 0.8" )
  end

  M._set_up = true
end


return M
