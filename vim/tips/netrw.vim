"NETRW
"> Layout
">> hide banner
    let g:netrw_banner = 0
">> allow toggle hide
    let g:netrw_hide= 1
">> hide dot files by default
    let g:netrw_list_hide = '\(^\|\s\s\)\zs\.\S\+'
">> windows size
    let g:netrw_winsize = 15
">> open files in new window
    if argv(0) ==# '.'
        let g:netrw_browse_split = 0
    else
        let g:netrw_browse_split = 4
    endif   
">> sync current and browsing directories
    let g:netrw_keepdir = 0
">> directories on the top, files below
    let g:netrw_sort_sequence = '[\/]$,*'
">> change of directory when opening a file
    set autochdir
">> set the default application to be called with "x"
    let g:netrw_browsex_viewer= "x"
">> keep cursor position
    let g:netrw_fastbrowse = 2
">> change the highlight of markded files
    hi! link netrwMarkFile Search
">> print in /tmp/vim_cwd the current working directory when Netrw is closed
    autocmd BufDelete * if &ft ==# 'netrw' | let g:cwd = expand('%:p:h') | call writefile([g:cwd], '/tmp/vim_cwd') | endif
"> Hotkeys 
    augroup netrw_setup | au! 
        au FileType netrw  nmap <leader>o :Lexplore<cr>
">> 'p' to display the current directory. 'h' to toggle hidden files
        au FileType netrw nmap <buffer> p :pwd<cr>
        au FileType netrw nmap <buffer> h gh
">> 'a' to mark files. 'w', and  'e' to execute command for marked files.
        au FileType netrw nmap <buffer> a mf
        au FileType netrw nmap <buffer> w mx
        au FileType netrw nmap <buffer> e mX
">> 'left' and 'right'/'enter' to change directory.
        au FileType netrw nmap <buffer> <right> <cr>cd
        au FileType netrw nmap <buffer> <left> -cd
">> 'r' to refresh Netrw
        au FileType netrw nmap <buffer> r <c-l>
">> 'mkf', 'd', 'D' , 'mv' and 'cp' to do the basic stuff
        au FileType netrw nmap <buffer> mkf cd:AsyncRun touch 
        au FileType netrw nmap <buffer> mkd cd:AsyncRun mkdir 
        au FileType netrw nmap <buffer> .mf cd:AsyncRun touch 
        au FileType netrw nmap <buffer> .md cd:AsyncRun mkdir 
        au FileType netrw nmap <buffer> d cd:AsyncRun .d 
        au FileType netrw nmap <buffer> rm cd:AsyncRun rm -r 
        au FileType netrw nmap <buffer> mv cd:AsyncRun mv 
        au FileType netrw nmap <buffer> cp cd:AsyncRun cp -r 
    augroup END
