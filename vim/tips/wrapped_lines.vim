"Author: Yuri Ximenes
"Contact: ximenesyuri@gmx.ie
"Description: moving along wrapped lined is a bit tricky, specially in insert
" mode. The following configuration do the job quite well.

inoremap <silent> <down> <c-r>=pumvisible() ? "\<lt>down>" : "\<lt>c-o>gj"<cr>
inoremap <silent> <up> <c-r>=pumvisible() ? "\<lt>up>" : "\<lt>c-o>gk"<cr>
nnoremap <expr> <up> (v:count == 0 ? 'gk' : 'k')
nnoremap <expr> <down> (v:count == 0 ? 'gj' : 'j')            
vnoremap <up> gk
vnoremap <down> gj
