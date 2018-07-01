" Vem Tabline: separator

" Due to a bug in Vim dictionary functions don't trigger script autoload
" This is just a workaround to load the files
function! vem_tabline#separator#Init()
    return 1
endfunction

let vem_tabline#separator#section = {}
let vem_tabline#separator#section.label = ''
let vem_tabline#separator#section.extra_buffer_count = 0

" Update state of the section
function! vem_tabline#separator#section.update(extra_buffer_count)
    let self.extra_buffer_count = a:extra_buffer_count
    if self.extra_buffer_count != 0
        let self.label = ' +' . self.extra_buffer_count . ' more '
    else
        let self.label = ''
    endif
endfunction

" Calculate the length in characters of the section
function! vem_tabline#separator#section.get_length()
    return len(self.label)
endfunction

" Render the '+ <N> more' buffers indicator
function! vem_tabline#separator#section.render()
    if self.extra_buffer_count != 0
        return '%#VemTablineSeparator#' . self.label . '%='
    else
        return '%#VemTablineNormal#%='
    endif
endfunction

