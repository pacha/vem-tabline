" Vem Tabline: buffers

" Use:
"
" Calling code first updates the list and then renders:
"
"   vem_tabline#buffers#section.update(buffernr_list)
"   vem_tabline#buffers#section.render(available_space_in_chars)
"
" Definitions:
"
" label = tagnr + buffer_name + discriminator + flags
"

" Due to a bug in Vim dictionary functions don't trigger script autoload
" This is just a workaround to load the files
function! vem_tabline#buffers#Init() abort
    return 1
endfunction

let vem_tabline#buffers#section = {}

" buffer_items is a list of dicts, each having info about one of the buffers
let vem_tabline#buffers#section.buffer_items = []

" the anchor is the index of the buffer to start rendering the tabline from
" the anchor direction: which side from the anchor draw the buffers
let vem_tabline#buffers#section.anchor = 0
let vem_tabline#buffers#section.anchor_direction = 'right'
let vem_tabline#buffers#section.current_buffer_index = 0

" viewport parameters
let vem_tabline#buffers#section.start_index = 0
let vem_tabline#buffers#section.end_index = 0
let vem_tabline#buffers#section.left_arrow = 0
let vem_tabline#buffers#section.right_arrow = 0
let vem_tabline#buffers#section.left_padding = ''
let vem_tabline#buffers#section.right_padding = ''

" the tagnr is the number shown in front of the buffer (if enabled)
" the tagnr_map is a dict that maps that number to the actual buffer number
let vem_tabline#buffers#section.tagnr_map = {}

"
" Update
"
function! vem_tabline#buffers#section.update(buffer_nrs) abort
    call self.populate_buffers(a:buffer_nrs)
    call self.generate_labels_without_tagnr()
endfunction

function! vem_tabline#buffers#section.populate_buffers(buffer_nrs) abort

    " data about the buffers to show in the tabline
    let self.buffer_items = []

    " do nothing if there are no buffer numbers
    if len(a:buffer_nrs) == 0
        return
    endif

    " gather info for each buffer
    for buffer_nr in a:buffer_nrs

        let buffer_item = copy(g:vem_tabline#buffers#buffer_item)

        " buffer number
        let buffer_item.nr = buffer_nr

        " elements of the file path in reversed order ([] for new buffers)
        " eg. ['tabline.vim', 'vem', 'autoload', 'runtime', 'vem', 'code', 'pacha', 'home']
        let buffer_item.path_parts = reverse(split(expand('#' . buffer_nr . ':p'), '[\//]'))

        " index of the last element in path_part to be included in the label
        let buffer_item.path_index = 0

        " label parts: <tagnr><name><discriminator><flags>
        let buffer_item.tagnr = ''
        let buffer_item.name = ''
        let buffer_item.discriminator = ''
        let buffer_item.flags = ''

        " buffer that is being editted
        let buffer_item.current = buffer_nr == bufnr('%')

        " buffer has modifications that haven't been saved
        let buffer_item.modified = getbufvar(buffer_nr, '&modified')

        " buffer is shown in a window of the current tabpage
        let buffer_item.shown = bufwinnr(buffer_nr) != -1

        " last buffer in tabline (computed later)
        let buffer_item.last_position = 0

        call add(self.buffer_items, buffer_item)
    endfor

    " update last position
    let self.buffer_items[-1].last_position = 1

endfunction

function! vem_tabline#buffers#section.generate_labels_without_tagnr() abort

    " iterate through buffers
    let buffer_items_count = len(self.buffer_items)
    for buffer_index in range(buffer_items_count)
        let buffer_item = self.buffer_items[buffer_index + 0]
        let path_parts_count = len(buffer_item.path_parts)

        " empty name
        if path_parts_count == 0
            let buffer_item.name = '[No Name]'
            continue
        endif

        " set label index by comparing this buffer with next ones until a
        " unique label is generated
        if buffer_index != buffer_items_count - 1
            for next_item in self.buffer_items[buffer_index + 1:]
                let index = s:find_first_non_match(buffer_item.path_parts, next_item.path_parts)
                let buffer_item.path_index = max([buffer_item.path_index, index])
                let next_item.path_index = max([next_item.path_index, index])
            endfor
        endif

        " get name
        let buffer_item.name = buffer_item.path_parts[0]

        " get discriminator
        if buffer_item.path_index != 0
            let filename = buffer_item.path_parts[0]
            let dirname = buffer_item.path_parts[buffer_item.path_index]
            let buffer_item.discriminator = g:vem_tabline_location_symbol . dirname
        endif

        " get flags
        if buffer_item.modified
            let buffer_item.flags = '*'
        endif

        " update current buffer index
        if buffer_item.current
            let self.current_buffer_index = buffer_index
        endif
    endfor

endfunction

"
" Render the list of buffers
"
function! vem_tabline#buffers#section.render(max_length) abort

    " do nothing if there are no buffers
    if len(self.buffer_items) == 0
        return ''
    endif

    " set viewport params
    call self.set_viewport_params(a:max_length)
    if self.current_buffer_index < self.start_index
        let self.anchor = self.current_buffer_index
        let self.anchor_direction = 'right'
        call self.set_viewport_params(a:max_length)
    elseif self.current_buffer_index > self.end_index
        let self.anchor = self.current_buffer_index
        let self.anchor_direction = 'left'
        call self.set_viewport_params(a:max_length)
    endif

    " set tagnr for labels
    if g:vem_tabline_show_number != 'none'
        call self.set_tagnrs()
    endif

    return self.get_tabline()

endfunction

function! vem_tabline#buffers#section.set_viewport_params(max_length) abort

    " check that the anchor is still valid
    let last_index = len(self.buffer_items) - 1
    if self.anchor > last_index
        let self.anchor = last_index
        let self.anchor_direction = 'left'
    endif

    " get range of indexes to iterate through
    if self.anchor_direction == 'right'
        let buffer_range = range(self.anchor, last_index)
        let first_arrow = self.anchor > 0
    else
        let buffer_range = reverse(range(0, self.anchor))
        let first_arrow = self.anchor < last_index
    endif

    " check how many buffers fit
    let anti_anchor = self.anchor
    let current_length = first_arrow ? 2 : 1  " account for the first arrow and right label margin
    let index = 0
    for buffer_index in buffer_range
        let buffer_item = self.buffer_items[buffer_index]
        let last_one = buffer_index == buffer_range[-1]

        " get tagnr
        let index += 1
        let tagnr = buffer_item.get_tagnr(index)

        " get label length + left label margin
        let label_length = buffer_item.get_length(tagnr) + 1

        " update current length and advance pointer to buffer
        let remaining = a:max_length - current_length
        if (!last_one && label_length < remaining) || (last_one && label_length <= remaining)
            let current_length += label_length
            let anti_anchor = buffer_index
        else
            break
        endif
    endfor

    " get final numbers
    if self.anchor_direction == 'right'
        let self.start_index = self.anchor
        let self.end_index = anti_anchor
        let self.left_arrow = first_arrow
        let self.right_arrow = anti_anchor < last_index
        let current_length += self.right_arrow ? 1 : 0
        let self.left_padding = 0
        let self.right_padding = a:max_length - current_length
    else
        let self.start_index = anti_anchor
        let self.end_index = self.anchor
        let self.left_arrow = anti_anchor > 0
        let self.right_arrow = first_arrow
        let current_length += self.left_arrow ? 1 : 0
        let self.left_padding = a:max_length - current_length
        let self.right_padding = 0
    endif

endfunction

function! vem_tabline#buffers#section.set_tagnrs() abort

    let self.tagnr_map = {}
    let buffer_range = range(self.start_index, self.end_index)
    let index = 0
    for buffer_index in buffer_range
        let buffer_item = self.buffer_items[buffer_index]
        let index += 1
        call buffer_item.set_tagnr(index)
        let self.tagnr_map[buffer_item.tagnr] = buffer_item.nr
    endfor

    " set tagnr for partial name
    if self.end_index < len(self.buffer_items) - 1
        let index += 1
        call self.buffer_items[self.end_index + 1].set_tagnr(index)
        let self.tagnr_map[buffer_item.tagnr] = buffer_item.nr
    endif

endfunction

function! vem_tabline#buffers#section.get_tabline() abort

    let section = '%#VemTablineNormal#'

    " left arrow
    if self.left_arrow
        let section .= g:vem_tabline_left_arrow

        " left padding
        if self.left_padding
            let section .= '%#VemTablinePartialName#' . self.get_left_padding() . '%#VemTablineNormal#'
        endif
    endif

    " buffers
    let buffer_range = range(self.start_index, self.end_index)
    for buffer_index in buffer_range
        let buffer_item = self.buffer_items[buffer_index]
        let last_one = buffer_index == buffer_range[-1]

        " label
        if buffer_item.current
            let section .= '%#VemTablineSelected# '
            let section .= buffer_item.render('Selected')
        elseif buffer_item.shown
            let section .= ' %#VemTablineShown#'
            let section .= buffer_item.render('Shown')
        else
            let section .= ' %#VemTablineNormal#'
            let section .= buffer_item.render('')
        endif

        " last right label margin
        if last_one
            let section .= ' %#VemTablineNormal#'
        endif
    endfor

    " right arrow
    if self.right_arrow
        " right padding
        if self.right_padding
            let section .= '%#VemTablinePartialName#' . self.get_right_padding() . '%#VemTablineNormal#'
        endif

        let section .= g:vem_tabline_right_arrow
    endif

    return section

endfunction

function! vem_tabline#buffers#section.get_left_padding() abort
    try
        let item = self.buffer_items[self.start_index - 1]
        let label = item.get_label()
        let padding = label[-self.left_padding:]
        let padding = repeat('.', self.left_padding - len(padding)) . padding
        return padding
    catch //
        return repeat('.', self.left_padding)
    endtry
endfunction

function! vem_tabline#buffers#section.get_right_padding() abort
    try
        let item = self.buffer_items[self.end_index + 1]
        let label = item.get_label()
        let padding = label[0:self.right_padding - 1]
        return padding
    catch //
        return repeat('.', self.right_padding)
    endtry
endfunction

" Compare two lists and return the index of the fist element that is different
" between them. If they are the same, the last index is returned.
"
" [], [] -> -1
" [], [a, b, d] -> 0
" [a, b], [c, d] -> 0
" [a, b, c], [a, f, c] -> 1
" [a, b, c], [a, b, d] -> 2
" [a, b, c], [a, b, c] -> 2
" [a, b, c], [a, b, c, e, f] -> 2
" [a, b, c, e, f], [a, b, c] -> 2
function! s:find_first_non_match(list_a, list_b) abort

    let len_list_a = len(a:list_a)
    let len_list_b = len(a:list_b)

    if len_list_a == 0 && len_list_b == 0
        " two empty lists: return -1
        return -1
    elseif len_list_a == 0 || len_list_b == 0
        " one of the lists is empty: first element of the other one
        return 0
    endif

    let min_len = min([len_list_a, len_list_b])
    for index in range(min_len)
        if a:list_a[index] != a:list_b[index]
            return index
        endif
    endfor
    return index

endfunction

"
" Buffer Item
"

let vem_tabline#buffers#buffer_item = {}

" get the length of a single buffer label
function! vem_tabline#buffers#buffer_item.get_length(tagnr) abort
    let margin = 2
    return len(a:tagnr) + len(self.name) + len(self.discriminator) + len(self.flags) + margin
endfunction

function! vem_tabline#buffers#buffer_item.get_label() abort
    return ' ' . self.tagnr . self.name . self.discriminator . self.flags . ' '
endfunction

function! vem_tabline#buffers#buffer_item.get_tagnr(index) abort
    if g:vem_tabline_show_number == 'none'
        return ''
    elseif g:vem_tabline_show_number == 'index'
        return a:index . g:vem_tabline_number_symbol
    elseif g:vem_tabline_show_number == 'buffnr'
        return self.nr . g:vem_tabline_number_symbol
    else
        let msg = "VemTabline: invalid value for g:vem_tabline_show_number"
        let msg .= " ('" . g:vem_tabline_show_number . "')"
        throw msg
    endif
endfunction

function! vem_tabline#buffers#buffer_item.set_tagnr(index) abort
    let self.tagnr = self.get_tagnr(a:index)
endfunction

function! vem_tabline#buffers#goto_buffer(minwid, clicks, btn, modifiers) abort
    execute 'buffer ' . a:minwid
endfunction

function! vem_tabline#buffers#buffer_item.render(modifier) abort
    let label = ' '
    if self.tagnr != ''
        let label .= '%#VemTablineNumber' . a:modifier . '#'
        let label .= self.tagnr
        let label .= '%#VemTabline' . a:modifier . '#'
    endif
    let label .= self.name
    if self.discriminator != ''
        let label .= '%#VemTablineLocation' . a:modifier . '#'
        let label .= self.discriminator
        let label .= '%#VemTabline' . a:modifier . '#'
    endif
    let label .= self.flags
    let label .= ' '

    " Enable mouse clicking (only neovim for now)
    if has('tablineat')
        let label = '%' . self.nr . '@vem_tabline#buffers#goto_buffer@' . label . '%X'
    endif

    return label
endfunction
