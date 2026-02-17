if exists("b:current_syntax")
  finish
endif

" Graph connectors
syntax match jjlogGraph /[│├╭╰─]/

" Working copy node (@)
syntax match jjlogAt /^\s*@\ze\s/

" Other commit nodes
syntax match jjlogNode /^\s*[○◉◆]\ze\s/

" Change ID: lowercase letters right after a node symbol
syntax match jjlogChangeId /\v([@○◉◆]\s+)\zs[a-z]+/

" Email address
syntax match jjlogEmail /[a-zA-Z0-9._%+-]\+@[a-zA-Z0-9.-]\+\.[a-zA-Z]\{2,}/

" Date and time
syntax match jjlogDate /\d\{4}-\d\{2}-\d\{2} \d\{2}:\d\{2}:\d\{2}/

" Commit ID: 8 hex chars (at end of line, after date/bookmarks)
syntax match jjlogCommitId /[0-9a-f]\{8}\s*$/

" Special markers
syntax match jjlogEmpty /(empty)/
syntax match jjlogNoDesc /(no description set)/
syntax match jjlogRoot /root()/
syntax match jjlogGitHead /git_head()/

" Tilde (elided history)
syntax match jjlogTilde /^\s*\~/

highlight default link jjlogGraph NonText
highlight default link jjlogAt Statement
highlight default link jjlogNode Type
highlight default link jjlogChangeId Identifier
highlight default link jjlogEmail String
highlight default link jjlogDate Number
highlight default link jjlogCommitId Comment
highlight default link jjlogEmpty WarningMsg
highlight default link jjlogNoDesc Comment
highlight default link jjlogRoot Special
highlight default link jjlogGitHead Label
highlight default link jjlogTilde NonText

let b:current_syntax = "jjlog"
