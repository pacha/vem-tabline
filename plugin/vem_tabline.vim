" Vem Tabline. Plugin to display buffers and tabs in the tabline.
" Part of vem project
" Maintainer: Andrés Sopeña <asopena@ehmm.org>
" Licence: The MIT License (MIT)

" Sentinel to prevent double execution and ensure a modern version of Vim
if exists('g:loaded_vem_tabline') || v:version < 700
    finish
endif
let g:loaded_vem_tabline = 1

scriptencoding utf-8

" Configuration variables
let g:vem_tabline_show = get(g:, 'vem_tabline_show', 1)
let g:vem_tabline_show_number = get(g:, 'vem_tabline_show_number', 'none')
let g:vem_tabline_number_symbol = get(g:, 'vem_tabline_location_symbol', ':')
let g:vem_tabline_multiwindow_mode = get(g:, 'vem_tabline_multiwindow_mode', 0)
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
highlight default link VemTablineLocation TabLine
highlight default link VemTablineNumber TabLine
highlight default link VemTablineSelected TabLineSel
highlight default link VemTablineLocationSelected TabLineSel
highlight default link VemTablineNumberSelected TabLineSel
highlight default link VemTablineShown TabLine
highlight default link VemTablineLocationShown TabLine
highlight default link VemTablineNumberShown TabLine
highlight default link VemTablinePartialName Tabline
highlight default link VemTablineSeparator TabLineFill
highlight default link VemTablineTabNormal TabLineFill
highlight default link VemTablineTabSelected TabLineSel
highlight default link VemTabline VemTablineNormal

" Functions

call vem_tabline#Init()

" Only call tabline.refresh() if the modified status of the buffer changes
" This function is needed to optimize performance
" TextChanged and TextChangedI are called too frequently to redraw every time
function! s:check_buffer_changes() abort
    let bufnum = bufnr('%')
    let old_modified_flag = getbufvar(bufnum, "vem_tabline_mod_opt")
    if old_modified_flag != &modified
        call g:vem_tabline#tabline.refresh()
        call setbufvar(bufnum, 'vem_tabline_mod_opt', &modified)
    endif
endfunction

" User function to switch buffers
function! VemTablineGo(tagnr) abort
    try
        let buffnr = g:vem_tabline#buffers#section.tagnr_map[a:tagnr . g:vem_tabline_number_symbol]
        exec 'buffer' . buffnr
    catch /E716:/
        exec 'buffer ' . a:tagnr
    catch //
        echoerr "VemTabline: Buffer " . a:tagnr . " does not exist"
    endtry
endfunction

" Commands

command! -nargs=1 VemTablineGo call VemTablineGo("<args>")

" Mappings

" select previous buffer
map <silent> <Plug>vem_prev_buffer- :<C-u>call vem_tabline#tabline.select_buffer('left')<CR>

" select next buffer
map <silent> <Plug>vem_next_buffer- :<C-u>call vem_tabline#tabline.select_buffer('right')<CR>

" move buffer to the left
map <silent> <Plug>vem_move_buffer_left- :<C-u>call vem_tabline#tabline.move_buffer('left')<CR>

" move buffer to the right
map <silent> <Plug>vem_move_buffer_right- :<C-u>call vem_tabline#tabline.move_buffer('right')<CR>

" Autocommands
augroup VemTabLine
    autocmd!
    autocmd VimEnter,TabEnter,WinEnter * call vem_tabline#tabline.refresh()
    autocmd BufAdd,BufEnter,BufFilePost * call vem_tabline#tabline.refresh()
    autocmd VimResized,CursorHold * call vem_tabline#tabline.refresh()
    autocmd BufDelete * call vem_tabline#tabline.refresh(str2nr(expand('<abuf>')))
    autocmd TextChanged,TextChangedI,BufWritePost * call s:check_buffer_changes()
    autocmd FileType qf call vem_tabline#tabline.refresh()
augroup END

" Options
set guioptions-=e
set tabline=%!vem_tabline#tabline.render()

