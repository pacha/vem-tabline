" Vem Tabline. Plugin to display buffers and tabs in the tabline.
" Part of vem project
" Maintainer: Andrés Sopeña <asopena@ehmm.org>
" Licence: The MIT License (MIT)

" Sentinel to prevent double execution
if exists('g:loaded_vem_tabline')
    finish
endif
let g:loaded_vem_tabline = 1

" Sentinel to guarantee a modern version of Vim
if v:version < 700
    echoerr 'Vim 7 is required for vem-tabline (this is %d.%d)'
    finish
endif

scriptencoding utf-8

" Configuration variables
let g:vem_tabline_show = get(g:, 'vem_tabline_show', 1)
let g:vem_tabline_multiwindow_mode = get(g:, 'vem_tabline_multiwindow_mode', 1)
let g:vem_tabline_location_symbol = get(g:, 'vem_tabline_location_symbol', '@')
if has('gui_running')
    let g:vem_tabline_left_arrow = get(g:, 'vem_tabline_left_arrow', '◀')
    let g:vem_tabline_right_arrow = get(g:, 'vem_tabline_right_arrow', '▶')
else
    let g:vem_tabline_left_arrow = get(g:, 'vem_tabline_left_arrow', '<')
    let g:vem_tabline_right_arrow = get(g:, 'vem_tabline_right_arrow', '>')
endif

" Syntax highlighting
highlight default link VemTablineNormal TabLine
highlight default link VemTablineSelected TabLineSel
highlight default link VemTablineShown TabLine
highlight default link VemTablineLocation TabLine
highlight default link VemTablineSeparator TabLineFill
highlight default link VemTablineTabNormal TabLineFill
highlight default link VemTablineTabSelected TabLineSel

" Functions

call vem_tabline#Init()

" Only call tabline.refresh() if the modified status of the buffer changes
" This function is needed to optimize performance
" TextChanged and TextChangedI are called too frequently to redraw every time
function! s:check_buffer_changes()
    let bufnum = bufnr('%')
    let old_modified_flag = getbufvar(bufnum, "vem_tabline_mod_opt")
    if old_modified_flag != &modified
        call g:vem_tabline#tabline.refresh()
        call setbufvar(bufnum, 'vem_tabline_mod_opt', &modified)
    endif
endfunction

" Mappings

" select previous buffer
nmap <silent> <Plug>vem_prev_buffer- :call vem_tabline#tabline.select_buffer('left')<CR>

" select next buffer
nmap <silent> <Plug>vem_next_buffer- :call vem_tabline#tabline.select_buffer('right')<CR>

" move buffer to the left
nmap <silent> <Plug>vem_move_buffer_left- :call vem_tabline#tabline.move_buffer('left')<CR>

" move buffer to the right
nmap <silent> <Plug>vem_move_buffer_right- :call vem_tabline#tabline.move_buffer('right')<CR>

" Autocommands
augroup VemTabLine
    autocmd!
    autocmd VimEnter,TabNew,TabClosed,TabEnter,WinEnter * call vem_tabline#tabline.refresh()
    autocmd BufAdd,BufEnter,BufFilePost * call vem_tabline#tabline.refresh()
    autocmd BufDelete * call vem_tabline#tabline.refresh(str2nr(expand('<abuf>')))
    autocmd TextChanged,TextChangedI,BufWritePost * call s:check_buffer_changes()
    autocmd FileType qf call vem_tabline#tabline.refresh()
augroup END

" Options
set guioptions-=e
set tabline=%!vem_tabline#tabline.render()

