" Vem Tabline: buffers

" Due to a bug in Vim dictionary functions don't trigger script autoload
" This is just a workaround to load the files
function! vem_tabline#buffers#Init()
    return 1
endfunction

let vem_tabline#buffers#section = {}

" buffer_items is a list of dicts, each having info about one of the buffers
let vem_tabline#buffers#section.buffer_items = []

" the anchor is the index of the buffer to start rendering the tabline from
" the anchor direction: which side from the anchor draw the buffers
let vem_tabline#buffers#section.anchor = 0
let vem_tabline#buffers#section.anchor_direction = 'right'

let vem_tabline#buffers#buffer_item = {}

" get the length of a single buffer label
function! vem_tabline#buffers#buffer_item.get_length()
    let margin_length = 2
    return len(self.name) + len(self.discriminator) + len(self.flags) + margin_length
endfunction

" render a single buffer label
function! vem_tabline#buffers#buffer_item.render(...)
    " parameters
    let discriminator_hl = get(a:, 1, '')
    let end_discriminator_hl = get(a:, 2, '')
    let max_length = get(a:, 3, 0)
    let crop_direction = get(a:, 4, 'none')

    " discriminator
    if self.discriminator != '' && crop_direction == 'none'
        let discriminator = discriminator_hl . self.discriminator . end_discriminator_hl
    else
        let discriminator = self.discriminator
    endif

    " build label
    let label = ' ' . self.name . discriminator . self.flags . ' '

    " crop label
    if crop_direction == 'left'
        let label = label[-max_length:]
    elseif crop_direction == 'right'
        let label = label[:max_length - 1]
    endif

    return label
endfunction

function! vem_tabline#buffers#section.update(buffer_nrs)

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

        " label parts: <name><discriminator><flags>
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

    " update buffer labels
    call s:generate_labels(self.buffer_items)

endfunction

" Calculate the length in characters of the section
function! vem_tabline#buffers#section.get_length()

    " length is 0 if there are no buffers
    if len(self.buffer_items) == 0
        return 0
    endif

    " length of section is the sum of the length of buffer labels
    let section_length = 0
    for buffer_item in self.buffer_items
        let section_length += buffer_item.get_length()
    endfor

    " one extra char between buffers (and at beginning and end)
    let margin_length = len(self.buffer_items) + 1

    return section_length + margin_length
endfunction

" Return the index range of buffers that fit in tabline
" together with how many chars of that last one fit (overflow)
" The result has the form: [start_index, end_index, overflow]
" An overflow of 0 means that the last buffer fits entirely
function! s:get_viewport_range(label_lengths, max_length, from_index, direction)

    " set traversal direction
    if a:direction == 'right'
        let inc = 1
        let last_index = len(a:label_lengths) - 1
    elseif a:direction == 'left'
        let inc = -1
        let last_index = 0
    endif

    " get the end of the range and the overflow
    let total_length = 0
    let overflow = 0
    for index in range(a:from_index, last_index, inc)
        let length = a:label_lengths[index]
        if total_length + length >= a:max_length
            let overflow = a:max_length - total_length
            break
        endif
        let total_length += length
    endfor

    if a:direction == 'right'
        let start_index = a:from_index
        let end_index = index
    else
        let start_index = index
        let end_index = a:from_index
    endif
    return [start_index, end_index, overflow]
endfunction

function! s:get_viewport_info(buffer_items, max_length, anchor, anchor_direction)

    " get label sizes, total size and index of selected (current) buffer
    let label_lengths = []
    let current_index = 0
    let last_index = len(a:buffer_items) - 1

    " total_length = label sizes + 1 space per label + 1 space at the end
    " <space><label><space><label><space><label><space><label><space>
    let total_length = 1
    for index in range(0, last_index)

        let buffer_item = a:buffer_items[index]

        " sum the length of the buffer label + 1 space margin at left
        call add(label_lengths, buffer_item.get_length() + 1)
        let total_length += buffer_item.get_length() + 1

        " save current index
        if buffer_item.current
            let current_index = index
        endif
    endfor

    " if all buffers fit in the space, stop here
    if total_length <= a:max_length
        let viewport_info = {}
        let viewport_info.start_index = 0
        let viewport_info.end_index = last_index
        let viewport_info.left_arrow = 0
        let viewport_info.right_arrow = 0
        let viewport_info.left_overflow = 0
        let viewport_info.right_overflow = 0
        let viewport_info.anchor = 0
        let viewport_info.anchor_direction = 'right'
        return viewport_info
    endif

    " check that the anchor is still valid
    let anchor = a:anchor <= last_index ? a:anchor : current_index

    " get tentative range
    let direction = a:anchor_direction
    if anchor == 0 || anchor == last_index
        let max_length = a:max_length - 3
    else
        let max_length = a:max_length - 4
    endif
    let range_info = s:get_viewport_range(label_lengths, max_length, anchor, direction)
    let [start_index, end_index, overflow] = range_info

    " change range if selected buffer is outside the original one
    let is_before = current_index < start_index
    let is_after = current_index > end_index
    let cropped_at_start = current_index == start_index && overflow != 0 && direction == 'left'
    let cropped_at_end = current_index == end_index && overflow != 0 && direction == 'right'
    if is_before || cropped_at_start
        let direction = 'right'
        let anchor = current_index
        let max_length = anchor == 0 ? a:max_length - 3 : a:max_length - 4
        let range_info = s:get_viewport_range(label_lengths, max_length, anchor, direction)
        let [start_index, end_index, overflow] = range_info
    elseif is_after || cropped_at_end
        let direction = 'left'
        let anchor = current_index
        let max_length = anchor == last_index ? a:max_length - 3 : a:max_length - 4
        let range_info = s:get_viewport_range(label_lengths, max_length, anchor, direction)
        let [start_index, end_index, overflow] = range_info
    endif

    " return result
    let left_overflow = direction == 'right' ? 0 : overflow
    let right_overflow = direction == 'right' ? overflow : 0
    let viewport_info = {}
    let viewport_info.start_index = start_index
    let viewport_info.end_index = end_index
    let viewport_info.left_arrow = start_index != 0 || left_overflow != 0
    let viewport_info.right_arrow = end_index != last_index || right_overflow != 0
    let viewport_info.left_overflow = left_overflow
    let viewport_info.right_overflow = right_overflow
    let viewport_info.anchor = anchor
    let viewport_info.anchor_direction = direction
    return viewport_info
endfunction

" Render the list of buffers
function! vem_tabline#buffers#section.render(max_length)

    " if there are no buffers there's nothing to show
    if len(self.buffer_items) == 0
        return ''
    endif

    " get range of buffers to show
    let anchor = self.anchor
    let direction = self.anchor_direction
    let viewport_info = s:get_viewport_info(self.buffer_items, a:max_length, anchor, direction)

    " save new anchor
    let self.anchor = viewport_info.anchor
    let self.anchor_direction = viewport_info.anchor_direction

    let initial = '%#VemTablineNormal#'
    let prefix = ' '
    let section = initial

    " show left overflow arrow
    if viewport_info.left_arrow
        let section .= g:vem_tabline_left_arrow
    endif

    let start_index = viewport_info.start_index
    let end_index = viewport_info.end_index
    for buffer_index in range(start_index, end_index)
        let buffer_item = self.buffer_items[buffer_index]

        " add prefix
        if buffer_item.current
            let prefix = '%#VemTablineSelected# '
        elseif buffer_item.shown
            let prefix = '%#VemTablineShown# '
        elseif prefix == '%#VemTablineSelected# ' || prefix == '%#VemTablineShown# '
            let prefix = ' %#VemTablineNormal#'
        else
            let prefix = ' '
        endif

        " partial label to the left
        if buffer_index == start_index && viewport_info.left_overflow != 0
            let discriminator_hl = ''
            let end_hl = ''
            let crop_direction = 'left'
            let overflow = viewport_info.left_overflow
        " partial label to the right
        elseif buffer_index == end_index && viewport_info.right_overflow != 0
            let discriminator_hl = ''
            let end_hl = ''
            let crop_direction = 'right'
            let overflow = viewport_info.right_overflow
        " current buffer
        elseif buffer_item.current
            let discriminator_hl = '%#VemTablineLocationSelected#'
            let end_hl = '%#VemTablineSelected#'
            let crop_direction = 'none'
            let overflow = 0
        " shown buffer
        elseif buffer_item.shown
            let discriminator_hl = '%#VemTablineLocationShown#'
            let end_hl = '%#VemTablineShown#'
            let crop_direction = 'none'
            let overflow = 0
        " all other buffers
        else
            let discriminator_hl = '%#VemTablineLocation#'
            let end_hl = '%#VemTablineNormal#'
            let crop_direction = 'none'
            let overflow = 0
        endif

        let label = buffer_item.render(discriminator_hl, end_hl, overflow, crop_direction)
        let section .= prefix . label
    endfor

    " show right overflow arrow
    if viewport_info.right_arrow
        let suffix = ' %#VemTablineNormal#' . g:vem_tabline_right_arrow
    else
        let suffix = ' %#VemTablineNormal#'
    endif

    let section .= suffix
    return section
endfunction

function! s:generate_labels(buffer_items)

    " iterate through buffers
    let buffer_items_count = len(a:buffer_items)
    for buffer_index in range(buffer_items_count)
        let buffer_item = a:buffer_items[buffer_index]
        let path_parts_count = len(buffer_item.path_parts)

        " empty name
        if path_parts_count == 0
            let buffer_item.name = '[No Name]'
            continue
        endif

        " set label index by comparing this buffer with next ones until a
        " unique label is generated
        if buffer_index != buffer_items_count - 1
            for next_item in a:buffer_items[buffer_index + 1:]
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

        " get discriminator
        if buffer_item.modified
            let buffer_item.flags = '*'
        endif
    endfor

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
function! s:find_first_non_match(list_a, list_b)

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

