local has_telescope, telescope = pcall(require, "telescope")
if not has_telescope then
  error "This plugin requires telescope.nvim (https://github.com/nvim-telescope/telescope.nvim)"
end

local actions = require "telescope.actions"
local action_state = require "telescope.actions.state"
local action_set = require "telescope.actions.set"
local finders = require "telescope.finders"
local make_entry = require "telescope.make_entry"
local pickers = require "telescope.pickers"
local previewers = require "telescope.previewers"
local sorters = require "telescope.sorters"
local utils = require "telescope.utils"
local conf = require("telescope.config").values
local log = require "telescope.log"

local scan = require "plenary.scandir"
local Path = require "plenary.path"
local os_sep = Path.path.sep

local flatten = vim.tbl_flatten
local filter = vim.tbl_filter


local external_file_types = {}
local external_open_cmd = ""


find_files = function(opts)
  local find_command = opts.find_command
  local hidden = opts.hidden
  local no_ignore = opts.no_ignore
  local follow = opts.follow
  local search_dirs = opts.search_dirs

  if search_dirs then
    for k, v in pairs(search_dirs) do
      search_dirs[k] = vim.fn.expand(v)
    end
  end

  if not find_command then
    if 1 == vim.fn.executable "fd" then
      find_command = { "fd", "--type", "f" }
      if hidden then
        table.insert(find_command, "--hidden")
      end
      if no_ignore then
        table.insert(find_command, "--no-ignore")
      end
      if follow then
        table.insert(find_command, "-L")
      end
      if search_dirs then
        table.insert(find_command, ".")
        for _, v in pairs(search_dirs) do
          table.insert(find_command, v)
        end
      end
    elseif 1 == vim.fn.executable "fdfind" then
      find_command = { "fdfind", "--type", "f" }
      if hidden then
        table.insert(find_command, "--hidden")
      end
      if no_ignore then
        table.insert(find_command, "--no-ignore")
      end
      if follow then
        table.insert(find_command, "-L")
      end
      if search_dirs then
        table.insert(find_command, ".")
        for _, v in pairs(search_dirs) do
          table.insert(find_command, v)
        end
      end
    elseif 1 == vim.fn.executable "rg" then
      find_command = { "rg", "--files" }
      if hidden then
        table.insert(find_command, "--hidden")
      end
      if no_ignore then
        table.insert(find_command, "--no-ignore")
      end
      if follow then
        table.insert(find_command, "-L")
      end
      if search_dirs then
        for _, v in pairs(search_dirs) do
          table.insert(find_command, v)
        end
      end
    elseif 1 == vim.fn.executable "find" and vim.fn.has "win32" == 0 then
      find_command = { "find", ".", "-type", "f" }
      if not hidden then
        table.insert(find_command, { "-not", "-path", "*/.*" })
        find_command = flatten(find_command)
      end
      if no_ignore ~= nil then
        log.warn "The `no_ignore` key is not available for the `find` command in `find_files`."
      end
      if follow then
        table.insert(find_command, "-L")
      end
      if search_dirs then
        table.remove(find_command, 2)
        for _, v in pairs(search_dirs) do
          table.insert(find_command, 2, v)
        end
      end
    elseif 1 == vim.fn.executable "where" then
      find_command = { "where", "/r", ".", "*" }
      if hidden ~= nil then
        log.warn "The `hidden` key is not available for the Windows `where` command in `find_files`."
      end
      if no_ignore ~= nil then
        log.warn "The `no_ignore` key is not available for the Windows `where` command in `find_files`."
      end
      if follow ~= nil then
        log.warn "The `follow` key is not available for the Windows `where` command in `find_files`."
      end
      if search_dirs ~= nil then
        log.warn "The `search_dirs` key is not available for the Windows `where` command in `find_files`."
      end
    end
  end

  if not find_command then
    print(
      "You need to install either find, fd, or rg. "
        .. "You can also submit a PR to add support for another file finder :)"
    )
    return
  end

  if opts.cwd then
    opts.cwd = vim.fn.expand(opts.cwd)
  end

  opts.entry_maker = opts.entry_maker or make_entry.gen_from_file(opts)

  opts.attach_mappings = function(prompt_bufnr, map)
    actions.select_default:replace(function()
      local entry = action_state.get_selected_entry()
      if entry[1] then
        local file_name = entry[1]
        for _, extension in ipairs(external_file_types) do
          local ending = "." .. extension
          if file_name:sub(-#ending) == ending then
            actions.close(prompt_bufnr)
            os.execute(external_open_cmd .. " \"" .. file_name .. "\"")
            return nil
          end
        end
        action_set.edit(prompt_bufnr, "edit")
      end
    end)
    return true
  end

  pickers.new(opts, {
    prompt_title = "Find Files",
    finder = finders.new_oneshot_job(find_command, opts),
    previewer = conf.file_previewer(opts),
    sorter = conf.file_sorter(opts),
  }):find()
end

file_browser = function(ops)
  opts = opts or {}

  local is_dir = function(value)
    return value:sub(-1, -1) == os_sep
  end

  opts.depth = opts.depth or 1
  opts.cwd = opts.cwd and vim.fn.expand(opts.cwd) or vim.loop.cwd()
  opts.new_finder = opts.new_finder
    or function(path)
      opts.cwd = path
      local data = {}

      scan.scan_dir(path, {
        hidden = opts.hidden or false,
        add_dirs = true,
        depth = opts.depth,
        on_insert = function(entry, typ)
          table.insert(data, typ == "directory" and (entry .. os_sep) or entry)
        end,
      })
      table.insert(data, 1, ".." .. os_sep)

      local maker = function()
        local mt = {}
        mt.cwd = opts.cwd
        mt.display = function(entry)
          local hl_group
          local display = utils.transform_path(opts, entry.value)
          if is_dir(entry.value) then
            display = display .. os_sep
            if not opts.disable_devicons then
              display = (opts.dir_icon or "") .. " " .. display
              hl_group = "Default"
            end
          else
            display, hl_group = utils.transform_devicons(entry.value, display, opts.disable_devicons)
          end

          if hl_group then
            return display, { { { 1, 3 }, hl_group } }
          else
            return display
          end
        end

        mt.__index = function(t, k)
          local raw = rawget(mt, k)
          if raw then
            return raw
          end

          if k == "path" then
            local retpath = Path:new({ t.cwd, t.value }):absolute()
            if not vim.loop.fs_access(retpath, "R", nil) then
              retpath = t.value
            end
            if is_dir(t.value) then
              retpath = retpath .. os_sep
            end
            return retpath
          end

          return rawget(t, rawget({ value = 1 }, k))
        end

        return function(line)
          local tbl = { line }
          tbl.ordinal = Path:new(line):make_relative(opts.cwd)
          return setmetatable(tbl, mt)
        end
      end

      return finders.new_table { results = data, entry_maker = maker() }
    end

  pickers.new(opts, {
    prompt_title = "File Browser",
    finder = opts.new_finder(opts.cwd),
    previewer = conf.file_previewer(opts),
    sorter = conf.file_sorter(opts),
    attach_mappings = function(prompt_bufnr, map)
      actions.select_default:replace(function()
        local entry = action_state.get_selected_entry()
        if is_dir(entry.path) then
          local new_cwd = vim.fn.expand(action_state.get_selected_entry().path:sub(1, -2))
          local current_picker = action_state.get_current_picker(prompt_bufnr)
          current_picker.cwd = new_cwd
          current_picker:refresh(opts.new_finder(new_cwd), { reset_prompt = true })
        elseif entry[1] then
          local file_name = entry[1]
          for _, extension in ipairs(external_file_types) do
            local ending = "." .. extension
            if file_name:sub(-#ending) == ending then
              actions.close(prompt_bufnr)
              os.execute(external_open_cmd .. " \"" .. file_name .. "\"")
              return nil
            end
          end
          action_set.edit(prompt_bufnr, "edit")
        end
      end)

      local create_new_file = function()
        local current_picker = action_state.get_current_picker(prompt_bufnr)
        local file = action_state.get_current_line()
        if file == "" then
          print(
            "To create a new file or directory(add "
              .. os_sep
              .. " at the end of file) "
              .. "write the desired new into the prompt and press <C-e>. "
              .. "It works for not existing nested input as well."
              .. "Example: this"
              .. os_sep
              .. "is"
              .. os_sep
              .. "a"
              .. os_sep
              .. "new_file.lua"
          )
          return
        end

        local fpath = current_picker.cwd .. os_sep .. file
        if not is_dir(fpath) then
          actions.close(prompt_bufnr)
          Path:new(fpath):touch { parents = true }
          vim.cmd(string.format(":e %s", fpath))
        else
          Path:new(fpath:sub(1, -2)):mkdir { parents = true }
          local new_cwd = vim.fn.expand(fpath)
          current_picker.cwd = new_cwd
          current_picker:refresh(opts.new_finder(new_cwd), { reset_prompt = true })
        end
      end

      map("i", "<C-e>", create_new_file)
      map("n", "<C-e>", create_new_file)
      return true
    end,
  }):find()
end

return telescope.register_extension {
  setup = function(ext_config)
    external_file_types = ext_config.external_file_types or {"pdf", "png", "jpg", "gif", "mp4"}
    external_open_cmd = ext_config.external_open_cmd or "xdg-open"
  end,
  exports = {
    find_files = find_files,
    file_browser = file_browser,
  },
}
