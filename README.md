
Vem Tabline
===========

Vem Tabline is a lightweight Vim plugin to display your tabs and buffers at the
top of your screen using Vim's tabline.

![Screenshot](doc/screenshots/one-window.png)

Vem tabline shows your tabs as numbered workspaces at the right of the top line
of the screen and the list of open buffers to the left:

* In tabs with only one window all buffers are listed.

* In tabs with more than one window, only the buffers that are being displayed
  are listed.

This allows you to have a cleaner list of buffers depending on the tab that is
active and goes well with Vim's philosophy of using tabs as workspaces to
arrange windows in different configurations.

**Note**: Vem Tabline is one component of a larger Vim configuration project
named Vem, so the name is not a typo :) You can use Vem Tabline completely
independently from the parent project though. (Vem is still in the works but
will be released under the MIT license when all its parts are completed.)

Installation
------------

You can use Vem Tabline right away without additional configuration. Just
install the plugin and start using it. You only need to configure it if you
want to manually order the buffers in the tabline (explained below).

You need at least Vim 7 to use Vem Tabline.

Features
--------

There are many Vim plugins to display the list of buffers. I created Vem
Tabline because none of them had the features I needed:

* Use of Vim's native tabline (no horizontal splits).

* Support for displaying both buffers and tabs simultaneously.

* Support for Vim's native commands (no re-mappings necessary -there are
  available key mappings but they are optional).

* Possibility to reorder the buffers in the tabline.

* No fighting against Vim's native concepts (in particular no
  scoping buffers to certain tabs).

* Lightweight, performant and just focused on providing the tabline
  functionality.

The design of Vem Tabline is based on two very cool ones:
[vim-buftabline](https://github.com/ap/vim-buftabline) and
[WinTabs](https://github.com/zefei/vim-wintabs). It doesn't share code with
them but most ideas come from their original authors.

Moving Buffers in Tabline
-------------------------

Vem Tabline allows you to change the order in which buffers are shown in each
tab. To do so, use the following `<Plug>` mappings:

    Move selected buffer to the left:  <Plug>vem_tabline_move_buffer_left-
    Move selected buffer to the right: <Plug>vem_tabline_move_buffer_right-

Vim doesn't support ordering buffers natively so if you use `:bnext` and
`:bprev`, they will not follow the order of buffers in the tabline if you have
modified it. To avoid this problem you can use the following mappings:

    Select previous buffer in tabline: <Plug>vem_tabline_prev_buffer-
    Select next buffer in tabline:     <Plug>vem_tabline_next_buffer-

For example you could set your mappings like:
```
nmap <leader>h <Plug>vem_tabline_move_buffer_left-
nmap <leader>l <Plug>vem_tabline_move_buffer_right-
nmap <leader>p <Plug>vem_tabline_prev_buffer-
nmap <leader>n <Plug>vem_tabline_next_buffer-
```

You may also want to map the numbered keys to quickly access your tabs. To do
so, use the following key mappings:
```
nnoremap 1 :1tabnext<CR>
nnoremap 2 :2tabnext<CR>
nnoremap 3 :3tabnext<CR>
nnoremap 4 :4tabnext<CR>
nnoremap 5 :5tabnext<CR>
nnoremap 6 :6tabnext<CR>
nnoremap 7 :7tabnext<CR>
nnoremap 8 :8tabnext<CR>
nnoremap 9 :9tabnext<CR>
```

Color Scheme
------------

Vem Tabline uses the default colors of your color scheme for rendering the
tabline. However you may change them using the following highlighting groups:

Highlighting Group    | Default     | Meaning
----------------------|-------------|------------------------------
VemTablineSelected    | TabLineSel  | Selected buffer
VemTablineNormal      | TabLine     | Non selected buffer
VemTablineLocation    | TabLine     | Directory name (when present)
VemTablineSeparator   | TabLineFill | +X more text
VemTablineTabSelected | TabLineSel  | Selected tab
VemTablineTabNormal   | TabLineFill | Non selected tab

