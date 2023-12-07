local ut = require "unititle.core"
local api = vim.api
local M = {}


local function apply_to_normal_wins(fn)
  for _, win in pairs(vim.tbl_filter(function(win)
    return api.nvim_win_get_config(win).relative == ""
  end, api.nvim_tabpage_list_wins(0)))
  do
    api.nvim_win_call(win, fn)
  end
end

local function update_all_winbars()
  local name = api.nvim_buf_get_name(0)
  --- `aucmd_event_locked` is useful when opening multiple buffers at the same
  --- time. It will prevent from updating the same set of titles several times.
  if not ut.aucmd_event_locked then
    vim.schedule(function()
      ut.emphasize_similar(name)
      apply_to_normal_wins(ut.set_unique_winbar)
      ut.aucmd_event_locked = nil
    end)
    --- As a result, if opening several buffers,
    --- just one operation will be scheduled.
    ut.aucmd_event_locked = true
  end
end


local function update_current_winbar()
  local win = api.nvim_get_current_win()
  if api.nvim_win_get_config(win).relative ~= "" then
    return
  end

  ut.set_unique_winbar()
end


function M.setup(conf)
  conf = conf or {}
  ut.title_section_sep = conf.title_section_sep or " : "
  local aug_ut = api.nvim_create_augroup("Unititle", { clear = true })

  --- Set up "winbar".
  if vim.fn.has "nvim-0.8" == 1 then
    api.nvim_create_autocmd({ "BufWinEnter" }, {
      callback = update_all_winbars,
      group = aug_ut,
    })
    if conf.navic_enabled then
      api.nvim_create_autocmd({ "CursorMoved" }, {
        callback = update_current_winbar,
        group = aug_ut,
      })
    end
  else
    vim.notify("'Unititle' requires Nvim >= 0.8")
  end

  M._set_up = true
end

return M
