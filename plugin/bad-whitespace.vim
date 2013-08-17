" bad-whitespace.vim - Highlights whitespace at the end of lines
" Maintainer:   Bit Connor <bit@mutantlemon.com>
" Version:      0.3

if exists('loaded_bad_whitespace')
    finish
endif
let loaded_bad_whitespace = 1

if ! exists( "g:bad_whitespace_patch_filetypes" )
    let g:bad_whitespace_patch_filetypes = ['diff', 'git']
endif

if ! exists( "g:bad_whitespace_off_filetypes" )
    let g:bad_whitespace_off_filetypes = []
endif

if ! exists( "g:bad_whitespace_patch_column_width_fallback" )
    " If the column width could not be derived from the hunk header, use this
    " value as a fallback.
    let g:bad_whitespace_patch_column_width_fallback = 0
endif

if ! exists( "g:bad_whitespace_alternative_color_filetypes" )
    let g:bad_whitespace_alternative_color_filetypes = []
endif

if ! exists( "g:bad_whitespace_color_default" )
    highlight default BadWhitespaceDefaultState ctermbg=red guibg=red
    let g:bad_whitespace_color_default = 'BadWhitespaceDefaultState'
endif

if ! exists( "g:bad_whitespace_color_alt_default" )
    highlight default BadWhitespaceAltDefaultState ctermbg=gray guibg=gray
    let g:bad_whitespace_color_alt_default = 'BadWhitespaceAltDefaultState'
endif

if ! exists( "g:bad_whitespace_match_priority" )
    " The priority used for the bad-whitespace match in matchadd()
    let g:bad_whitespace_match_priority = -20
endif

" The IDs 1-3 are reserved and therefore never used by matchadd.
let s:InvalidMatchId = 1

execute 'highlight link BadWhitespace ' . g:bad_whitespace_color_default
execute 'highlight link BadWhitespaceAlternative '
            \ . g:bad_whitespace_color_alt_default
autocmd BufWinEnter,WinEnter,FileType * call <SID>EnableShowBadWhitespace()

function! s:IsAlternativeColorFiletype()
  let l:alt_filtypes = filter(
              \ copy(g:bad_whitespace_alternative_color_filetypes),
              \ 'v:val == &ft')
  if empty(l:alt_filtypes)
      return 0
  else
      return 1
  endif
endfunction

fun! s:DeleteBadWhitespaceMatch()
    " Delete the bad whitespace match in this window
    if exists("w:bad_whitespace_match_id")
                \ && w:bad_whitespace_match_id != s:InvalidMatchId
        call matchdelete(w:bad_whitespace_match_id)
        let w:bad_whitespace_match_id = s:InvalidMatchId
    endif
endfun

fun! s:SetBadWhitespaceMatch(highlight_group,  whitespace_pattern)
    " Set or update the bad whitespace match in this window
    call s:DeleteBadWhitespaceMatch()
    let w:bad_whitespace_match_id =  matchadd(a:highlight_group,
                \ a:whitespace_pattern, g:bad_whitespace_match_priority)
endfun

function! s:ShowBadWhitespace(force)
  if a:force
    let b:bad_whitespace_show = 1
  endif
  autocmd ColorScheme <buffer> execute 'highlight link BadWhitespace '
              \ . g:bad_whitespace_color_default
  autocmd ColorScheme <buffer>
              \ execute 'highlight link BadWhitespaceAlternative '
              \ . g:bad_whitespace_color_alt_default
  let l:whitespace_pattern_global = s:GetBadWhitespacePattern(0)
  let l:whitespace_pattern_editing = s:GetBadWhitespacePattern(1)
  if s:IsAlternativeColorFiletype()
      let l:active_highlight = 'BadWhitespaceAlternative'
  else
      let l:active_highlight = 'BadWhitespace'
  endif
  call s:SetBadWhitespaceMatch(l:active_highlight, l:whitespace_pattern_global)
  augroup BadWhitespace
    autocmd! * <buffer>
    execute 'autocmd InsertLeave <buffer> call <SID>SetBadWhitespaceMatch( "'
                \ . l:active_highlight . '", '''
                \ . l:whitespace_pattern_global . ''')'
    execute 'autocmd InsertEnter <buffer> call <SID>SetBadWhitespaceMatch( "'
                \ . l:active_highlight . '", '''
                \ . l:whitespace_pattern_editing . ''')'
  augroup END
endfunction

function! s:GetBadWhitespacePattern(want_editing_pattern)
  " Return the bad-whitespace pattern for the current buffer.  If
  " want_editing_pattern is nonzero return the pattern for insert mode.
  if exists('b:bad_whitespace_buffer_specific_patterns')
      let l:pattern_prefixes = b:bad_whitespace_buffer_specific_patterns
  else
      let l:pattern_prefixes = [
                  \ '\_s\+\%$\|\s\+$',
                  \ '\_s\+\%#\@<!\%$\|\s\+\%#\@<!$']
  endif
  if a:want_editing_pattern
      return l:pattern_prefixes[1]
  else
      return l:pattern_prefixes[0]
  endif
endfunction

function! s:GetPatternsForPatches()
  let l:save_cursor = getpos(".")
  if search('^@\+', 'we')
      let l:start_colum = col('.')
  else
      let l:start_colum = g:bad_whitespace_patch_column_width_fallback + 1
      if g:bad_whitespace_patch_column_width_fallback != 0
          echomsg "bad-whitespace: No @ char match. "
                      \ . "Will use fallback +/- column width "
                      \ . g:bad_whitespace_patch_column_width_fallback
      endif
  endif
  call setpos('.', l:save_cursor)
  let l:patch_pattern = '\%' . l:start_colum . 'c.\{-\}\zs\s\+\ze'
  return [l:patch_pattern . '$', l:patch_pattern . '\%#\@<!$']
endfunction

function! s:SetBufferSpecificPatterns()
  let l:patch_filtypes = filter(copy(g:bad_whitespace_patch_filetypes),
              \ 'v:val == &ft')
  if !empty(l:patch_filtypes)
    let b:bad_whitespace_buffer_specific_patterns = s:GetPatternsForPatches()
  endif
endfunction

function! s:TurnOffBadWhitespaceForConfiguredFiletypes()
  let l:off_filtypes = filter(copy(g:bad_whitespace_off_filetypes),
              \ 'v:val == &ft')
  if !empty(l:off_filtypes)
      call s:HideBadWhitespace(1)
  endif
endfun

function! s:HideBadWhitespace(force)
  if a:force
    let b:bad_whitespace_show = 0
  endif
  call s:DeleteBadWhitespaceMatch()
  augroup BadWhitespace
    autocmd! * <buffer>
  augroup END
endfunction

function! s:EnableShowBadWhitespace()
  call s:SetBufferSpecificPatterns()
  if !exists("b:bad_whitespace_show")
      let b:bad_whitespace_show = 1
  endif
  if &modifiable && b:bad_whitespace_show
    call <SID>ShowBadWhitespace(0)
  else
    call <SID>HideBadWhitespace(0)
  endif
  call s:TurnOffBadWhitespaceForConfiguredFiletypes()
endfunction

function! s:ToggleBadWhitespace()
  if !exists("b:bad_whitespace_show")
    let b:bad_whitespace_show = 0
    if &modifiable
      let b:bad_whitespace_show = 1
    endif
  endif
  if b:bad_whitespace_show
    call <SID>HideBadWhitespace(1)
  else
    call <SID>ShowBadWhitespace(1)
  endif
endfunction

function! s:EraseBadWhitespace(line1,line2)
  let l:save_cursor = getpos(".")
  silent! execute ':' . a:line1 . ',' . a:line2
              \ . 's/' . s:GetBadWhitespacePattern(0) . '//'
  call setpos('.', l:save_cursor)
endfunction

" Run :EraseBadWhitespace to remove end of line white space.
command! -range=% EraseBadWhitespace
            \ call <SID>EraseBadWhitespace(<line1>,<line2>)
command! ShowBadWhitespace call <SID>ShowBadWhitespace(1)
command! HideBadWhitespace call <SID>HideBadWhitespace(1)
command! ToggleBadWhitespace call <SID>ToggleBadWhitespace()
command! SetSearchPatternToBadWhitespace
            \ let @/ = <SID>GetBadWhitespacePattern(0)
