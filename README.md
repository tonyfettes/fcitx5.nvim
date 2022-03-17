# fcitx5.nvim

[WIP but already in maintenance] Fcitx5 client in neovim

## Reminds

This plugin needs to be run with corresponding input method frontend **disabled**
in either your Neovim UI (terminal emulator or GUI), or Fcitx5.

## Demo

<video src="https://user-images.githubusercontent.com/29998228/143730510-fd5299e9-4487-4831-bba3-0132086dce17.mp4" width="100%"></video>

## Install

If you use `packer.nvim`,
```lua
use {
  'tonyfettes/fcitx5.nvim'
  tag = 'v0.0.1-alpha',
  rocks = {'dbus_proxy', 'lgi'}
}
```

Then, check if corresponding Input method frontend is disabled in Fcitx5
configuration, if your terminal/GUI support that. Otherwise, your terminal/GUI
will capture your keystrokes and sent them to Fcitx5 instead of Neovim.

## Setup

The example below shows the default values.
```vim
lua<<EOF
require'fcitx5'.setup = {
  ui = {
    separator = '',
    padding = { left = 1, right = 1 }
  }
}
EOF

hi link Fcitx5CandidateNormal None
hi link Fcitx5CandidateSelected Search
hi link Fcitx5PreeditNormal None
hi link Fcitx5PreeditUnderline Underline
hi link Fcitx5PreeditHighLight IncSearch
hi link Fcitx5PreeditDontCommit None
hi link Fcitx5PreeditBold Bold
hi Fcitx5PreeditStrike gui=strikethrough
hi link Fcitx5PreeditItalic Italic
```

## Quick Start

```lua
use {
  'tonyfettes/fcitx5.nvim',
  config = {
    -- Load `fcitx5.nvim`
    require'fcitx5'.setup {}
    -- Map <M-Tab> to toggle between most recent two input methods.
    vim.cmd[[inoremap <M-Tab> <Cmd>lua require'fcitx5'.toggle()<CR>]]
  },
  -- Add luarocks dependencies
  rocks = { 'lgi', 'dbus_proxy' }
}
```

## Roadmap

- [x] Fix error on exit
- [x] Switchable input method and group (currently hardcoded to 'rime')
- [x] Break into two windows for pre-edit and candidate list respectively
- [x] Select candidates with function
- [x] Highlight
  - [x] Pre-edit highlight
- [x] UI glitch on first keystroke after insert
- [x] Candidate list margin
- [ ] Commit when focus out
- [ ] True Client side pre-edit support.
- [ ] Double-line mode, i.e. pre-edit is embedded in input method panel.
- [ ] Horizontal/Vertical layout
- [ ] Command-line support
- [ ] \(Perhaps\) `CursorMovedI/InsertCharPre` to `nvim_buf_attach()`
- [ ] \(Perhaps\) Show current input method and input group using dedicated window
- [ ] <del>If `'wrap'` is not set, scroll horizontal if pre-edit is too long, otherwise move to next line.</del> Too hard.
