# fcitx5.nvim

[WIP] fcitx5 client in neovim

## Demo

<video src="https://user-images.githubusercontent.com/29998228/143730510-fd5299e9-4487-4831-bba3-0132086dce17.mp4" width="100%"></video>

## Install

packer.nvim

```lua
use {
  'tonyfettes/fcitx5.nvim'
  rocks = {'dbus_proxy', 'lgi'}
}
```

## Setup

The example below shows the default values.

```vim
" setup() can be called before/after the loading of fcitx5.nvim
lua<<EOF
require'fcitx5'.setup = {
  ui = {
    separator = '',
    padding = { left = 1, right = 1 }
  }
}
EOF

hi! link Fcitx5CandidateNormal None
hi! link Fcitx5CandidateSelected Search
hi! link Fcitx5PreeditNormal None
hi! link Fcitx5PreeditUnderline Underline
hi! link Fcitx5PreeditHighLight IncSearch
hi! link Fcitx5PreeditDontCommit None
hi! link Fcitx5PreeditBold Bold
hi Fcitx5PreeditStrike gui=strikethrough
hi! link Fcitx5PreeditItalic Italic
```

## Example Usage

```vim
" Map Shift+Tab to toggle the most recent two input methods.
" Function toggle() must be called after init().
inoremap <S-Tab> <Cmd>lua require'fcitx5'.toggle()<CR>
```

## Roadmap

- [x] Fix error on exit
- [x] Switchable input method and group (currently hardcoded to 'rime')
- [x] Break into two windows for pre-edit and candidate list respectively
- [x] Select candidates with function
- [ ] If `'wrap'` is not set, scroll horizontal if pre-edit is too long, otherwise move to next line
- [ ] Show current input method and input group using dedicated window
- [x] Highlight
  - [x] Pre-edit highlight
- [x] UI glitch on first keystroke after insert
- [ ] Command-line support
- [ ] Horizontal/Vertical layout
- [ ] Candidate list margin
- [ ] Commit when focus out
- [ ] \(Perhaps\) `CursorMovedI/InsertCharPre` to `nvim_buf_attach()`
