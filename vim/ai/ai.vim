function! s:AI_status(msg) abort
  echo 'AI: ' . a:msg
  redraw
endfunction

function! s:AI_model_supports_thinking(model) abort
  let l:m = tolower(a:model)
  if l:m =~# 'deepseek'
        \ || l:m =~# 'r1'
        \ || l:m =~# 'thinking'
        \ || l:m =~# 'reason'
    return 1
  endif
  return 0
endfunction

function! AI(token, ...) abort
  let l:token = a:token
  let l:explicit_model = a:0 >= 1 ? a:1 : ''

  let l:last_input  = search('^>>> input\>',  'bnW')
  let l:last_thread = search('^>>> thread\>', 'bnW')

  if l:last_input == 0 && l:last_thread == 0
    echoerr "AI: No '>>> input' or '>>> thread' marker found"
    return
  endif

  if l:last_thread > l:last_input
    let l:kind  = 'thread'
    let l:start = l:last_thread
  else
    let l:kind  = 'input'
    let l:start = l:last_input
  endif

  let l:model = s:AI_resolve_model(l:start, l:explicit_model)
  if empty(l:model)
    return
  endif

  let l:region_end  = s:AI_find_region_end(l:start)
  let l:scope_start = s:AI_find_scope_start(l:start)

  if l:kind ==# 'thread'
    call s:AI_status('building thread messages...')
    let l:main_msgs = s:AI_build_thread_messages(l:scope_start, l:start)
  else
    call s:AI_status('building input message...')
    let l:main_msgs = s:AI_build_input_messages(l:start, l:region_end)
  endif

  if type(l:main_msgs) != type([])
    return
  endif

  call s:AI_status('collecting context...')
  let [l:ctx_system, l:ctx_resources] = s:AI_build_context_messages(l:scope_start, l:region_end, l:model)

  if l:kind ==# 'thread'
    if len(l:main_msgs) > 1
      let l:history  = l:main_msgs[0 : len(l:main_msgs) - 2]
      let l:cur_user = l:main_msgs[-1]
    else
      let l:history  = []
      let l:cur_user = l:main_msgs[0]
    endif
    let l:msgs = l:ctx_system + l:history + l:ctx_resources + [l:cur_user]
  else
    let l:msgs = l:ctx_system + l:ctx_resources + l:main_msgs
  endif

  call s:AI_status('building payload...')
  let l:payload = json_encode({
        \ 'model': l:model,
        \ 'messages': l:msgs,
        \ 'stream': v:false
        \ })

  call s:AI_status("sending payload to model '" . l:model . "'...")
  if s:AI_model_supports_thinking(l:model)
    call s:AI_status('model is thinking...')
  endif

  let l:cmd = [
        \ 'curl', '-sS',
        \ '-H', 'Authorization: Bearer ' . l:token,
        \ '-H', 'Content-Type: application/json',
        \ '-X', 'POST',
        \ '--data-binary', l:payload,
        \ 'https://openrouter.ai/api/v1/chat/completions'
        \ ]

  let l:opts = {
        \ 'out_cb':  function('s:AI_on_stdout', [bufnr('%'), l:kind, l:model]),
        \ 'out_mode': 'raw'
        \ }

  call job_start(l:cmd, l:opts)
endfunction

function! s:AI_resolve_model(marker_lnum, explicit_model) abort
  if !empty(a:explicit_model)
    return a:explicit_model
  endif

  let l:line = getline(a:marker_lnum)
  let l:is_thread = l:line =~# '^>>> thread\>'

  let l:m = matchlist(l:line, '^>>> \%(input\|thread\)\s\+\(\S\+\)')
  if !empty(l:m)
    let l:name = l:m[1]
    if exists('g:ai_models') && type(g:ai_models) == type({}) && has_key(g:ai_models, l:name)
      return g:ai_models[l:name]
    endif
    return l:name
  endif

  if l:is_thread
    let l:save_pos = getpos('.')
    call cursor(a:marker_lnum, 1)
    let l:prev_end = search('^>>> end$', 'bnW')
    call setpos('.', l:save_pos)

    if l:prev_end == 0
      let l:start = 1
    else
      let l:start = l:prev_end + 1
    endif

    let l:lnum = a:marker_lnum - 1
    while l:lnum >= l:start
      let l:l = getline(l:lnum)
      let l:m2 = matchlist(l:l, '^>>> thread\>\s\+\(\S\+\)')
      if !empty(l:m2)
        let l:name = l:m2[1]
        if exists('g:ai_models') && type(g:ai_models) == type({}) && has_key(g:ai_models, l:name)
          return g:ai_models[l:name]
        endif
        return l:name
      endif
      let l:lnum -= 1
    endwhile
  endif

  echoerr "AI: No model specified (neither in marker, previous thread, nor as argument)"
  return ''
endfunction

function! s:AI_find_region_end(start_lnum) abort
  let l:save_pos = getpos('.')
  call cursor(a:start_lnum, 1)
  let l:next_input  = search('^>>> input\>',  'nW')
  let l:next_thread = search('^>>> thread\>', 'nW')
  let l:next_end    = search('^>>> end$',     'nW')
  call setpos('.', l:save_pos)

  let l:cands = filter([l:next_input, l:next_thread, l:next_end], 'v:val > 0')
  if empty(l:cands)
    return line('$')
  endif
  return min(l:cands) - 1
endfunction

function! s:AI_find_scope_start(marker_lnum) abort
  let l:save_pos = getpos('.')
  call cursor(a:marker_lnum, 1)
  let l:prev_end    = search('^>>> end$',     'bnW')
  let l:prev_forget = search('^>>> forget\>', 'bnW')
  call setpos('.', l:save_pos)

  let l:start = 1
  if l:prev_end > 0
    let l:start = l:prev_end + 1
  endif
  if l:prev_forget > 0 && l:prev_forget >= l:start
    let l:start = l:prev_forget + 1
  endif
  return l:start
endfunction

function! s:AI_build_input_messages(start_lnum, region_end) abort
  let l:out = 0
  for lnum in range(a:start_lnum + 1, a:region_end)
    if getline(lnum) =~# '^>>> output\>'
      let l:out = lnum
      break
    endif
  endfor

  if l:out > 0
    let l:input_end = l:out - 1
  else
    let l:input_end = a:region_end
  endif

  if l:input_end < a:start_lnum + 1
    echoerr "AI: No content after '>>> input'"
    return 0
  endif

  let l:lines = getline(a:start_lnum + 1, l:input_end)

  let l:ctx = []
  for l:line in l:lines
    let l:m = matchlist(l:line, '^>>> \S\+\s*\(.*\)$')
    if !empty(l:m)
      call add(l:ctx, l:m[1])
    else
      call add(l:ctx, l:line)
    endif
  endfor

  let l:input_text = join(l:ctx, "\n")
  if empty(trim(l:input_text))
    echoerr "AI: Empty input block"
    return 0
  endif

  return [ {'role': 'user', 'content': l:input_text} ]
endfunction

function! s:AI_build_thread_messages(scope_start_lnum, last_thread_lnum) abort
  let l:start = a:scope_start_lnum
  let l:last  = line('$')
  let l:lines = getline(l:start, l:last)
  let l:n     = len(l:lines)
  let l:rel_last_thread = a:last_thread_lnum - l:start

  let l:msgs = []
  let l:i = 0
  let l:cur_idx = -1

  while l:i < l:n
    if l:lines[l:i] =~# '^>>> input\>'
      let l:k = l:i + 1
      while l:k < l:n && l:lines[l:k] !~ '^>>> '
        let l:k += 1
      endwhile
      let l:i = l:k
      continue
    endif

    if l:lines[l:i] =~# '^>>> thread\>'
      if l:i == l:rel_last_thread
        let l:cur_idx = l:i
        break
      endif

      let l:user_start = l:i + 1
      let l:j = l:user_start
      while l:j < l:n && l:lines[l:j] !~ '^>>> '
        let l:j += 1
      endwhile
      let l:user_end = l:j - 1

      let l:user_text = ''
      if l:user_start <= l:user_end
        let l:user_text = join(l:lines[l:user_start : l:user_end], "\n")
      endif

      if l:j >= l:n || l:lines[l:j] !~# '^>>> output\>'
        if !empty(trim(l:user_text))
          call add(l:msgs, {'role': 'user', 'content': l:user_text})
        endif
        let l:i = l:j
        continue
      endif

      let l:assistant_start = l:j + 1
      if l:assistant_start < l:n && l:lines[l:assistant_start] =~ '^\s*$'
        let l:assistant_start += 1
      endif

      let l:k = l:assistant_start
      while l:k < l:n && l:lines[l:k] !~ '^>>> '
        let l:k += 1
      endwhile
      let l:assistant_end = l:k - 1

      let l:assistant_text = ''
      if l:assistant_start <= l:assistant_end
        let l:assistant_text = join(l:lines[l:assistant_start : l:assistant_end], "\n")
      endif

      if !empty(trim(l:user_text))
        call add(l:msgs, {'role': 'user', 'content': l:user_text})
      endif
      if !empty(trim(l:assistant_text))
        call add(l:msgs, {'role': 'assistant', 'content': l:assistant_text})
      endif

      let l:i = l:k
      continue
    endif

    let l:i += 1
  endwhile

  if l:cur_idx == -1
    echoerr "AI: Internal error locating current thread block"
    return 0
  endif

  let l:user_start = l:cur_idx + 1
  let l:j = l:user_start
  while l:j < l:n && l:lines[l:j] !~ '^>>> '
    let l:j += 1
  endwhile
  let l:user_end = l:j - 1

  if l:user_start > l:user_end
    echoerr "AI: No content after '>>> thread'"
    return 0
  endif

  let l:cur_input_lines = l:lines[l:user_start : l:user_end]
  let l:input_text = join(l:cur_input_lines, "\n")
  if empty(trim(l:input_text))
    echoerr "AI: Empty thread input block"
    return 0
  endif

  call add(l:msgs, {'role': 'user', 'content': l:input_text})
  return l:msgs
endfunction

function! s:AI_build_context_messages(scope_start_lnum, scope_end_lnum, model) abort
  let l:system_msgs   = []
  let l:resource_msgs = []

  let l:ignore = []
  if exists('g:ai_ignore') && type(g:ai_ignore) == type([])
    let l:ignore = copy(g:ai_ignore)
  endif

  let l:seen_files = {}
  let l:seen_urls  = {}

  let l:supports_images = s:AI_model_supports_images(a:model)

  let l:lnum = a:scope_start_lnum
  while l:lnum <= a:scope_end_lnum
    let l:line = getline(l:lnum)

    if l:line =~# '^>>> context\>'
      let l:ctx_lnum = l:lnum + 1
      while l:ctx_lnum <= a:scope_end_lnum && getline(l:ctx_lnum) !~# '^>>> '
        let l:ctxline = trim(getline(l:ctx_lnum))
        if l:ctxline ==# ''
          let l:ctx_lnum += 1
          continue
        endif

        let l:m = matchlist(l:ctxline, '^\(\w\+\)\s*:\s*\(.*\)$')
        if empty(l:m)
          let l:ctx_lnum += 1
          continue
        endif

        let l:kind = tolower(l:m[1])
        let l:val  = l:m[2]

        if l:kind ==# 'ignore'
          if !empty(l:val)
            call add(l:ignore, l:val)
          endif

        elseif l:kind ==# 'role'
          if !empty(l:val)
            call s:AI_status('adding role instructions to context...')
            call add(l:system_msgs, {'role': 'system', 'content': l:val})
          endif

        elseif l:kind ==# 'file'
          let l:path = s:AI_normalize_path(l:val)
          if !empty(l:path) && filereadable(l:path)
            if !s:AI_path_ignored(l:path, l:ignore) && !has_key(l:seen_files, l:path)
              let l:seen_files[l:path] = 1
              let l:msg = s:AI_make_file_message(l:path, l:supports_images)
              if type(l:msg) == type({})
                call s:AI_status('adding file "' . fnamemodify(l:path, ':.') . '" to context...')
                call add(l:resource_msgs, l:msg)
              endif
            endif
          endif

        elseif l:kind ==# 'dir'
          let l:dir = s:AI_normalize_path(l:val)
          if !empty(l:dir) && isdirectory(l:dir)
            call s:AI_status('collecting files from dir "' . fnamemodify(l:dir, ':.') . '" for context...')
            for l:f in s:AI_list_dir_files(l:dir, l:ignore)
              if !has_key(l:seen_files, l:f)
                let l:seen_files[l:f] = 1
                let l:msg = s:AI_make_file_message(l:f, l:supports_images)
                if type(l:msg) == type({})
                  call s:AI_status('adding file "' . fnamemodify(l:f, ':.') . '" to context...')
                  call add(l:resource_msgs, l:msg)
                endif
              endif
            endfor
          endif

        elseif l:kind ==# 'url'
          let l:url = l:val
          if !empty(l:url) && !has_key(l:seen_urls, l:url)
            let l:seen_urls[l:url] = 1
            let l:msg = s:AI_make_url_message(l:url)
            if type(l:msg) == type({})
              call s:AI_status("adding url '" . l:url . "' to context...")
              call add(l:resource_msgs, l:msg)
            endif
          endif
        endif

        let l:ctx_lnum += 1
      endwhile

      let l:lnum = l:ctx_lnum
      continue
    endif

    let l:lnum += 1
  endwhile

  return [l:system_msgs, l:resource_msgs]
endfunction

function! s:AI_normalize_path(p) abort
  let l:s = trim(a:p)
  if empty(l:s)
    return ''
  endif
  let l:s = expand(l:s)
  return fnamemodify(l:s, ':p')
endfunction

function! s:AI_path_ignored(path, ignore_patterns) abort
  if empty(a:ignore_patterns)
    return 0
  endif
  let l:rel = fnamemodify(a:path, ':.')
  for l:pat in a:ignore_patterns
    if empty(l:pat)
      continue
    endif
    try
      if l:rel =~ glob2regpat(l:pat)
        return 1
      endif
    catch
    endtry
  endfor
  return 0
endfunction

function! s:AI_list_dir_files(dir, ignore_patterns) abort
  let l:base = fnamemodify(a:dir, ':p')
  if l:base[-1:] !=# '/'
    let l:base .= '/'
  endif
  let l:paths = glob(l:base . '*', 0, 1)
  let l:files = []
  for l:p in l:paths
    if filereadable(l:p) && !s:AI_path_ignored(l:p, a:ignore_patterns)
      call add(l:files, l:p)
    endif
  endfor
  return l:files
endfunction

function! s:AI_make_file_message(path, supports_images) abort
  let l:ext = tolower(fnamemodify(a:path, ':e'))
  let l:rel = fnamemodify(a:path, ':.')
  call s:AI_status('reading file "' . l:rel . '" to context...')

  if index(['png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp', 'svg'], l:ext) >= 0
    if !a:supports_images
      return {'role': 'user', 'content': 'Image file (not inlined; model has no vision support): ' . l:rel}
    endif

    let l:mime = s:AI_guess_image_mime(l:ext)
    if l:mime ==# ''
      let l:mime = 'image/png'
    endif

    let l:cmd = 'base64 ' . shellescape(a:path)
    let l:b64 = substitute(system(l:cmd), '\s\+', '', 'g')
    if v:shell_error != 0 || empty(l:b64)
      return {'role': 'user', 'content': 'Image file (failed to read): ' . l:rel}
    endif

    let l:data_url = 'data:' . l:mime . ';base64,' . l:b64
    return {
          \ 'role': 'user',
          \ 'content': [
          \   {'type': 'text', 'text': 'Image from file ' . l:rel},
          \   {'type': 'image_url', 'image_url': {'url': l:data_url}}
          \ ]
          \ }
  endif

  let l:text = s:AI_read_text_file(a:path)
  if empty(l:text)
    return {}
  endif

  let l:fenced = l:ext
  if l:fenced ==# ''
    let l:fenced = 'text'
  endif

  let l:content = 'File: ' . l:rel . "\n\n```" . l:fenced . "\n" . l:text . "\n```"
  return {'role': 'user', 'content': l:content}
endfunction

function! s:AI_guess_image_mime(ext) abort
  if a:ext ==# 'png'
    return 'image/png'
  elseif a:ext ==# 'jpg' || a:ext ==# 'jpeg'
    return 'image/jpeg'
  elseif a:ext ==# 'gif'
    return 'image/gif'
  elseif a:ext ==# 'webp'
    return 'image/webp'
  elseif a:ext ==# 'bmp'
    return 'image/bmp'
  elseif a:ext ==# 'svg'
    return 'image/svg+xml'
  endif
  return ''
endfunction

function! s:AI_read_text_file(path) abort
  if !filereadable(a:path)
    return ''
  endif

  let l:max_bytes = exists('g:ai_max_file_bytes') ? g:ai_max_file_bytes : 200000
  let l:max_lines = exists('g:ai_max_file_lines') ? g:ai_max_file_lines : 2000

  let l:size = getfsize(a:path)
  if l:size < 0
    let l:size = 0
  endif

  let l:truncated = (l:size > l:max_bytes && l:max_bytes > 0)

  if l:truncated
    let l:lines = readfile(a:path, '', l:max_lines)
  else
    let l:lines = readfile(a:path)
  endif

  let l:text = join(l:lines, "\n")
  if l:truncated
    let l:text .= "\n\n[... file truncated; original size " . l:size . " bytes ...]"
  endif
  return l:text
endfunction

function! s:AI_make_url_message(url) abort
  call s:AI_status("reading url '" . a:url . "'...")
  let l:max_bytes = exists('g:ai_max_url_bytes') ? g:ai_max_url_bytes : 200000

  let l:res = system('curl -fsSL ' . shellescape(a:url))
  if v:shell_error != 0
    call s:AI_status("failed to fetch url '" . a:url . "'")
    return {
          \ 'role': 'user',
          \ 'content': 'Failed to fetch URL: ' . a:url
          \ }
  endif

  let l:body = strpart(l:res, 0, l:max_bytes)
  let l:trunc = (strlen(l:res) > l:max_bytes)
  if l:trunc
    let l:body .= "\n\n[... response truncated ...]"
  endif

  let l:content =
        \ "You are given an offline snapshot of the content of this URL:\n" .
        \ a:url . "\n\n" .
        \ "Use ONLY the content below as the page content when answering " .
        \ "questions about this website. Do NOT say that you cannot browse " .
        \ "the internet; you already have the page content.\n\n" .
        \ "----- BEGIN PAGE CONTENT -----\n" .
        \ l:body . "\n" .
        \ "----- END PAGE CONTENT -----"

  return {'role': 'user', 'content': l:content}
endfunction

function! s:AI_model_supports_images(model) abort
  let l:m = tolower(a:model)
  if l:m =~# 'vision'
        \ || l:m =~# 'gpt-4o'
        \ || l:m =~# 'gpt-4\.1'
        \ || l:m =~# 'claude-3'
        \ || l:m =~# 'llama-3\.2-vision'
    return 1
  endif
  return 0
endfunction

function! s:AI_on_stdout(bufnr, kind, model, job_id, data) abort
  call s:AI_status('model is replying...')

  if type(a:data) == type([])
    let l:joined = join(a:data, "\n")
  else
    let l:joined = a:data
  endif

  if empty(trim(l:joined))
    return
  endif

  try
    let l:res = json_decode(l:joined)
  catch
    echoerr "AI: Failed to decode JSON response"
    return
  endtry

  if type(l:res) != type({}) || !has_key(l:res, 'choices') || empty(l:res.choices)
    echoerr "AI: Unexpected response from model"
    return
  endif

  let l:text = get(l:res.choices[0].message, 'content', '')
  if empty(l:text)
    echoerr "AI: Empty content in model response"
    return
  endif

  let l:buf = a:bufnr
  if !bufexists(l:buf)
    return
  endif

  call s:AI_status('building output...')

  let l:curbuf = bufnr('%')
  execute 'keepalt buffer' l:buf

  if a:kind ==# 'thread'
    let l:marker_pat = '^>>> thread\>'
  else
    let l:marker_pat = '^>>> input\>'
  endif

  let l:start = search(l:marker_pat, 'bnW')
  if l:start == 0
    echoerr "AI: Marker not found when inserting output"
    if l:curbuf != l:buf && bufexists(l:curbuf)
      execute 'keepalt buffer' l:curbuf
    endif
    return
  endif

  let l:save_pos = getpos('.')
  call cursor(l:start, 1)
  let l:next_input  = search('^>>> input\>',  'nW')
  let l:next_thread = search('^>>> thread\>', 'nW')
  let l:next_end    = search('^>>> end$',     'nW')
  call setpos('.', l:save_pos)

  let l:cands = filter([l:next_input, l:next_thread, l:next_end], 'v:val > 0')
  if empty(l:cands)
    let l:region_end = line('$')
  else
    let l:region_end = min(l:cands) - 1
  endif

  let l:out = 0
  for lnum in range(l:start + 1, l:region_end)
    if getline(lnum) =~# '^>>> output\>'
      let l:out = lnum
      break
    endif
  endfor

  if l:out > 0
    let l:del_start = l:out
    if l:out > l:start + 1 && getline(l:out - 1) =~ '^\s*$'
      let l:del_start = l:out - 1
    endif
    call deletebufline(l:buf, l:del_start, l:region_end)
    let l:insert_lnum = l:del_start - 1
  else
    let l:insert_lnum = l:region_end
  endif

  call append(l:insert_lnum, '')
  call append(l:insert_lnum + 1, '>>> output by ' . a:model)
  call append(l:insert_lnum + 2, '')
  call append(l:insert_lnum + 3, split(l:text, "\n"))

  call s:AI_status('done.')

  if l:curbuf != l:buf && bufexists(l:curbuf)
    execute 'keepalt buffer' l:curbuf
  endif
endfunction
