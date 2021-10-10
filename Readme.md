# telescope-better-find-files.nvim
A file picker for [Telescope](https://github.com/nvim-telescope/telescope.nvim). This is basically a copy of the find\_files builtin of Telescope, the only difference being that it can open non-text file in external programs.

## Installation
Using [Vim Plug](https://github.com/junegunn/vim-plug):
```
Plug 'Triton171/telescope-better-find-files.nvim'
```

Additionally you need to load this Plugin for Telescope:
```
lua << EOF
require('telescope').load_extension('better_find_files')
EOF
```


## Configuration
This extension can be configured using `extensions` field inside Telescope setup function:
```
require'telescope'.setup {
  extensions = {
    better_find_files = {
      -- A list of file extensions that should be opened with an external program
      external_file_types = {"pdf", "png", "jpg", "gif", "mp4"},
      -- The command to open a file
      external_open_cmd = "xdg-open"
    }
  },
}
```
The configuration shown here is used as a default in case no explicit configuration is given
