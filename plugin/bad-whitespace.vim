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

function! s:ShowBadWhitespace(force)
  if a:force
    let b:bad_whitespace_show = 1
  endif
  autocmd ColorScheme <buffer> execute 'highlight link BadWhitespace '
              \ . g:bad_whitespace_color_default
  autocmd ColorScheme <buffer>
              \ execute 'highlight link BadWhitespaceAlternative '
              \ . g:bad_whitespace_color_alt_default
  let l:whitespace_pattern_global = '/' . s:GetBadWhitespacePattern(0) . '/'
  let l:whitespace_pattern_editing = '/' . s:GetBadWhitespacePattern(1) . '/'
  if s:IsAlternativeColorFiletype()
      let l:active_colorscheme = 'BadWhitespaceAlternative'
      match none BadWhitespace
  else
      let l:active_colorscheme = 'BadWhitespace'
      match none BadWhitespaceAlternative
  endif
  execute 'match ' . l:active_colorscheme . ' ' . l:whitespace_pattern_global
  augroup BadWhitespace
    autocmd! * <buffer>
    execute 'autocmd InsertLeave <buffer> match ' . l:active_colorscheme
                \ . ' ' . l:whitespace_pattern_global
    execute 'autocmd InsertEnter <buffer> match ' . l:active_colorscheme
                \ . ' ' . l:whitespace_pattern_editing
  augroup END
endfunction

function! s:GetBadWhitespacePattern(want_editing_pattern)
  " Return the bad-whitespace pattern for the current buffer.  If
  " want_editing_pattern is nonzero return the pattern for insert mode.
  if exists('b:bad_whitespace_buffer_pattern_prefix')
      let l:pattern_prefix = b:bad_whitespace_buffer_pattern_prefix
  else
      let l:pattern_prefix = '\s\+'
  endif
  if a:want_editing_pattern
      return l:pattern_prefix . '\%#\@<!$'
  else
      return l:pattern_prefix . '$'
  endif
endfunction

function! s:GetPatternPrefixForPatches()
  let l:save_cursor = getpos(".")
  if search('^@\+', 'we')
      let l:start_colum = col('.')
  else
      let l:start_colum = g:bad_whitespace_patch_column_width_fallback + 1
      echomsg "bad-whitespace: could not find a sequence of @ characters. "
                  \ . "Will use fallback +/- column width "
                  \ . g:bad_whitespace_patch_column_width_fallback
  endif
  call setpos('.', l:save_cursor)
  return '\%' . l:start_colum . 'c.\{-\}\zs\s\+\ze'
endfunction

function! s:SetBufferSpecificPatternPrefix()
  let l:patch_filtypes = filter(copy(g:bad_whitespace_patch_filetypes),
              \ 'v:val == &ft')
  if !empty(l:patch_filtypes)
    let b:bad_whitespace_buffer_pattern_prefix = s:GetPatternPrefixForPatches()
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
  match none BadWhitespace
  augroup BadWhitespace
    autocmd! * <buffer>
  augroup END
endfunction

function! s:EnableShowBadWhitespace()
  call s:SetBufferSpecificPatternPrefix()
  if exists("b:bad_whitespace_show")
    return
  endif
  if &modifiable
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
