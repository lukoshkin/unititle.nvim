# Similar Buffers Distinguished

This plugin provides unique titles for buffers with similar names opened in
Neovim at once. One can use it for their purpose (as an ancillary tool) or set
it as a part of winbar title together with [navic](
https://github.com/SmiteshP/nvim-navic)'s output.

## Installation

* With [**Packer**](https://github.com/wbthomason/packer.nvim)
  ```lua
  use {
    'lukoshkin/auenv.nvim',
    requires = 'SmiteshP/nvim-navic',
    --- Omit the requirement in case you don't need the navic's output
  }
  ```

  Possible options:
  ```lua
  use {
    'lukoshkin/auenv.nvim',
    requires = 'SmiteshP/nvim-navic',
    config = function ()
      require'auenv'.setup {
        title_section_sep = ':',
        default_winbar = true,
      }
    end
  }
  ```
