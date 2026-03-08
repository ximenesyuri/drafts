" Author: Yuri Ximenes
" Contact: ximenesyuri@gmx.ie
" Description: copy last code block in the form ```<lang> for some language.

function! s:copy_last_code_block()
    let l:save_pos = getpos('.')
    try
        let l:found = search('^\s*```[a-zA-Z]\+', 'bW')
        if l:found
            normal! j
            let l:start_content_pos = getpos('.')

            let l:end_found = search('^\s*```$', 'W')
            if l:end_found
                normal! k
                let l:end_content_pos = getpos('.')

                execute l:start_content_pos[1] . ',' . l:end_content_pos[1] . 'y+'
                echom 'Code block content copied to clipboard.'
            else
                echom 'End of code block not found.'
            endif
        else
            echom 'No code block found with a language specifier.'
        endif
    catch /.*/
        echom 'Error occurred: ' . v:exception
    endtry

    call setpos('.', l:save_pos)
endfunction

nnoremap <leader>cc :call <SID>copy_last_code_block()<CR>
