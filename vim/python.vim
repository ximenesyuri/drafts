syntax clear

" Delimiters
syn match pythonDelimiter /[\[\](),{}]/
syn match pythonColon /:/ containedin=ALLBUT,pythonString,pythonRawString,pythonComment,pythonBytes,pythonRawBytes,pythonFString,pythonRawFString display

syn match pythonFunctionCall '\%([^[:cntrl:]:[:space:][:punct:][:digit:]]\|_\)\%([^[:cntrl:][:punct:][:space:]]\|_\)*\ze\%(\s*(\)'

syn keyword pythonStatement     break continue del return pass yield global assert lambda with
syn keyword pythonStatement     raise nextgroup=pythonExClass skipwhite
syn keyword pythonStatement     class nextgroup=pythonClass skipwhite
syn keyword pythonClassVar      self cls mcs
syn keyword pythonRepeat        for while
syn keyword pythonConditional   if elif else
syn keyword pythonException     try except finally
syn keyword pythonInclude       import
syn keyword pythonImport        import
syn match pythonRaiseFromStatement      '\<from\>'
syn match pythonImport          '^\s*\zsfrom\>'

syn keyword pythonStatement   as nonlocal
syn match   pythonStatement   '\v\.@<!<await>'
syn match   pythonFunction    '\%([^[:cntrl:][:space:][:punct:][:digit:]]\|_\)\%([^[:cntrl:][:punct:][:space:]]\|_\)*' display contained
syn match   pythonClass       '\%([^[:cntrl:][:space:][:punct:][:digit:]]\|_\)\%([^[:cntrl:][:punct:][:space:]]\|_\)*' display contained
syn match   pythonStatement   '\<async\s\+with\>'
syn match   pythonStatement   '\<async\s\+for\>'
syn keyword pythonStatement def contained containedin=pythonFuncSignature nextgroup=pythonFunction skipwhite
syn match pythonStatement '\<async\s\+def\>' contained containedin=pythonFuncSignature nextgroup=pythonFunction skipwhite
syn cluster pythonExpression contains=pythonStatement,pythonRepeat,pythonConditional,pythonOperator,pythonNumber,pythonHexNumber,pythonOctNumber,pythonBinNumber,pythonFloat,pythonString,pythonFString,pythonRawString,pythonRawFString,pythonBytes,pythonBoolean,pythonNone,pythonSingleton,pythonBuiltinAttr,pythonBuiltinFunc,pythonBuiltinType,pythonClassVar,pythonFunctionCall,pythonDelimiter


"syn match pythonAttr '\%(\.\)\@<=\%([^[:cntrl:][:space:][:punct:][:digit:]]\|_\)\%([^[:cntrl:][:punct:][:space:]]\|_\)*\%(\s*(\)\@!' contained containedin=ALLBUT,pythonString,pythonRawString,pythonComment,pythonBytes,pythonRawBytes,pythonFString,pythonRawFString,pythonImport

" Types
syn region pythonDict
      \ matchgroup=pythonDelimiter
      \ start='{'
      \ end='}'
      \ contains=@pythonExpression,
      \          pythonFunctionCall,
      \          pythonString,pythonRawString,
      \          pythonBytes,pythonRawBytes,
      \          pythonFString,pythonRawFString,
      \          pythonComment,
      \

syn region pythonList
      \ matchgroup=pythonDelimiter
      \ start='\['
      \ end='\]'
      \ contains=@pythonExpression,
      \          pythonFunctionCall,
      \          pythonString,pythonRawString,
      \          pythonBytes,pythonRawBytes,
      \          pythonFString,pythonRawFString,
      \          pythonComment,
      \

syn region pythonTuple
      \ matchgroup=pythonDelimiter
      \ start='('
      \ end=')'
      \ contains=@pythonExpression,
      \          pythonFunctionCall,
      \          pythonString,pythonRawString,
      \          pythonBytes,pythonRawBytes,
      \          pythonFString,pythonRawFString,
      \          pythonComment,
      \

syn region pythonFuncSignature
     \ start=/^\s*\%(async\s*\)\?def\>/
     \ end=/:\s*$/
     \ keepend
     \ contains=@pythonExpression,pythonComment,pythonTypeHint,pythonDict,pythonDelimiter,pythonColon

syn region pythonTypeHint start=/:/ end=/,\|)\|(\|\[\|\]\|=/ keepend contained containedin=pythonFuncSignature contains=pythonDelimiter,pythonOperator

" Handle return type hints
syn region pythonReturnTypeHint
      \ matchgroup=pythonArrowOperator
      \ start=/->/
      \ end=/\ze:/
      \ containedin=pythonFuncSignature
      \ contains=pythonBuiltinType,pythonClassName

" Operators
syn keyword pythonOperator and in is not or
syn match pythonOperator '\V=\|+\|*\|@\|/\|%\|&\||\|^\|~\|<\|>\|!=\|:='
syn match pythonOperator /-\%(>\)\@!/

syn match pythonError           '[$?]\|\([-+@%&|^~]\)\1\{1,}\|\([=*/<>]\)\2\{2,}\|\([+@/%&|^~<>]\)\3\@![-+*@/%&|^~<>]\|\*\*[*@/%&|^<>]\|=[*@/%&|^<>]\|-[+*@/%&|^~<]\|[<!>]\+=\{2,}\|!\{2,}=\+' display
syn match   pythonDecorator    '^\s*\zs@' display nextgroup=pythonDottedName skipwhite
syn match   pythonDottedName '\%([^[:cntrl:][:space:][:punct:][:digit:]]\|_\)\%([^[:cntrl:][:punct:][:space:]]\|_\)*\%(\.\%([^[:cntrl:][:space:][:punct:][:digit:]]\|_\)\%([^[:cntrl:][:punct:][:space:]]\|_\)*\)*' display contained
syn match   pythonDot        '\.' display containedin=pythonDottedName

" Comments
syn match   pythonComment       '#.*$' display contains=pythonTodo,@Spell
syn match   pythonRun         '\%^#!.*$'
syn match   pythonCoding      '\%^.*\%(\n.*\)\?#.*coding[:=]\s*[0-9A-Za-z-_.]\+.*$'
syn keyword pythonTodo          TODO FIXME XXX contained

" Errors
syn match pythonError           '\<\d\+[^0-9[:space:]]\+\>' display
syn match pythonIndentError   '^\s*\%( \t\|\t \)\s*\S'me=e-1 display
syn match pythonSpaceError    '\s\+$' display

" Strings
syn region pythonBytes    start=+[bB]'+ skip=+\\\\\|\\'\|\\$+ excludenl end=+'+ end=+$+ keepend contains=pythonBytesError,pythonBytesContent,@Spell
syn region pythonBytes    start=+[bB]"+ skip=+\\\\\|\\"\|\\$+ excludenl end=+"+ end=+$+ keepend contains=pythonBytesError,pythonBytesContent,@Spell
syn region pythonBytes    start=+[bB]'''+ skip=+\\'+ end=+'''+ keepend contains=pythonBytesError,pythonBytesContent,pythonDocTest,pythonSpaceError,@Spell
syn region pythonBytes    start=+[bB]"""+ skip=+\\"+ end=+"""+ keepend contains=pythonBytesError,pythonBytesContent,pythonDocTest2,pythonSpaceError,@Spell
syn match pythonBytesError    '.\+' display contained
syn match pythonBytesContent  '[\u0000-\u00ff]\+' display contained contains=pythonBytesEscape,pythonBytesEscapeError
syn match pythonBytesEscape       +\\[abfnrtv'"\\]+ display contained
syn match pythonBytesEscape       '\\\o\o\=\o\=' display contained
syn match pythonBytesEscapeError  '\\\o\{,2}[89]' display contained
syn match pythonBytesEscape       '\\x\x\{2}' display contained
syn match pythonBytesEscapeError  '\\x\x\=\X' display contained
syn match pythonBytesEscape       '\\$'

syn match pythonUniEscape         '\\u\x\{4}' display contained
syn match pythonUniEscapeError    '\\u\x\{,3}\X' display contained
syn match pythonUniEscape         '\\U\x\{8}' display contained
syn match pythonUniEscapeError    '\\U\x\{,7}\X' display contained
syn match pythonUniEscape         '\\N{[A-Z ]\+}' display contained
syn match pythonUniEscapeError    '\\N{[^A-Z ]\+}' display contained

" Python 3 strings
syn region pythonString   start=+'+ skip=+\\\\\|\\'\|\\$+ excludenl end=+'+ end=+$+ keepend contains=pythonBytesEscape,pythonBytesEscapeError,pythonUniEscape,pythonUniEscapeError,@Spell
syn region pythonString   start=+"+ skip=+\\\\\|\\"\|\\$+ excludenl end=+"+ end=+$+ keepend contains=pythonBytesEscape,pythonBytesEscapeError,pythonUniEscape,pythonUniEscapeError,@Spell
syn region pythonString   start=+'''+ skip=+\\'+ end=+'''+ keepend contains=pythonBytesEscape,pythonBytesEscapeError,pythonUniEscape,pythonUniEscapeError,pythonDocTest,pythonSpaceError,@Spell
syn region pythonString   start=+"""+ skip=+\\"+ end=+"""+ keepend contains=pythonBytesEscape,pythonBytesEscapeError,pythonUniEscape,pythonUniEscapeError,pythonDocTest2,pythonSpaceError,@Spell

" F-strings with prefix highlighting
syn region pythonFString matchgroup=pythonStringPrefix start=+[fF]\z(['"]\)+ skip=+\\\\\|\\'\|\\$+ excludenl end=+'+ end=+$+ keepend contains=pythonBytesEscape,pythonBytesEscapeError,pythonUniEscape,pythonUniEscapeError,@Spell
syn region pythonFString matchgroup=pythonStringPrefix start=+[fF]\z(["]\)+ skip=+\\\\\|\\"\|\\$+ excludenl end=+"+ end=+$+ keepend contains=pythonBytesEscape,pythonBytesEscapeError,pythonUniEscape,pythonUniEscapeError,@Spell
syn region pythonFString matchgroup=pythonStringPrefix start=+[fF]\z('''\)+ skip=+\\'+ end=+'''+ keepend contains=pythonBytesEscape,pythonBytesEscapeError,pythonUniEscape,pythonUniEscapeError,pythonDocTest,pythonSpaceError,@Spell
syn region pythonFString matchgroup=pythonStringPrefix start=+[fF]\z("""\)+ skip=+\\"+ end=+"""+ keepend contains=pythonBytesEscape,pythonBytesEscapeError,pythonUniEscape,pythonUniEscapeError,pythonDocTest2,pythonSpaceError,@Spell

" Raw strings with prefix highlighting
syn region pythonRawString matchgroup=pythonStringPrefix start=+[rR]\z(['"]\)+ skip=+\\\\\|\\'\|\\$+ excludenl end=+'+ end=+$+ keepend contains=pythonRawEscape,@Spell
syn region pythonRawString matchgroup=pythonStringPrefix start=+[rR]\z(["]\)+ skip=+\\\\\|\\"\|\\$+ excludenl end=+"+ end=+$+ keepend contains=pythonRawEscape,@Spell
syn region pythonRawString matchgroup=pythonStringPrefix start=+[rR]\z('''\)+ skip=+\\'+ end=+'''+ keepend contains=pythonDocTest,pythonSpaceError,@Spell
syn region pythonRawString matchgroup=pythonStringPrefix start=+[rR]\z("""\)+ skip=+\\"+ end=+"""+ keepend contains=pythonDocTest2,pythonSpaceError,@Spell

" Raw F-strings with prefix highlighting
syn region pythonRawFString matchgroup=pythonStringPrefix start=+\%([fF][rR]\|[rR][fF]\)\z(['"]\)+ skip=+\\\\\|\\'\|\\$+ excludenl end=+'+ end=+$+ keepend contains=pythonRawEscape,@Spell
syn region pythonRawFString matchgroup=pythonStringPrefix start=+\%([fF][rR]\|[rR][fF]\)\z(["]\)+ skip=+\\\\\|\\"\|\\$+ excludenl end=+"+ end=+$+ keepend contains=pythonRawEscape,@Spell
syn region pythonRawFString matchgroup=pythonStringPrefix start=+\%([fF][rR]\|[rR][fF]\)\z('''\)+ skip=+\\'+ end=+'''+ keepend contains=pythonDocTest,pythonSpaceError,@Spell
syn region pythonRawFString matchgroup=pythonStringPrefix start=+\%([fF][rR]\|[rR][fF]\)\z("""\)+ skip=+\\"+ end=+"""+ keepend contains=pythonDocTest,pythonSpaceError,@Spell

" Bytes with prefix highlighting
syn region pythonBytes matchgroup=pythonStringPrefix start=+[bB]\z(['"]\)+ skip=+\\\\\|\\'\|\\$+ excludenl end=+'+ end=+$+ keepend contains=pythonBytesError,pythonBytesContent,@Spell
syn region pythonBytes matchgroup=pythonStringPrefix start=+[bB]\z(["]\)+ skip=+\\\\\|\\"\|\\$+ excludenl end=+"+ end=+$+ keepend contains=pythonBytesError,pythonBytesContent,@Spell
syn region pythonBytes matchgroup=pythonStringPrefix start=+[bB]\z('''\)+ skip=+\\'+ end=+'''+ keepend contains=pythonBytesError,pythonBytesContent,pythonDocTest,pythonSpaceError,@Spell
syn region pythonBytes matchgroup=pythonStringPrefix start=+[bB]\z("""\)+ skip=+\\"+ end=+"""+ keepend contains=pythonBytesError,pythonBytesContent,pythonDocTest2,pythonSpaceError,@Spell

" Raw bytes with prefix highlighting
syn region pythonRawBytes matchgroup=pythonStringPrefix start=+\%([bB][rR]\|[rR][bB]\)\z(['"]\)+ skip=+\\\\\|\\'\|\\$+ excludenl end=+'+ end=+$+ keepend contains=pythonRawEscape,@Spell
syn region pythonRawBytes matchgroup=pythonStringPrefix start=+\%([bB][rR]\|[rR][bB]\)\z(["]\)+ skip=+\\\\\|\\"\|\\$+ excludenl end=+"+ end=+$+ keepend contains=pythonRawEscape,@Spell
syn region pythonRawBytes matchgroup=pythonStringPrefix start=+\%([bB][rR]\|[rR][bB]\)\z('''\)+ skip=+\\'+ end=+'''+ keepend contains=pythonDocTest,pythonSpaceError,@Spell
syn region pythonRawBytes matchgroup=pythonStringPrefix start=+\%([bB][rR]\|[rR][bB]\)\z("""\)+ skip=+\\"+ end=+"""+ keepend contains=pythonDocTest2,pythonSpaceError,@Spell

syn match pythonRawEscape +\\['"]+ display contained
syn match pythonStrFormatting '%\%(([^)]\+)\)\=[-#0 +]*\d*\%(\.\d\+\)\=[hlL]\=[diouxXeEfFgGcrs%]' contained containedin=pythonString,pythonRawString,pythonBytesContent
syn match pythonStrFormatting '%[-#0 +]*\%(\*\|\d\+\)\=\%(\.\%(\*\|\d\+\)\)\=[hlL]\=[diouxXeEfFgGcrs%]' contained containedin=pythonString,pythonRawString,pythonBytesContent

" str.format syntax

syn match pythonStrFormat "{\%(\%([^[:cntrl:][:space:][:punct:][:digit:]]\|_\)\%([^[:cntrl:][:punct:][:space:]]\|_\)*\|\d\+\)\=\%(\.\%([^[:cntrl:][:space:][:punct:][:digit:]]\|_\)\%([^[:cntrl:][:punct:][:space:]]\|_\)*\|\[\%(\d\+\|[^!:\}]\+\)\]\)*\%(![rsa]\)\=\%(:\%({\%(\%([^[:cntrl:][:space:][:punct:][:digit:]]\|_\)\%([^[:cntrl:][:punct:][:space:]]\|_\)*\|\d\+\)}\|\%([^}]\=[<>=^]\)\=[ +-]\=#\=0\=\d*,\=\%(\.\d\+\)\=[bcdeEfFgGnosxX%]\=\)\=\)\=}" contained containedin=pythonString,pythonRawString
syn region pythonStrInterpRegion matchgroup=pythonStrFormat start="{" end="\%(![rsa]\)\=\%(:\%({\%(\%([^[:cntrl:][:space:][:punct:][:digit:]]\|_\)\%([^[:cntrl:][:punct:][:space:]]\|_\)*\|\d\+\)}\|\%([^}]\=[<>=^]\)\=[ +-]\=#\=0\=\d*,\=\%(\.\d\+\)\=[bcdeEfFgGnosxX%]\=\)\=\)\=}" extend contained containedin=pythonFString,pythonRawFString contains=pythonStrInterpRegion,@pythonExpression
syn match pythonStrFormat "{{\|}}" contained containedin=pythonFString,pythonRawFString

" string.Template format
syn match pythonStrTemplate '\$\$' contained containedin=pythonString,pythonRawString
syn match pythonStrTemplate '\${[a-zA-Z_][a-zA-Z0-9_]*}' contained containedin=pythonString,pythonRawString
syn match pythonStrTemplate '\$[a-zA-Z_][a-zA-Z0-9_]*' contained containedin=pythonString,pythonRawString

" Numbers (ints, longs, floats, complex)
syn match   pythonOctError    '\<0[oO]\=\o*\D\+\d*\>' display
syn match   pythonHexError    '\<0[xX]\x*[g-zG-Z]\x*\>' display
syn match   pythonBinError    '\<0[bB][01]*\D\+\d*\>' display

syn match   pythonHexNumber   '\<0[xX][_0-9a-fA-F]*\x\>' display
syn match   pythonOctNumber   '\<0[oO][_0-7]*\o\>' display
syn match   pythonBinNumber   '\<0[bB][_01]*[01]\>' display

syn match   pythonNumberError '\<\d[_0-9]*\D\>' display
syn match   pythonNumberError '\<0[_0-9]\+\>' display
syn match   pythonNumberError '\<0_x\S*\>' display
syn match   pythonNumberError '\<0[bBxXoO][_0-9a-fA-F]*_\>' display
syn match   pythonNumberError '\<\d[_0-9]*_\>' display
syn match   pythonNumber      '\<\d\>' display
syn match   pythonNumber      '\<[1-9][_0-9]*\d\>' display
syn match   pythonNumber      '\<\d[jJ]\>' display
syn match   pythonNumber      '\<[1-9][_0-9]*\d[jJ]\>' display

syn match   pythonOctError    '\<0[oO]\=\o*[8-9]\d*\>' display
syn match   pythonBinError    '\<0[bB][01]*[2-9]\d*\>' display

syn match   pythonFloat       '\.\d\%([_0-9]*\d\)\=\%([eE][+-]\=\d\%([_0-9]*\d\)\=\)\=[jJ]\=\>' display
syn match   pythonFloat       '\<\d\%([_0-9]*\d\)\=[eE][+-]\=\d\%([_0-9]*\d\)\=[jJ]\=\>' display
syn match   pythonFloat       '\<\d\%([_0-9]*\d\)\=\.\d\=\%([_0-9]*\d\)\=\%([eE][+-]\=\d\%([_0-9]*\d\)\=\)\=[jJ]\=' display

" Builtin objects
syn keyword pythonNone        None
syn keyword pythonBoolean     True False
syn keyword pythonSingleton   Ellipsis NotImplemented
syn keyword pythonBuiltinAttr  __debug__ __doc__ __file__ __name__ __package__
syn keyword pythonBuiltinAttr  __loader__ __spec__ __path__ __cached__
syn region pythonDunder start=/__/ end=/__/ contained containedin=pythonDottedName, pythonString,pythonRawString,pythonComment,pythonBytes,pythonRawBytes,pythonFString,pythonRawFString


" Builtin exceptions and warnings
let s:exs_re = 'BaseException|Exception|ArithmeticError|LookupError|EnvironmentError|AssertionError|AttributeError|BufferError|EOFError|FloatingPointError|GeneratorExit|IOError|ImportError|IndexError|KeyError|KeyboardInterrupt|MemoryError|NameError|NotImplementedError|OSError|OverflowError|ReferenceError|RuntimeError|StopIteration|SyntaxError|IndentationError|TabError|SystemError|SystemExit|TypeError|UnboundLocalError|UnicodeError|UnicodeEncodeError|UnicodeDecodeError|UnicodeTranslateError|ValueError|VMSError|WindowsError|ZeroDivisionError|Warning|UserWarning|BytesWarning|DeprecationWarning|PendingDeprecationWarning|SyntaxWarning|RuntimeWarning|FutureWarning|ImportWarning|UnicodeWarning'

let s:exs_re .= '|BlockingIOError|ChildProcessError|ConnectionError|BrokenPipeError|ConnectionAbortedError|ConnectionRefusedError|ConnectionResetError|FileExistsError|FileNotFoundError|InterruptedError|IsADirectoryError|NotADirectoryError|PermissionError|ProcessLookupError|TimeoutError|StopAsyncIteration|ResourceWarning'

execute 'syn match pythonExClass ''\v\.@<!\zs<%(' . s:exs_re . ')>'''
unlet s:exs_re

hi link pythonStatement        Statement
hi link pythonRaiseFromStatement   Statement
hi link pythonImport           Include
hi link pythonFunction         Delimiter
hi link pythonFunctionCall     Function

hi link pythonConditional      Conditional
hi link pythonRepeat           Repeat
hi link pythonException        Exception
hi link pythonOperator         Operator
hi link pythonDelimiter        Delimiter
hi link pythonColon            Delimiter
hi link pythonArrowOperator    Operator

hi link pythonDecorator        Define
hi link pythonDottedName       Function

hi link pythonComment          Comment
hi link pythonCoding           Special
hi link pythonRun              Special
hi link pythonTodo             Todo

hi link pythonError            Error
hi link pythonIndentError      Error
hi link pythonSpaceError       Error

hi link pythonString           String
hi link pythonRawString        String
hi link pythonRawEscape        Constant
hi link pythonBytesEscape      Constant

hi link pythonUniEscape        Constant
hi link pythonUniEscapeError   Error

hi link pythonStrFormatting    Special
hi link pythonStrFormat        Special
hi link pythonStrTemplate      Special

hi link pythonNumber           Number
hi link pythonHexNumber        Number
hi link pythonOctNumber        Number
hi link pythonBinNumber        Number
hi link pythonFloat            Float
hi link pythonNumberError      Error
hi link pythonOctError         Error
hi link pythonHexError         Error
hi link pythonBinError         Error

hi link pythonBoolean          Boolean
hi link pythonNone             Constant
hi link pythonSingleton        Constant
hi link pythonBuiltinAttr      Constant
hi link pythonDunder           Constant

hi link pythonExClass          Structure
hi link pythonClass            Structure
hi link pythonClassVar         Identifier

hi link pythonTypeHint     Type
hi link pythonReturnTypeHint Type
hi link pythonDot Delimiter

"hi link pythonAttr Identifier

hi link pythonStringPrefix Constant

let b:current_syntax = 'python'

