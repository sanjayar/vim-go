" Write a Go file to a temporary directory and append this directory to $GOPATH.
"
" The file will written to a:path, which is relative to the temporary directory,
" and this file will be loaded as the current buffer.
"
" The cursor will be placed on the character before any 0x1f byte.
"
" The full path to the created directory is returned, it is the caller's
" responsibility to clean that up!
fun! gotest#write_file(path, contents) abort
  let l:dir = go#util#tempdir("vim-go-test/testrun/")
  let $GOPATH .= ':' . l:dir
  let l:full_path = l:dir . '/src/' . a:path

  call mkdir(fnamemodify(l:full_path, ':h'), 'p')
  call writefile(a:contents, l:full_path)
  exe 'cd ' . l:dir . '/src'
  silent exe 'e ' . a:path

  " Set cursor.
  let l:lnum = 1
  for l:line in a:contents
    let l:m = match(l:line, '')
    if l:m > -1
      call setpos('.', [0, l:lnum, l:m, 0])
      call setline('.', substitute(getline('.'), '', '', ''))
      break
    endif

    let l:lnum += 1
  endfor

  return l:dir
endfun

" Load a fixture file from test-fixtures.
"
" The file will be copied to a new GOPATH-compliant temporary directory and
" loaded as the current buffer.
fun! gotest#load_fixture(path) abort
  let l:dir = go#util#tempdir("vim-go-test/testrun/")
  let $GOPATH .= ':' . l:dir
  let l:full_path = l:dir . '/src/' . a:path

  call mkdir(fnamemodify(l:full_path, ':h'), 'p')
  exe 'cd ' . l:dir . '/src'
  silent exe 'noautocmd e ' . a:path
  silent exe printf('read %s/test-fixtures/%s', g:vim_go_root, a:path)
  silent noautocmd w!

  return l:dir
endfun

" Diff the contents of the current buffer to a:want, which should be a list.
" If a:skipHeader is true we won't bother with the package and import
" declarations; so e.g.:
"
"     let l:diff = s:diff_buffer(1, ['_ = mail.Address{}'])
"
" will pass, whereas otherwise you'd have to:
"
"     let l:diff = s:diff_buffer(0, ['package main', 'import "net/mail", '_ = mail.Address{}'])
fun! gotest#assert_buffer(skipHeader, want) abort
  let l:buffer = go#util#GetLines()

  if a:skipHeader
    for l:lnum in range(0, len(l:buffer) - 1)
      " Bit rudimentary, but works reasonably well.
      if match(l:buffer[l:lnum], '^\v(func|var|const|import \(|\))') > -1
        let l:buffer = l:buffer[l:lnum:]
        break
      endif
    endfor
  endif

  " Using ' is often easier so we don't have to escape ".
  let l:want = map(a:want, 'substitute(v:val, "\\\\t", "\t", "")')

  let l:tmp = go#util#tempdir('assert_buffer')
  try
    call writefile(l:buffer, l:tmp . '/have')
    call writefile(l:want, l:tmp . '/want')
    call go#fmt#run('gofmt', l:tmp . '/have', l:tmp . '/have')
    call go#fmt#run('gofmt', l:tmp . '/want', l:tmp . '/want')
    let [l:out, l:err] = go#util#Exec(["diff", "-u", l:tmp . '/have', l:tmp . '/want'])
  finally
    call delete(l:tmp . '/have')
    call delete(l:tmp . '/want')
    call delete(l:tmp, 'd')
  endtry

  if l:err || l:out != ''
    let v:errors = extend(v:errors, split(l:out, "\n"))
  endif
endfun

" Diff the contents of the current buffer to the fixture file in a:path.
fun! gotest#assert_fixture(path) abort
  let l:want = readfile(printf('%s/test-fixtures/%s', g:vim_go_root, a:path))
  call gotest#assert_buffer(0, l:want)
endfun


" vim: sw=2 ts=2 et
