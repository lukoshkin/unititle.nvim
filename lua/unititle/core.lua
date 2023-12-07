local api = vim.api
unpack = unpack or table.unpack

local M = {}
M.emphasized_titles = {}
M.title_section_sep = ' : '  -- may be overridden in `.setup` call


local function tbl_cnt (tbl)
  if tbl == nil then
    return 0
  end
  return vim.tbl_count(tbl)
end


local function minmax_len_among_lists (lists, opts)
  local subid = function (elem)
    if opts and opts.tuple_id then
      return elem[opts.tuple_id]
    end
    return elem
  end

  if tbl_cnt(lists) == 1 then
    return tbl_cnt(subid(lists[next(lists)]))
  end

  local ext_len, cond
  if opts ~= nil and opts.mode == 'max' then
    ext_len = 0
    cond = function (b) return #b > ext_len end
  else
    ext_len = 1 / 0
    cond = function (b) return #b < ext_len end
  end

  vim.tbl_map(function(b)
    if cond(subid(b)) then
      ext_len = #subid(b)
    end
  end, lists)

  return ext_len
end


local function get_active_bufs ()
  local bufs = api.nvim_list_bufs()
  bufs = vim.tbl_filter(function (b) return vim.bo[b].buflisted end, bufs)
  return bufs
end


-- function find_active_bufs (pat)
--   local bufs = get_active_bufs()
--   bufs = vim.tbl_filter(function (b)
--     return api.nvim_buf_get_name(b):match(pat)
--   end, bufs)
--   return bufs
-- end


local function similar_buf_names ()
  local similar = {}
  local bufs = get_active_bufs()
  vim.tbl_map(function (bnr)
    local name = api.nvim_buf_get_name(bnr)
    local stem = vim.fs.basename(name)
    similar[stem] = similar[stem] or {}
    similar[stem][name] = name
  end, bufs)
  return similar
end


local function _tail_alignment_trim(kv_pairs)
  local last_same
  local min_len = minmax_len_among_lists(kv_pairs, { tuple_id = 2 })
  local i = 0

  while i < min_len do
    local all_same = true
    local ref = kv_pairs[1][2]
    ref = ref[#ref - i]

    for j = 2, #kv_pairs do
      local elem = kv_pairs[j][2]
      if elem[#elem - i] ~= ref then
        all_same = false
        i = i + 1
        break
      end
    end

    if all_same then
      for _, kv in pairs(kv_pairs) do
        last_same = table.remove(kv[2], #kv[2] - i)
      end
      min_len = min_len - 1
    end
  end

  local k1, v1 = unpack(kv_pairs[1])
  if #v1 < 1 then
    v1 = { last_same }
  end

  return kv_pairs, k1, v1
end


local function tail_alignment_trim (similar)
  local kv_pairs = {}
  for k, v in pairs(similar) do
    table.insert(kv_pairs, {k, v})
  end

  local emphasized = {}
  table.sort(kv_pairs, function (a, b) return #a[2] < #b[2] end)

  local k1, v1
  for _ = 1, #kv_pairs-1 do
    kv_pairs, k1, v1 = _tail_alignment_trim(kv_pairs)
    table.remove(kv_pairs, 1)
    emphasized[k1] = v1
  end

  local kn, vn = unpack(kv_pairs[#kv_pairs])
  emphasized[kn] = vn
  return emphasized
end


-- local function distinct_parent_ids (similar)
--   local parent_ids = {}
--   --- Prevent from going further when not needed.
--   if similar == nil or tbl_cnt(similar) < 2 then
--     return parent_ids
--   end
--
--   local max_len = minmax_len_among_lists(similar, { mode = 'max' })
--   for i = 1, max_len do
--     local notna = {}
--     vim.tbl_map(
--       function (parents)
--         if parents[i] ~= nil then
--           table.insert(notna, parents[i])
--         end
--       end, similar)
--     local all_same = #notna > 1
--     for j = 2, #notna do
--       if notna[j] ~= notna[1] then
--         all_same = false
--         break
--       end
--     end
--     if not all_same then
--       table.insert(parent_ids, i)
--     end
--   end
--   return parent_ids
-- end


local function remove_common_prefix (similar)
  if tbl_cnt(similar) < 2 then
    return
  end

  local min_len = minmax_len_among_lists(similar)
  --- Why not to 0:
  --- a/b  after transform (with 0)  b
  --- a/                             ''
  while min_len > 1 do
    local prev_name = nil
    for _, parents in pairs(similar) do
      local name = parents[1]
      if prev_name ~= nil and name ~= prev_name then
        return
      end
      prev_name = name
    end
    min_len = min_len - 1
    for _, parents in pairs(similar) do
      table.remove(parents, 1)
    end
  end
end


local function lazy_merging (emphasized)
  local titles = {}
  local nbufs = tbl_cnt(emphasized)

  local i = 0
  local freqs
  while tbl_cnt(freqs) < nbufs do
    freqs = {}
    for key, parents in pairs(emphasized) do
      local elem = parents[#parents - i]
      local sep = ''
      if elem and titles[key] and titles[key] ~= '' then
        sep = M.title_section_sep
      end
      titles[key] = (elem or '') .. sep .. (titles[key] or '')
      if #titles[key] > 0 then
        freqs[titles[key]] = (freqs[titles[key]] or 0) + 1
      end
    end
    i = i + 1
  end

  return titles
end


function M.emphasize_similar (buf_name)
  local stem = vim.fs.basename(buf_name)
  local similar = similar_buf_names()[stem]
  if similar == nil or tbl_cnt(similar) < 2 then
    return ""
  end

  for key_name, name in pairs(similar) do
    name = vim.fs.dirname(name)
    similar[key_name] = vim.split(name, '/')
  end

  remove_common_prefix(similar)
  local emphasized = tail_alignment_trim(similar)
  M.emphasized_titles = lazy_merging(emphasized)
  return M.emphasized_titles[buf_name]
end


-- function M.emphasize_similar (buf_name)
--   local stem = vim.fs.basename(buf_name)
--   local similar = similar_buf_names()[stem]
--   if similar == nil or tbl_cnt(similar) < 2 then
--     return ""
--   end

--   for key_name, name in pairs(similar) do
--     name = vim.fs.dirname(name)
--     similar[key_name] = vim.split(name, '/')
--   end

--   remove_common_prefix(similar)
--   local par_ids = distinct_parent_ids(similar)
--   local emphasized = {}
--   for _, id in pairs(par_ids) do
--     for key_name, parents in pairs(similar) do
--       emphasized[key_name] = emphasized[key_name] or {}
--       table.insert(emphasized[key_name], parents[id])
--     end
--   end

--   --- Again:
--   --- a/b  after the code above  b   after the loop below  b
--   --- a/                         ""                        a
--   for key_name, parents in pairs(similar) do
--     if #emphasized[key_name] == 0 then
--       table.insert(emphasized[key_name], parents[#parents])
--     end
--   end

--   M.emphasized_titles = lazy_merging(emphasized)
--   return M.emphasized_titles[buf_name]
-- end


function M.set_unique_winbar ()
  local name = api.nvim_buf_get_name(0)
  if string.match(name, '%%') then
    return
  end

  name = M.emphasized_titles[name] or vim.fs.basename(name)
  vim.wo.winbar = name

  local ok, navic = pcall(require, 'nvim-navic')
  local sep = M.title_section_sep  -- alias

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
