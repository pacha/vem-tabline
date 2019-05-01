" Vem Tabline: tabpages

" Due to a bug in Vim dictionary functions don't trigger script autoload
" This is just a workaround to load the files
function! vem_tabline#tabpages#Init() abort
    return 1
endfunction

let vem_tabline#tabpages#section = {}
let vem_tabline#tabpages#section.tabpage_count = 0

" Update state of the section
function! vem_tabline#tabpages#section.update() abort
    let self.tabpage_count = tabpagenr('$')
endfunction

" Calculate the length in characters of the section
" It considers each tab to consist of the number itself and two blank
" characters at the sides. eg ' 12 '. Only works up to 999 tabs.
function! vem_tabline#tabpages#section.get_length() abort
    if self.tabpage_count == 1
        return 0
    elseif self.tabpage_count < 10
        return self.tabpage_count * 3
    elseif self.tabpage_count < 100
        return (self.tabpage_count - 9) * 4 + (9 * 3)
    else
        return (self.tabpage_count - 90) * 5 + (self.tabpage_count - 9) * 4 + (9 * 3)
    endif
endfunction

" render the tabpage list
function! vem_tabline#tabpages#section.render() abort

    if self.tabpage_count == 1
        return ''
    endif

    let section = ''
    for tabpage_nr in range(1, self.tabpage_count)

        " select the highlighting
        if tabpage_nr == tabpagenr()
            let section .= '%#VemTablineTabSelected#'
        else
            let section .= '%#VemTablineTabNormal#'
        endif

        " set the tab page number (for mouse clicks) and label
        let section .= '%' . tabpage_nr . 'T ' . tabpage_nr . ' '
    endfor

    " after the last tab reset tab page number
    let section .= '%T'

    return section

endfunction

