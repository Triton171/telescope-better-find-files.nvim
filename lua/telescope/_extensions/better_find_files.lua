local has_telescope, telescope = pcall(require, "telescope")
if not has_telescope then
  error "This plugin requires telescope.nvim (https://github.com/nvim-telescope/telescope.nvim)"
end


local make_entry = require "telescope.make_entry"
local conf = require("telescope.config").values
local log = require "telescope.log"
local finders = require "telescope.finders"
local pickers = require "telescope.pickers"


local external_file_types = {}
local external_open_cmd = ""


better_find_files = function(opts)
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

  -- Allow opening external files
  -- TODO: Untested
  opts.attach_mappings = function(prompt_bufnr, map)
    actions.select_default:replace(function()
      local entry = action_state.get_selected_entry()
      if entry[1] then
        local file_name = entry[1]
        local ending = ".pdf"
        if file_name:sub(-#ending) == ending then
          actions.close(prompt_bufnr)
          os.execute("xdg-open " .. file_name)
          return nil
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



return telescope.register_extension {
  setup = function(ext_config)
    external_file_types = ext_config.external_file_types or {"pdf", "png", "jpg", "gif", "mp4"}
    external_open_cmd = ext_config.external_open_cmd or "xdg-open"
  end,
  exports = {
    better_find_files = better_find_files
  },
}
