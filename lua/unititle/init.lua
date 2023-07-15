local ut = require'unititle.core'
local api = vim.api
local M = {}


local function apply_to_normal_wins (fn)
  for _, win in pairs(vim.tbl_filter(function(win)
    return api.nvim_win_get_config(win).relative == ''
  end, api.nvim_tabpage_list_wins(0)))
  do
    api.nvim_win_call(win, fn)
  end
end


function M.setup (conf)
  conf = conf or {}
  ut.title_section_sep = conf.title_section_sep or ' : '
  local aug_ut = api.nvim_create_augroup('Unititle', {clear = true})

  --- Set up 'winbar'.
  if vim.fn.has'nvim-0.8' == 1 then
    api.nvim_create_autocmd({ "BufWinEnter" }, {
      callback = function ()
        local name = api.nvim_buf_get_name(0)
        --- If opening multiple buffers at the same time,
        --- update titles only once.
        if not ut.aucmd_event_locked then
          vim.schedule(function ()
            ut.emphasize_similar(name)
            apply_to_normal_wins(ut.set_default_winbar)
            ut.aucmd_event_locked = nil
          end)
          ut.aucmd_event_locked = true
          --- As a result, if opening several buffers,
          --- just one operation will be scheduled.
        end
      end,
      group = aug_ut,
    })
    if conf.default_winbar then
      api.nvim_create_autocmd({ "CursorMoved" }, {
        callback = ut.set_default_winbar,
        group = aug_ut,
      })
    end
  else
    vim.notify("'Unititle' requires Nvim >= 0.8" )
  end

  M._set_up = true
end


return M
