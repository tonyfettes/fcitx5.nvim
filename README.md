# fcitx5.nvim

[WIP] fcitx5 client in neovim

## Install

packer.nvim

```lua
use {
  'tonyfettes/fcitx5.nvim'
  rocks = {'dbus_proxy', 'lgi'}
}
```

## Demo

<video src="https://user-images.githubusercontent.com/29998228/143666070-f5daf6e1-9f2f-4fa2-af92-6ee5b582df62.mp4" width="100%"></video>

## Roadmap

- [x] Fix error on exit
- [x] Switchable input method and group (currently hardcoded to 'rime')
- [x] Break into two windows for pre-edit and candidate list respectively
- [ ] Select candidates with function
- [ ] If `'wrap'` is not set, scroll horizontal if pre-edit is too long, otherwise move to next line
- [ ] Show current input method and input group
- [x] Highlight
- [x] UI glitch on first keystroke after insert
- [ ] Command-line support
- [ ] Horizontal/Vertical layout
- [ ] Candidate list margin
- [ ] Commit when focus out
- [ ] \(Perhaps\) `CursorMovedI/InsertCharPre` to `nvim_buf_attach()`
