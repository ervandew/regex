" Author:  Eric Van Dewoestine
"
" License: {{{
"   Copyright (c) 2005 - 2011, Eric Van Dewoestine
"   All rights reserved.
"
"   Redistribution and use of this software in source and binary forms, with
"   or without modification, are permitted provided that the following
"   conditions are met:
"
"   * Redistributions of source code must retain the above
"     copyright notice, this list of conditions and the
"     following disclaimer.
"
"   * Redistributions in binary form must reproduce the above
"     copyright notice, this list of conditions and the
"     following disclaimer in the documentation and/or other
"     materials provided with the distribution.
"
"   * Neither the name of Eric Van Dewoestine nor the names of its
"     contributors may be used to endorse or promote products derived from
"     this software without specific prior written permission of
"     Eric Van Dewoestine.
"
"   THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS
"   IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
"   THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
"   PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
"   CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
"   EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
"   PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
"   PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
"   LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
"   NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
"   SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
" }}}

" Global Variables {{{
  if !exists("g:RegexHi{0}")
    let g:RegexHi{0} = 'Constant'
  endif

  if !exists("g:RegexHi{1}")
    let g:RegexHi{1} = 'MoreMsg'
  endif

  if !exists("g:RegexGroupHi{0}")
    let g:RegexGroupHi{0} = 'Statement'
  endif

  if !exists("g:RegexGroupHi{1}")
    let g:RegexGroupHi{1} = 'Todo'
  endif

  if !exists("g:RegexTempDir")
    let g:RegexTempDir = expand('$TMP')
    if g:RegexTempDir == '$TMP'
      let g:RegexTempDir = expand('$TEMP')
    endif
    if g:RegexTempDir == '$TEMP' && has('unix')
      let g:RegexTempDir = '/tmp'
    endif
    let g:RegexTempDir = substitute(g:RegexTempDir, '\', '/', 'g')
  endif
" }}}

" Script Variables {{{
  " \%2l\%6c\_.*\%3l\%19c
  let s:pattern = '\%<startline>l\%<startcolumn>c\_.*\%<endline>l\%<endcolumn>c'

  let s:test_content = [
      \ 'te(st)',
      \ 'Some test content used to test',
      \ 'language specific regex against.',
    \ ]

  let s:regexfile = g:RegexTempDir . '/regex_<lang>.txt'
" }}}

" OpenTestWindow(lang) {{{
" Opens a buffer where the user can test regex expressions.
function! regex#regex#OpenTestWindow(lang)
  let lang = a:lang != '' ? a:lang : &ft
  let file = substitute(s:regexfile, '<lang>', lang, '')
  if bufwinnr(file) == -1
    exec "botright 10split " . file
    setlocal ft=regex
    setlocal winfixheight
    setlocal bufhidden=delete
    setlocal nobuflisted
    setlocal nobackup
    setlocal nowritebackup
    setlocal statusline=%<%f\ %h%=%-10.(%l,%c%V\ flags=%{b:regex_flags}%)\ %P

    let b:regex_flags = 'm' " default multiline on
    let b:regex_lang = lang

    nnoremap <buffer> <silent> <c-f> :call <SID>Flags()<cr>
    command -buffer NextMatch :call s:NextMatch()
    command -buffer PrevMatch :call s:PrevMatch()

    augroup regex
      autocmd!
      autocmd BufWritePost <buffer> call s:Evaluate()
      autocmd BufWinLeave <buffer> call s:FlagsClose()
    augroup END
  endif

  nohlsearch
  noautocmd write
  call s:Evaluate()
endfunction " }}}

" s:Evaluate() {{{
" Evaluates the test regex file.
function! s:Evaluate()
  if line('$') == 1 && getline('$') == ''
    call s:AddTestContent()
  endif

  " forces reset of syntax
  set ft=regex

  let lang = b:regex_lang
  let file = substitute(s:regexfile, '<lang>', lang, '')
  let b:results = []
  try
    exec 'let out = regex#lang#' . lang . '#Evaluate("' . file . '", b:regex_flags)'
  catch /E117/
    echohl Error | echom 'Regex does not yet support ' . lang | echohl Normal
    call delete(file)
    set nomodified
    bdelete
    return
  endtry

  let results = split(out, '\n')
  if len(results) == 1 && results[0] == '0'
    return
  endif
  let b:results = results

  let offsets = s:CompileOffsets(file)

  let matchIndex = 0
  for result in results
    let groups = split(result, ',')
    let groupIndex = 0
    if len(groups) > 1
      for group in groups[1:]
        let patterns = s:BuildPatterns(group, offsets)
        for pattern in patterns
          exec 'syntax match ' . g:RegexGroupHi{groupIndex % 2} .
            \ ' /' . pattern . '/ '
        endfor
        let groupIndex += 1
      endfor
    endif

    let match = groups[0]
    let patterns = s:BuildPatterns(match, offsets)

    for pattern in patterns
      exec 'syntax match ' . g:RegexHi{matchIndex % 2} .
        \ ' /' . pattern . '/ ' .
        \ 'contains=' . g:RegexGroupHi0 . ',' . g:RegexGroupHi1
    endfor

    let matchIndex += 1
  endfor
endfunction "}}}

" s:BuildPatterns(match, offsets) {{{
" Builds the regex patterns for the supplied match.
function! s:BuildPatterns(match, offsets)
  " vim (as of 7 beta 2) doesn't seem to be handling multiline matches very
  " well (highlighting can get lost while scrolling), so here we break them up.
  exec 'let [start,end] = ' . string(split(a:match, '-'))
  let [startLine, startColumn] = a:offsets.offsetToLineColumn(start)
  let [endLine, endColumn] = a:offsets.offsetToLineColumn(end)

  let patterns = []

  if startLine < endLine
    while startLine < endLine
      " ignore virtual sections.
      if startColumn <= len(getline(startLine))
        let pattern = s:pattern
        let pattern = substitute(pattern, '<startline>', startLine, '')
        let pattern = substitute(pattern, '<startcolumn>', startColumn, '')
        let pattern = substitute(pattern, '<endline>', startLine, '')
        let pattern = substitute
          \ (pattern, '<endcolumn>', len(getline(startLine)) + 1, '')
        call add(patterns, pattern)
      endif
      let startLine += 1
      let startColumn = 1
    endwhile

    let pattern = s:pattern
    let pattern = substitute(pattern, '<startline>', endLine, '')
    let pattern = substitute(pattern, '<startcolumn>', 1, '')
    let pattern = substitute(pattern, '<endline>', endLine, '')
    let pattern = substitute(pattern, '<endcolumn>', endColumn + 1, '')
    call add(patterns, pattern)
  else
    let pattern = s:pattern
    let pattern = substitute(pattern, '<startline>', startLine, '')
    let pattern = substitute(pattern, '<startcolumn>', startColumn, '')
    let pattern = substitute(pattern, '<endline>', endLine, '')
    let pattern = substitute(pattern, '<endcolumn>', endColumn + 1, '')
    call add(patterns, pattern)
  endif

  return patterns
endfunction" }}}

" s:CompileOffsets(file) {{{
" Compile a set of offsets to line numbers for quick conversion of offsets to
" line/column.
function! s:CompileOffsets(file)
  let offsets = {'offsets': []}

  function! offsets.compile(file) dict " {{{
    let offset = 0
    call add(self.offsets, offset)
    for line in readfile(a:file, 'b')
      let offset += len(line) + 1
      call add(self.offsets, offset)
    endfor
  endfunction " }}}

  function! offsets.offsetToLineColumn(offset) dict " {{{
    if a:offset <= 0
      return [1, 1]
    endif

    let bot = -1
    let top = len(self.offsets) - 1
    while (top - bot) > 1
      let mid = (top + bot) / 2
      if self.offsets[mid] < a:offset
        let bot = mid
      else
        let top = mid
      endif
    endwhile

    if self.offsets[top] > a:offset
      let top -= 1
    endif

    let line = top + 1
    let column = 1 + a:offset - self.offsets[top]
    return [line, column]
  endfunction " }}}

  call offsets.compile(a:file)

  return offsets
endfunction " }}}

" s:Flags() {{{
" Opens a window where the user can enable/disable regex compile flags.
function! s:Flags()
  if s:FlagsClose()
    return
  endif

  let regex_flags = b:regex_flags
  let regex_buffer = bufnr('%')

  vertical rightb 50new RegexFlags

  let b:regex_buffer = regex_buffer

  let m = regex_flags =~ 'm' ? 'x' : ' '
  let i = regex_flags =~ 'i' ? 'x' : ' '
  let d = regex_flags =~ 'd' ? 'x' : ' '

  call append(1, [
      \ 'Toggle regex compile flags using <cr> or <space>.',
      \ '',
      \ m . ' (m) multiline',
      \ i . ' (i) ignore case',
      \ d . ' (d) dotall',
    \ ])
  1,1delete _

  setlocal nonumber
  setlocal buftype=nofile
  setlocal winfixwidth

  nnoremap <buffer> <silent> <c-f> :call <SID>Flags()<cr>
  nnoremap <buffer> <silent> <space> :call <SID>ToggleFlag()<cr>
  nnoremap <buffer> <silent> <cr> :call <SID>ToggleFlag()<cr>
  nnoremap <buffer> <silent> u <Nop>
  nnoremap <buffer> <silent> U <Nop>
  nnoremap <buffer> <silent> <c-r> <Nop>
endfunction " }}}

" s:FlagsClose() {{{
function! s:FlagsClose()
  let winnr = bufwinnr('RegexFlags')
  if winnr != -1
    let curwin = winnr()
    exec winnr . 'winc w'
    bdelete
    exec curwin . 'winc w'
    return 1
  endif
  return 0
endfunction " }}}

" s:ToggleFlag() {{{
function! s:ToggleFlag()
  let line = getline('.')
  if line =~ '^[x ] ([mid])'
    let value = line =~ '^x' ? ' ' : 'x'
    call setline('.', value . line[1:])
  endif
  let lines = filter(getline(1, '$'), 'v:val =~ "^x ([mid])"')
  let flags = join(map(lines, 'substitute(v:val, "x (\\(\\w\\)).*", "\\1", "")'), '')
  call setbufvar(b:regex_buffer, 'regex_flags', flags)

  let winnr = bufwinnr(b:regex_buffer)
  if winnr != -1
    let curwinnr = winnr()
    exec winnr . 'winc w'
    call s:Evaluate()
    exec curwinnr . 'winc w'
  endif
endfunction " }}}

" s:NextMatch() {{{
" Moves the cursor to the next match.
function! s:NextMatch()
  if exists("b:results")
    let curline = line('.')
    let curcolumn = col('.')
    for result in b:results
      let line = substitute(result, '\([0-9]\+\):.*', '\1', '')
      let column = substitute(result, '[0-9]\+:\([0-9]\+\).*', '\1', '')
      if column > len(getline(line))
        let column -= 1
      endif
      if (line > curline) || (line == curline && column > curcolumn)
        call cursor(line, column)
        return
      endif
    endfor
    if len(b:results) > 0
      let result = b:results[0]
      echohl WarningMsg | echo "Search hit BOTTOM, continuing at TOP" | echohl Normal
      let line = substitute(result, '\([0-9]\+\):.*', '\1', '')
      let column = substitute(result, '[0-9]\+:\([0-9]\+\).*', '\1', '')
      call cursor(line, column)
    endif
  endif
endfunction " }}}

" s:PrevMatch() {{{
" Moves the cursor to the previous match.
function! s:PrevMatch()
  if exists("b:results")
    let curline = line('.')
    let curcolumn = col('.')
    let index = len(b:results) - 1
    while index >= 0
      let result = b:results[index]
      let line = substitute(result, '\([0-9]\+\):.*', '\1', '')
      let column = substitute(result, '[0-9]\+:\([0-9]\+\).*', '\1', '')
      if column > len(getline(line))
        let column -= 1
      endif
      if (line < curline) || (line == curline && column < curcolumn)
        call cursor(line, column)
        return
      endif
      let index -= 1
    endwhile
    if len(b:results) > 0
      let result = b:results[len(b:results) - 1]
      echohl WarningMsg | echo "Search hit TOP, continuing at BOTTOM" | echohl Normal
      let line = substitute(result, '\([0-9]\+\):.*', '\1', '')
      let column = substitute(result, '[0-9]\+:\([0-9]\+\).*', '\1', '')
      call cursor(line, column)
    endif
  endif
endfunction " }}}

" s:AddTestContent() {{{
" Add the test content to the current regex test file.
function! s:AddTestContent()
  call append(1, s:test_content)
  1,1delete _
endfunction " }}}

" System(cmd) {{{
" Executes system() accounting for possibly disruptive vim options.
function! regex#regex#System(cmd)
  let saveshell = &shell
  let saveshellcmdflag = &shellcmdflag
  let saveshellpipe = &shellpipe
  let saveshellquote = &shellquote
  let saveshellredir = &shellredir
  let saveshellslash = &shellslash
  let saveshelltemp = &shelltemp
  let saveshellxquote = &shellxquote

  if has('win32') || has('win64')
    set shell=cmd.exe shellcmdflag=/c
    set shellpipe=>%s\ 2>&1 shellredir=>%s\ 2>&1
    set shellquote= shellxquote=
    set shelltemp noshellslash
  else
    if executable('/bin/bash')
      set shell=/bin/bash
    else
      set shell=/bin/sh
    endif
    set shellcmdflag=-c
    set shellpipe=2>&1\|\ tee shellredir=>%s\ 2>&1
    set shellquote= shellxquote=
    set shelltemp noshellslash
  endif

  let result = system(a:cmd)

  let &shell = saveshell
  let &shellcmdflag = saveshellcmdflag
  let &shellquote = saveshellquote
  let &shellslash = saveshellslash
  let &shelltemp = saveshelltemp
  let &shellxquote = saveshellxquote
  let &shellpipe = saveshellpipe
  let &shellredir = saveshellredir

  if v:shell_error
    echohl Error
    echom 'Failed to execute command (' . a:cmd . '): ' . result
    echohl Normal
    return
  endif

  return result
endfunction " }}}

" Cygpath(path, type) {{{
function! regex#regex#Cygpath(path, type)
  if executable('cygpath')
    let path = substitute(a:path, '\', '/', 'g')
    if a:type == 'windows'
      let path = regex#System('cygpath -m "' . path . '"')
    else
      let path = regex#System('cygpath "' . path . '"')
    endif
    let path = substitute(path, '\n$', '', '')
    return path
  endif
  return a:path
endfunction " }}}

" vim:ft=vim:fdm=marker
