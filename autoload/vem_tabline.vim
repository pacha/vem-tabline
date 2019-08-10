" Data and functions to control the tabline
"
" Most important elements:
"
" vem_tabline#tabline
" dictionary with all the information associated to the tabline
"
" vem_tabline#tabline.refresh()
" update tabline internal status according to the status of vim tabs, windows and buffers
"
" vem_tabline#tabline.render()
" draw the tabline
"

" Due to a bug in Vim dictionary functions don't trigger script autoload
" This is just a workaround to load the files
function! vem_tabline#Init() abort
    call g:vem_tabline#buffers#Init()
    call g:vem_tabline#separator#Init()
    call g:vem_tabline#tabpages#Init()
endfunction

" all the information about the tabline is stored here
" call the 'render' function to obtain the final string
let vem_tabline#tabline = {}
let vem_tabline#tabline.is_multiwindow = 0
let vem_tabline#tabline.tabline_buffers = []
let vem_tabline#tabline.extra_buffer_count = 0
let vem_tabline#tabline.cached_tabline = ''

" return only buffers that aren't unlisted or quickfix ones
function! s:get_buffer_list(...) abort
    " get params
    let deleted_buffer_nr = get(a:, 1, 0)

    " get condition
    let only_listed = 'buflisted(v:val) && "quickfix" !=? getbufvar(v:val, "&buftype")'
    let not_just_deleted = 'v:val != ' . deleted_buffer_nr
    let condition = only_listed . ' && ' . not_just_deleted

    " filter buffer list
    return filter(range(1, bufnr('$')), condition)
endfunction

" keep the sort in which buffers are displayed stored in tab and use it to
" sort buffers every time
function! s:sort_buffers_in_tabpage(buffer_nrs) abort
    " create variable in tabpage
    if !exists('t:vem_tabline_buffers')
        let t:vem_tabline_buffers = []
    endif

    " keep buffers that are still valid and skip deleted ones
    let still_valid = filter(t:vem_tabline_buffers, 'index(a:buffer_nrs, v:val)!=-1')

    " add new buffers
    let new_buffers = filter(a:buffer_nrs, 'index(t:vem_tabline_buffers, v:val)==-1')

    let t:vem_tabline_buffers = still_valid + new_buffers
    return t:vem_tabline_buffers
endfunction

" update state of tabline according to current buffers/windows/tabpages
function! vem_tabline#tabline.update(...) abort

    let deleted_buffer_nr = get(a:, 1, 0)

    " listed buffers
    let listed_buffers = s:get_buffer_list(deleted_buffer_nr)

    " buffers in current tabpage
    let buffers_in_tab = tabpagebuflist()
    let only_listed = 'buflisted(v:val) && "quickfix" !=? getbufvar(v:val, "&buftype")'
    let unique = 'index(buffers_in_tab, v:val, v:key+1)==-1'
    let self.tabpage_buffers = filter(buffers_in_tab, only_listed . ' && ' . unique)

    " windows in tabpage
    let condition = 'index(self.tabpage_buffers, winbufnr(v:val)) != -1'
    let self.total_window_num = winnr('$')
    let self.tabpage_windows = filter(range(1, self.total_window_num), condition)

    " check if multiwindow mode
    let self.is_multiwindow = len(self.tabpage_windows) > 1
    let self.multiwindow_mode = self.is_multiwindow && g:vem_tabline_multiwindow_mode

    " list of buffers to display and extra buffers (non-displayed ones)
    if self.multiwindow_mode
        let self.tabline_buffers = self.tabpage_buffers
        let self.extra_buffer_count = len(listed_buffers) - len(self.tabpage_buffers)
    else
        let self.tabline_buffers = s:sort_buffers_in_tabpage(listed_buffers)
        let self.extra_buffer_count = 0
    endif

    let self.cached_tabline = self.get_tabline()

endfunction

" Some changes in the window layout (eg. <C-w>o) don't trigger autocommand events.
" This should be called when you need to ensure that the window layout haven't changed.
function! vem_tabline#tabline.update_if_needed() abort
    if self.total_window_num != winnr('$')
        call self.update()
    endif
endfunction

" Create tabline string
function! vem_tabline#tabline.get_tabline() abort

    " tabpages
    call g:vem_tabline#tabpages#section.update()
    let tabpage_length = g:vem_tabline#tabpages#section.get_length()
    let tabpage_section = g:vem_tabline#tabpages#section.render()

    " separator
    call g:vem_tabline#separator#section.update(self.extra_buffer_count)
    let separator_length = g:vem_tabline#separator#section.get_length()
    let separator_section = g:vem_tabline#separator#section.render()

    " buffers
    let screen_length = &columns
    let available_length = max([screen_length - tabpage_length - separator_length, 0])
    call g:vem_tabline#buffers#section.update(self.tabline_buffers)
    let buffer_section = g:vem_tabline#buffers#section.render(available_length)

    " join result
    return buffer_section . separator_section . tabpage_section

endfunction

" Return cached tabline
function! vem_tabline#tabline.render() abort
    return self.cached_tabline
endfunction

" Get the buffer to be used if current one were to be deleted.
" The buffer is selected according to the order of buffers in the tabline
" (usually the one to the right, unless it is the last one, then the one to
" the left is returned).
" If current buffer is not in the list return 0
function! vem_tabline#tabline.get_replacement_buffer() abort
    " get buffer position
    let bufnum = bufnr('%')
    let bufnum_pos = index(self.tabline_buffers, bufnum)
    echomsg bufnum_pos

    " check if current buffer is not in the tabline
    if bufnum_pos == -1
        return 0
    endif

    " get replacement buffer position
    let next_pos = bufnum_pos + 1 < len(self.tabline_buffers) ? bufnum_pos + 1 : bufnum_pos - 1

    " get replacement buffer number
    let next_buf = self.tabline_buffers[next_pos]
    return next_buf
endfunction

" Get next/prev buffer in list (according to the stored sorting)
" 'direction' is 'left' or 'right' and the return value is the buffer number
" if current buffer is not in the list return 0
function! vem_tabline#tabline.get_next_buffer(direction) abort
    " get buffer position
    let bufnum = bufnr('%')
    let bufnum_pos = index(self.tabline_buffers, bufnum)

    " check if current buffer is not in the tabline
    if bufnum_pos == -1
        return 0
    endif

    " get next/prev buffer position
    let inc = a:direction == 'right' ? 1 : -1
    let next_pos = (bufnum_pos + inc) % len(self.tabline_buffers)

    " get buffer number
    let next_buf = self.tabline_buffers[next_pos]
    return next_buf
endfunction

" Get next/prev window in tab that contains a buffer of the tabline
" 'direction' is 'left' or 'right' and the return value is the window number
" if current window doesn't contain a tabline buffer return 0
function! vem_tabline#tabline.get_next_window(direction) abort
    " get window position
    let winnum = winnr()
    let winnum_pos = index(self.tabpage_windows, winnum)

    " check if current window is not in tabline
    if winnum_pos == -1
        return 0
    endif

    " get next tabline buffer window
    let inc = a:direction == 'right' ? 1 : -1
    let next_pos = (winnum_pos + inc) % len(self.tabpage_windows)

    " get buffer number
    let next_winnum = self.tabpage_windows[next_pos]
    return next_winnum
endfunction

" Select next/prev buffer in tabline
" If the current buffer is in the tabline, it selects the prev or next one
" Otherwise, it selects one of the buffers in the tabline
function! vem_tabline#tabline.select_buffer(direction) abort

    " if multiwindow: go to new window
    " if single window: show new buffer in same window
    call self.update_if_needed()
    if self.multiwindow_mode
        call self.select_next_window(a:direction)
    else
        call self.select_next_buffer(a:direction)
    endif
endfunction

" Select buffer in multi-window mode
function! vem_tabline#tabline.select_next_window(direction) abort
    " get the number of the buffer to select
    let next_winnum = self.get_next_window(a:direction)
    if next_winnum == 0
        if len(self.tabpage_windows) > 0
            let next_winnum = self.tabpage_windows[0]
        else
            return
        endif
    endif
    exec next_winnum . 'wincmd w'
endfunction

" Select buffer in single-window mode
function! vem_tabline#tabline.select_next_buffer(direction) abort
    let next_bufnum = self.get_next_buffer(a:direction)
    if next_bufnum == 0
        if winnr('$') > 1
            if len(self.tabpage_windows) > 0
                let next_winnum = self.tabpage_windows[0]
                exec next_winnum . 'wincmd w'
            endif
            return
        else
            if len(self.tabline_buffers) > 0
                let next_bufnum = self.tabline_buffers[0]
            endif
        endif
    endif
    exec next_bufnum . 'buffer'
endfunction

" Move current buffer to left/right in the tabline
function! vem_tabline#tabline.move_buffer(direction) abort

    " check that the buffer is in tabline
    let bufnum = bufnr('%')
    let bufnum_pos = index(self.tabline_buffers, bufnum)
    if bufnum_pos == -1
        return
    endif

    " if multiwindow: rotate, if single window: swap
    call self.update_if_needed()
    if self.multiwindow_mode
        call self.swap_window_position(a:direction)
    else
        call self.swap_buffer_position(a:direction)
    endif
endfunction

function! vem_tabline#tabline.swap_window_position(direction) abort

    " get the number of the buffer to swap possition with
    let next_winnum = self.get_next_window(a:direction)
    if next_winnum == 0
        return
    endif

    " swap contents
    exec next_winnum . 'wincmd x'

    " move to next window
    exec next_winnum . 'wincmd w'
endfunction

" Move current buffer to left/right in the tabline
function! vem_tabline#tabline.swap_buffer_position(direction) abort

    " get buffer position
    let sorted_buffers = t:vem_tabline_buffers
    let bufnum = bufnr('%')
    let bufnum_pos = index(sorted_buffers, bufnum)
    let buf_count = len(sorted_buffers)

    " if the buffer isn't present yet in the list, do nothing
    if bufnum_pos == -1
        return
    endif

    " get left sublist
    let to_left = a:direction == 'left'
    let boundary_left = to_left ? bufnum_pos - 2 : bufnum_pos - 1
    let left_side = boundary_left < 0 ? [] : sorted_buffers[:boundary_left]

    " get left side of the swap movement
    if to_left
        let left_swap = [bufnum]
    else
        let left_swap = bufnum_pos >= buf_count - 1 ? [] : sorted_buffers[bufnum_pos + 1:bufnum_pos + 1]
    endif

    " get right side of the swap movement
    if to_left
        let right_swap = bufnum_pos < 1 ? [] : sorted_buffers[bufnum_pos - 1:bufnum_pos - 1]
    else
        let right_swap = [bufnum]
    endif

    " get right sublist
    let boundary_right = to_left ? bufnum_pos + 1 : bufnum_pos + 2
    let right_side = boundary_right >= buf_count ? [] : sorted_buffers[boundary_right:]

    " assemble buffer list back
    if bufnum_pos == 0 && to_left
        let t:vem_tabline_buffers = right_side + left_swap
    elseif bufnum_pos == buf_count - 1 && !to_left
        let t:vem_tabline_buffers = right_swap + left_side
    else
        let t:vem_tabline_buffers = left_side + left_swap + right_swap + right_side
    endif

    " redraw buftabline
    call self.refresh()
endfunction

" Determine if it is necessary to show the tabline
function! vem_tabline#tabline.refresh(...) abort
    let deleted_buffer_nr = get(a:, 1, 0)
    call self.update(deleted_buffer_nr)

    if g:vem_tabline_show == 0
        set showtabline=0
    elseif g:vem_tabline_show == 1
        if tabpagenr('$') > 1 || len(self.tabline_buffers) > 1 || self.extra_buffer_count > 0
            set showtabline=2
        else
            set showtabline=0
        endif
    else
        set showtabline=2
    endif
endfunction

