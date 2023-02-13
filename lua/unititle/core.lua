local fn = vim.fn
local api = vim.api
local M = {}


local function tbl_cnt (tbl)
  local cnt = 0
  if tbl == nil then
    return 0
  end
  for _ in pairs(tbl) do
    cnt = cnt + 1
  end
  return cnt
end


local function minmax_len_among_lists (lists, opts)
  if tbl_cnt(lists) == 1 then
    return tbl_cnt(lists[next(lists)])
  end

  local ext_len, cond
  if opts ~= nil and opts.mode == 'max' then
    ext_len = 0
    cond = function (b) return #b > ext_len end
  else
    ext_len = 1 / 0
    cond = function (b) return #b < ext_len end
  end

  vim.tbl_map(function(b) if cond(b) then ext_len = #b end end, lists)
  return ext_len
end


function M.only_normal_windows ()
  local normal_windows = vim.tbl_filter(function (key)
    return api.nvim_win_get_config(key).relative == ''
  end, api.nvim_tabpage_list_wins(0))
  return normal_windows
end


function M.get_active_bufs ()
  local bufs = api.nvim_list_bufs()
  bufs = vim.tbl_filter(function (b) return vim.bo[b].buflisted end, bufs)
  return bufs
end


function M.find_active_bufs (pat)
  local bufs = M.get_active_bufs()
  bufs = vim.tbl_filter(function (b)
    return api.nvim_buf_get_name(b):match(pat)
  end, bufs)
  return bufs
end


function M.similar_buf_names ()
  local similar = {}
  local bufs = M.get_active_bufs()
  vim.tbl_map(function (bnr)
    local name = api.nvim_buf_get_name(bnr)
    local stem = vim.fs.basename(name)
    similar[stem] = similar[stem] or {}
    similar[stem][name] = name
  end, bufs)
  return similar
end


local function distinct_parent_ids (similar)
  local parent_ids = {}
  --- Prevent from going further when not needed.
  if similar == nil or tbl_cnt(similar) < 2 then
    return parent_ids
  end

  local max_len = minmax_len_among_lists(similar, { mode = 'max' })
  for i = max_len, 1, -1 do
    local notna = {}
    vim.tbl_map(
      function (parents)
        if parents[i] ~= nil then
          table.insert(notna, parents[i])
        end
      end, similar)
    local all_same = #notna > 1
    for j = 2, #notna do
      if notna[j] ~= notna[1] then
        all_same = false
        break
      end
    end
    if not all_same then
      table.insert(parent_ids, i)
    end
  end
  return parent_ids
end


local function remove_common_prefix (similar)
  if tbl_cnt(similar) < 2 then return end
  local min_len = minmax_len_among_lists(similar)
  while min_len > 0 do
    local all_same = true
    local prev_name = nil
    for _, parents in pairs(similar) do
      local name = parents[1]
      if prev_name ~= nil and name ~= prev_name then
        all_same = false
        return
      end
      prev_name = name
    end
    if all_same then
      min_len = min_len - 1
      for key, parents in pairs(similar) do
        table.remove(parents, 1)
      end
    end
  end
end


function M.unique_name (buf_name)
  local stem = vim.fs.basename(buf_name)
  local similar = M.similar_buf_names()[stem]
  if similar == nil or tbl_cnt(similar) < 2 then
    return ""
  end

  for key_name, name in pairs(similar) do
    name = vim.fs.dirname(name)
    similar[key_name] = vim.split(name, '/')
  end

  remove_common_prefix(similar)
  local par_ids = distinct_parent_ids(similar)
  local emphasized = {}
  for i = 0, #par_ids-1 do
    for key_name, parents in pairs(similar) do
      emphasized[key_name] = emphasized[key_name] or {}
      local id = #parents - par_ids[#par_ids - i]
      table.insert(emphasized[key_name], parents[id])
    end
  end

  for key_name, tbl in pairs(emphasized) do
    emphasized[key_name] = table.concat(tbl, ' : ')
  end

  return emphasized[buf_name]
end


function M.set_winbar ()
  local name = api.nvim_buf_get_name(0)
  local name = M.unique_name(name)
  vim.wo.winbar = name

  local ok, navic = pcall(require, 'nvim-navic')
  local sep = vim.g.winbar_first_sep  -- alias

  local lsp_loc
  if ok and navic.is_available() then
    lsp_loc = navic.get_location()
  else
    return
  end

  local wb = vim.wo.winbar or ''
  if wb:match(sep) ~= nil then
    wb = wb:match('^(.+)'..sep..'.*$')
  end

  if lsp_loc ~= '' then
    vim.wo.winbar = wb..sep..lsp_loc
  end
end


return M
