" Vim indent file
" Language:	PHP
" Author:	John Wellesz <John.wellesz (AT) teaser (DOT) fr>
" URL:		http://www.2072productions.com/vim/indent/php.vim
" Last Change:	2004 December 27th
" Version: 1.07
"
" Changes: 1.07		- Added support for "Here document" tags:
"					   - HereDoc end tags are indented properly.
"					   - HereDoc content remains unchanged.
"					- All the code that is outside PHP delimiters remains
"					  unchanged.
"					- New feature: The content of <script.*> html tags is considered as PHP
"					  and indented according to the surrounding PHP code.
"					- "else if" are detected as "elseif".
"					- Multiline /**/ are indented when the user types it but
"					  remain unchanged when indenting from their beginning.
"					- Fixed indenting of // and # comments.
"					- php_sync_method option is set to 0 (fromstart).
"					  This is required for complex PHP scripts else the indent
"					  may fail.
"					- Files with non PHP code at the beginning could alter the indent
"					  of the following PHP code.
"					- Other minor improvements and corrections.
"
"
" Changes: 1.06:    - Switch block were no longer indented correctly...
"					- Added an option to use a default indenting instead of 0.
"					  (whereas I still can't find any good reason to use it!)
"					- A problem with ^\s*);\= lines where ending a non '{}'
"					  structure.
"					- Changed script local variable to be buffer local
"					  variable instead.
"
" Changes: 1.05:    - Lines containing "<?php ?>" and "?> <?php"
"					  (start and end tag on the same line) are no
"					  longer indented at col 1 but as normal code.
"
"
" Changes: 1.04:	- Strings containing "//" could break the indenting
"					  algorithm.
"					- When a '{}' block was at col 1, the second line of the
"					  block was not indented at all (because of a stupid
"					  optimization coupled with a bug).
"
" Changes: 1.03:	- Some indenting problems corrected: end of non '{}'
"					  structures was not detected in some cases. The part of
"					  code concerned have been re-written
"					- PHP start tags were not indented at col 1
"					- Wrong comment in the code have been corrected
"
" Changes: 1.02:	- The bug I was talking about in version 1.01 (right below) has
"					  been corrected :)
"					- Also corrected another bug that could occur in
"					  some special cases.
"					- I removed the debug mode left in 1.01 that could
"					  cause some Vim messages at loading if other script were
"					  bugged.
"
" Changes: 1.01:	- Some little bug corrections reguarding automatic optimized
"					  mode that missed some tests and could break the indenting.
"
"					- There is also a problem with complex non bracked structures, when several
"					  else are following each other, the algorithm do not indent the way it
"					  should.
"					  That will be corrected in the next version.
" 
" Changes: improvements with regard to the original version (0.5) by Miles Lott (whose this script was inspired):
"			   - Commented part of code or non PHP code no longer break the
"				 indent algorithm, the content of those parts are indented
"				 separatly
"			   - corrected a strange thing (a part of code was duplicated) ->
"			   the last version couldn't work.
"		       - Folds can be used without problem
"		       - multilevel non bracked structures are indented (like
"		       in C)
"		         Exemple:
"					if (!isset($History_lst_sel)) 
"						if (!isset($blabla)) 
"							if (!isset($bloum)) {
"								$History_lst_sel=0;
"							} else
"							    $foo="truc";
"						else $bla= "foo";
"					$command_hist = TRUE;
"
"			   - "array( 'blabla'," lines no longer break the indent of the
"			     following lines
"			   - the options php_noindent_switch and php_indent_shortopentags have been removed
"			     (couldn't find any reason why one would want to use them)
"			   - PHP open and close tags are always set to col 1 as for the
"			   immediate following php code
"			   
"  If you find a bug, please e-mail me at John.wellesz (AT) teaser (DOT) fr
"  with an example of code that break the algorithm.
"
"
"	Thanks a lot for using this script.
"

" NOTE: This script must be used with PHP syntax ON and with the php syntax
" script by Lutz Eymers (http://www.isp.de/data/php.vim ) . Else it won't be able to
" work correctly.
"
"	This script set the option php_sync_method of PHP syntax script to 0
"	(fromstart indenting method) in order to have an accurate syntax.
"
"	In the case you have syntax errors in your script such as end of HereDoc
"	tags not at col 1 you'll have to indent your file 2 times (This script 
"	will automatically put HereDoc end tags at col 1).
" 

" Options: PHP_default_indenting = # of sw (default is 0).

" This script uses the syntax to test matching {}, comments, <??> validity
" and to know if the line it is ask to indent is php code or not...
" Unfortunately for complex files the search syntax method isn't accurate so
" we must use the fromstart sync method.
let php_sync_method = 0

if exists("PHP_default_indenting")
	let b:PHP_default_indenting = PHP_default_indenting * &sw
else
	let b:PHP_default_indenting = 0
endif
" Only load this indent file when no other was loaded. But reset those state
" variables if needed

let b:PHP_lastindented = 0
let b:PHP_indentbeforelast = 0
let b:PHP_indentinghuge = 0
let b:PHP_CurrentIndentLevel = b:PHP_default_indenting
let b:PHP_LastIndentedWasComment = 0
" PHP code detect variables
let b:InPHPcode = 0
let b:InPHPcode_checked = 0
let b:InPHPcode_and_script = 0
let b:InPHPcode_tofind = ""
let b:PHP_oldchangetick = b:changedtick

if exists("b:did_indent")
	finish
endif

let b:did_indent = 1
setlocal nosmartindent

setlocal nolisp
setlocal indentexpr=GetPhpIndent()
"setlocal indentkeys+=0=,0),=EO
setlocal indentkeys=0{,0},0),:,!^F,o,O,e,*<Return>,=?>,=<?

" Only define the function once.
if exists("*GetPhpIndent")
	finish
endif

let s:endline= '\s*\%(//.*\|#.*\|/\*.*\*/\s*\)\=$'
let s:PHP_startindenttag = '<?\%(.*?>\)\@!\|<script[^>]*>\%(.*<\/script>\)\@!'
" setlocal debug=msg


function! GetLastRealCodeLNum(startline) " {{{
	"Inspired from the function SkipJavaBlanksAndComments by Toby Allsopp for indent/java.vim 
	let lnum = a:startline
	let old_lnum = lnum

	while lnum > 1
		let lnum = prevnonblank(lnum)
		let lastline = getline(lnum)

		" if we are inside an html <script> we must skip ?> tags to indent
		" everything as php
		if b:InPHPcode_and_script && lastline =~ '?>\s*$'
			let lnum = lnum - 1


		elseif lastline =~ '^\s*\%(//\|#\|/\*.*\*/\s*$\)' " if line is under comment
			let lnum = lnum - 1
		elseif lastline =~ '\*/\s*$' " skip multiline comments
			call cursor(lnum, 1)
			call search('\*/\zs', 'W')
			let lnum = searchpair('/\*\zs', '', '\*/\zs', 'bWr', '') " find the most outside /*

			let lastline = getline(lnum)
			if lastline =~ '^\s*/\*' " if line contains nothing but comment
				let lnum = lnum - 1 " do the job again on the line before (a comment can hide another...)
			else
				break
			endif

			
		elseif lastline =~? '\%(//\s*\|?>.*\)\@<!<?\%(php\)\=\s*$\|^\s*<script\>' " skip non php code
		"	call cursor(lnum, 1)
		"	call search('<?\zs', 'W')
		"	let lnum = searchpair('?>\zs', '', '<?\zs', 'bW', 'getline(".") =~ "<?.*?>"') " find the most outside /*

		"	let lastline = getline(lnum)
			while lastline !~ '\(<?.*\)\@<!?>' && lnum > 1
				let lnum = lnum - 1
				let lastline = getline(lnum)
			endwhile
			if lastline =~ '^\s*?>' " if line contains nothing but end tag 
				let lnum = lnum - 1
			else
				break " else there is something important before the ?>
			endif


			" Manage "here document" tags
		elseif lastline =~? '^\a\w*;$' && lastline !~? s:notPhpHereDoc " match the end of a heredoc
			let tofind=substitute( lastline, '\([^;]\+\);', '<<<\1$', '')
			while getline(lnum) !~? tofind && lnum > 1
				let lnum = lnum - 1
			endwhile
		else
			break " if none of these were true then we are done
		endif
	endwhile

	if lnum==1 && getline(lnum)!~ '<?'
		let lnum=0
	endif
	return lnum
endfunction
" }}}

function! Skippmatch()  " {{{
   	" the slowest instruction of this script, remove it and the script is 3
	" times faster but you may have troubles with '{' inside comments or strings
	" that will break the indent algorithm...
	let synname = synIDattr(synID(line("."), col("."), 0), "name")
	" echo synname . line(".")
	if synname == "phpParent" || synname == "javaScriptBraces"
	"if synname =~? "string" || synname =~? "phpComment" || synname =~? "phpHereDoc"
		return 0
		"return 1
	else
		return 1
		"return 0
	endif
endfun
" }}}

function! FindOpenBracket(lnum) " {{{
	call cursor(a:lnum, 1) " set the cursor to the start of the lnum line
	return searchpair('{', '', '}', 'bW', 'Skippmatch()')
endfun
" }}}

function! FindTheIfOfAnElse (lnum, StopAfterFirstPrevElse) " {{{
" A very clever recoursive function created by me (John Wellesz) that find the "if" corresponding to an
" "else". This function can easily be adapted for other languages :)
	
	if getline(a:lnum) =~# '^\s*}\s*else\%(if\)\=\>'
		let beforeelse = a:lnum " we do this so we can find the opened bracket to speed up the process
	else
		let beforeelse = GetLastRealCodeLNum(a:lnum - 1)
	endif

	if !s:level
		let s:iftoskip = 0
	endif

	" If we found another "else" then it means we need to skip the next "if"
	" we'll found. (since version 1.02)
	if getline(beforeelse) =~# '^\s*\%(}\s*\)\=else\%(\s*if\)\@!\>'
		let s:iftoskip = s:iftoskip + 1
	endif
	
	" A closing bracket? let skip the whole block to save some recursive calls
	if getline(beforeelse) =~ '^\s*}' " .s:endline
		let beforeelse = FindOpenBracket(beforeelse)

		" Put us on the block starter
		if getline(beforeelse) =~ '^\s*{'
			let beforeelse = GetLastRealCodeLNum(beforeelse - 1)
		endif
	endif


	if !s:iftoskip && a:StopAfterFirstPrevElse && getline(beforeelse) =~# '^\s*\%([}]\s*\)\=else\%(if\)\=\>'
		return beforeelse
	endif
	" if there was an else, then there is a if...
	if getline(beforeelse) !~# '^\s*if\>' && beforeelse>1 || s:iftoskip && beforeelse>1
		
		if  s:iftoskip && getline(beforeelse) =~# '^\s*if\>'
			let s:iftoskip = s:iftoskip - 1
		endif

		let s:level =  s:level + 1
		let beforeelse = FindTheIfOfAnElse(beforeelse, a:StopAfterFirstPrevElse)
	endif

	return beforeelse

endfunction
" }}}

function! IslinePHP (lnum, tofind) " {{{
	" This function asks to the syntax if the pattern 'tofind' on the line
	" number 'lnum' is PHP code (very slow...).
	let cline = getline(a:lnum)

	if a:tofind==""
		let tofind = '\%(^\s*\)\@<=\S'
	else
		let tofind = a:tofind
	endif

	let tofind = tofind . '\c' " ignorecase

	let coltotest = match (cline, tofind) + 1 "find the first non blank char in the current line
	
	let synname = synIDattr(synID(a:lnum, coltotest, 0), "name") " ask to syntax what is its name

	if matchstr(synname, '^...') == "php" || synname=="Delimiter"
		return synname
	else
		return ""
	endif
endfunction
" }}}

let s:notPhpHereDoc = '\%(break\|return\|continue\|exit\);'
let s:blockstart = '\%(\%(\%(}\s*\)\=else\%(\s\+\)\=\)\=if\>\|while\>\|for\%(each\)\=\>\|declare\|||\|&&\>\)'

function! GetPhpIndent()
	"##############################################
	"########### MAIN INDENT FUNCTION #############
	"##############################################

	" This detect if the user is currently typing text between each call
	let UserIsEditing=0
	if 	b:PHP_oldchangetick != b:changedtick
		let b:PHP_oldchangetick = b:changedtick
		let UserIsEditing=1
	endif


	if b:PHP_default_indenting
		let b:PHP_default_indenting = g:PHP_default_indenting * &sw
	endif

	let cline = getline(v:lnum) " current line

	" Let's detect if we are indenting just one line or more than 3 lines
	" in the last case we can slightly optimize our algorithm
	if !b:PHP_indentinghuge && b:PHP_lastindented > b:PHP_indentbeforelast 
		if b:PHP_indentbeforelast
			let b:PHP_indentinghuge = 1
			echom 'Large indenting detected, speed optimizations engaged'
		endif
		let b:PHP_indentbeforelast = b:PHP_lastindented
	endif

	" If the line we are indenting isn't directly under the previous non-blank
	" line of the file then deactivate the optimization procedures and reset
	" status variable (we restart for scratch)
	if b:InPHPcode_checked && prevnonblank(v:lnum - 1) != b:PHP_lastindented
		if b:PHP_indentinghuge
			echom 'Large indenting deactivated'
			let b:PHP_indentinghuge = 0
			let b:PHP_CurrentIndentLevel = b:PHP_default_indenting
		endif
		let b:PHP_lastindented = v:lnum
		let b:PHP_LastIndentedWasComment=0
		let b:PHP_indentbeforelast = 0
		
		let UserIsEditing=0 " user did changed

		let b:InPHPcode = 0
		let b:InPHPcode_checked = 0
		let b:InPHPcode_and_script = 0
		let b:InPHPcode_tofind = ""

	elseif v:lnum > b:PHP_lastindented " we are indenting line in > order (we can rely on the line before)
		let real_PHP_lastindented = b:PHP_lastindented
		let b:PHP_lastindented = v:lnum
	endif

	" We must detect if we are in PHPCODE or not, but one time only, then
	" we will detect php end and start tags, comments /**/ and HereDoc
	" tags

	if !b:InPHPcode_checked " {{{ One time check
		let b:InPHPcode_checked = 1

		let synname = IslinePHP (prevnonblank(v:lnum), "") " the line could be blank (if the user presses 'return')

		if synname!=""
			if synname != "phpHereDoc"
				let b:InPHPcode = 1
				let b:InPHPcode_tofind = ""
			else
				let b:InPHPcode = 0

				let lnum = v:lnum - 1
				while getline(lnum) !~? '<<<\a\w*$' && lnum >1
					let lnum = lnum - 1
				endwhile

				let b:InPHPcode_tofind = substitute( getline(lnum), '^.*<<<\(\a\w*\)\c', '^\\s*\1;$', '')
			endif
		else
			let b:InPHPcode = 0
			" Then we have to find a php start tag...
			let b:InPHPcode_tofind = '<?\%(.*?>\)\@!\|<script.*>'
		endif
	endif "!b:InPHPcode_checked }}}

	" Now we know where we are so we can verify the line right above the
	" current one to see if we have to stop or restart php indenting
	
	" Test if we are indenting PHP code {{{
	" Find an executable php code line above the current line.
	let lnum = prevnonblank(v:lnum - 1)
	let last_line = getline(lnum)

	" If we aren't in php code, then there is something we have to find
	if b:InPHPcode_tofind!=""
		if cline =~? b:InPHPcode_tofind
			let	b:InPHPcode = 1
			let b:InPHPcode_tofind = ""
			if cline =~ '\*/'
				return -1 " we don't want to indent closing '*/'
			elseif cline =~? '<script\>' " a more accurate test is useless since there isn't any other possibility
				let b:InPHPcode_and_script = 1
			endif
		endif
	endif

	" ### If we are in PHP code, we test the line before to see if we have to stop indenting

	if b:InPHPcode

		" Was last line containing a PHP end tag ?
		if !b:InPHPcode_and_script && last_line =~ '\%(<?.*\)\@<!?>\%(.*<?\)\@!' && IslinePHP(lnum, '?>')=="Delimiter"
			if cline !~? s:PHP_startindenttag
				let b:InPHPcode = 0
				let b:InPHPcode_tofind = s:PHP_startindenttag
			elseif cline =~? '<script\>'
				let b:InPHPcode_and_script = 1
			endif

			" Was last line the start of a HereDoc ?
		elseif last_line =~? '<<<\a\w*$' 
					" \&& IslinePHP(lnum, '\a\w*$')=="Delimiter"
			let b:InPHPcode = 0
			let b:InPHPcode_tofind = substitute( last_line, '^.*<<<\(\a\w*\)\c', '^\\s*\1;$', '')

			" Skip /* \n+ */ comments execept when the user is currently
			" writting them
		elseif !UserIsEditing && cline =~ '^\s*/\*\%(.*\*/\)\@!'
					" \ && IslinePHP(v:lnum, '/\*')=="phpComment"
			let b:InPHPcode = 0
			let b:InPHPcode_tofind = '\*/'

			" is current line the end of a HTML script ? (we indent script the
			" same as php code)
		elseif cline =~? '^\s*</script>'
			let b:InPHPcode = 0
			" let b:InPHPcode_and_script = 0
			let b:InPHPcode_tofind = s:PHP_startindenttag
		endif
	endif " }}}

	" Non PHP code is let as it is
	if !b:InPHPcode && !b:InPHPcode_and_script
		return -1
	elseif !b:InPHPcode
		let b:InPHPcode_and_script = 0
	endif

	" Align correctly multi // or # lines

	" Indent successive // or # comment the same way the first is {{{
	if cline =~ '^\s*\%(//\|#\|/\*.*\*/\s*$\)'
		if b:PHP_LastIndentedWasComment == 1
			return indent(real_PHP_lastindented) " line replaced in 1.02
		endif
		let b:PHP_LastIndentedWasComment = 1
	else
		let b:PHP_LastIndentedWasComment = 0
	endif
	" }}}

	" Some tags are always indented to col 1

	" Things always indented at col 1 (PHP delimiter: <?, ?>, Heredoc end) {{{
	" PHP start tags are always at col 1, useless to indent unless the end tag
	" is on the same line
	if cline =~# '^\s*<?' && cline !~ '?>' " Added the ^\s* part in version 1.03
		return 0
	endif

	" PHP end tags are always at col 1, useless to indent unless if it's
	" followed by a start tag on the same line
	if  cline =~ '^\s*?>' && cline !~# '<?'  
		return 0
	endif

	" put HereDoc end tags at start of lines
	if cline =~? '^\s*\a\w*;$' && cline !~? s:notPhpHereDoc
		return 0
	endif
	" }}}

	let s:level = 0

	" Find an executable php code line above the current line.
	let lnum = GetLastRealCodeLNum(v:lnum - 1)
	let last_line = getline(lnum)    " last line
	let ind = indent(lnum) " by default
	let endline= s:endline

	if ind==0 && b:PHP_default_indenting
		let ind = b:PHP_default_indenting
	endif

	" Hit the start of the file, use default indent.
	if lnum == 0
		return b:PHP_default_indenting
	endif

	" if the last line is a stated line and it's not indented then why should
	" we indent this one??
	" if optimized mode is active and nor current or previous line are an 'else'
	" or the end of a possible bracketless thing then indent the same as the previous
	" line
	if last_line =~ '[;}]'.endline
		if ind==b:PHP_default_indenting
			return b:PHP_default_indenting
		elseif b:PHP_indentinghuge && ind==b:PHP_CurrentIndentLevel && cline !~# '^\s*\%(else\|\%(case\|default\).*:\|[})];\=\)' && last_line !~# '^\s*\%(\%(}\s*\)\=else\)' && getline(GetLastRealCodeLNum(lnum - 1))=~';'.endline
			return b:PHP_CurrentIndentLevel
		endif
	endif

	" Search the matching open bracket (with searchpair()) and set the indent of cline
	" to the indent of the matching line.
	if cline =~ '^\s*}\%(}}\)\@!'
		let ind = indent(FindOpenBracket(v:lnum))
		let b:PHP_CurrentIndentLevel = b:PHP_default_indenting
		return ind
	endif

	let LastLineClosed = 0 " used to prevent redundant tests in the last part of the script

	let unstated='\%(^\s*'.s:blockstart.'.*)\|\%(//.*\)\@<!\<e'.'lse\>\)'.endline
	" What is an unstated line?
	" - an "else" at the end of line
	" - a  s:blockstart (if while etc...) followed by anything and a ")" at
	"   the end of line

	" if the current line is an 'else' starting line
	" (to match an 'else' preceded by a '}' is irrelevant and futile - see
	" code above)
	if ind != b:PHP_default_indenting && cline =~# '^\s*else\%(if\)\=\>'
		let b:PHP_CurrentIndentLevel = b:PHP_default_indenting " prevent optimized to work at next call
		return indent(FindTheIfOfAnElse(v:lnum, 1))
	elseif last_line =~# unstated && cline !~ '^\s*{\|^\s*);\='.endline
		let ind = ind + &sw
		return ind

		" If the last line is terminated by ';' or if it's a closing '}'
		" We need to check if this isn't the end of a multilevel non '{}'
		" structure such as:
		" Exemple: 
		"			if ($truc)
		"				echo 'truc';
		"
		"	OR
		"
		"			if ($truc)
		"				while ($truc) {
		"					lkhlkh();
		"					echo 'infinite loop\n';
		"				}
	elseif ind != b:PHP_default_indenting && last_line =~ ';'.endline.'\|^\s*}\%(.*{'. endline.'\)\@!'
		" If we are here it means that the previous line is:
		" - a *;$ line
		" - a [beginning-blanck] } followed by anything but a { $
		let previous_line = last_line
		let last_line_num = lnum
		let LastLineClosed = 1
		" The idea here is to check if the current line is after a non '{}'
		" structure so we can indent it like the top of that structure.
		" The top of that structure is caracterized by a if (ff)$ style line
		" preceded by a stated line. If there is no such structure then we
		" just have to find two 'normal' lines following each other with the
		" same indentation and with the first of these two lines terminated by
		" a ; or by a }...

		while 1
			" let's skip '{}' blocks
			if previous_line =~ '^\s*}'
				" find the openning '{'
				let last_line_num = FindOpenBracket(last_line_num)

				" if the '{' is alone on the line get the line before
				if getline(last_line_num) =~ '^\s*{'
					let last_line_num = GetLastRealCodeLNum(last_line_num - 1)
				endif

				let previous_line = getline(last_line_num)

				continue
			else
				" At this point we know that the previous_line isn't a closing
				" '}' so we can check if we really are in such a structure.

				" it's not a '}' but it could be an else alone...
				if getline(last_line_num) =~# '^\s*else\%(if\)\=\>'
					let last_line_num = FindTheIfOfAnElse(last_line_num, 0)
					continue " re-run the loop (we could find a '}' again)
				endif

				" So now it's ok we can check :-)
				" A good quality is to have confidence in oneself so to know
				" if yes or no we are in that struct lets test the indent of
				" last_line_num and of last_line_num - 1!
				" If those are == then we are almost done.
				"
				" That isn't sufficient, we need to test how the first of the
				" 2 lines is ended...

				" Note the indenting of the line we are checking

				let last_match = last_line_num " remember the 'topest' line we found so far

				let one_ahead_indent = indent(last_line_num)
				let last_line_num = GetLastRealCodeLNum(last_line_num - 1)
				let two_ahead_indent = indent(last_line_num)
				let after_previous_line = previous_line
				let previous_line = getline(last_line_num)


				" If we find a '{' or a case/default then we are inside that block so lets
				" indent properly... Like the line following that block starter
				if previous_line =~# '^\s*\%(case\|default\).*:\|{'.endline
					break
				endif

				" The 3 lines below are not necessary for the script to work
				" but it makes it work a little more faster in some (rare) cases.
				" We verify if we are at the top of a non '{}' struct.
				if after_previous_line=~# '^\s*'.s:blockstart.'.*)'.endline && previous_line =~# '[;}]'.endline
					break
				endif

				if one_ahead_indent == two_ahead_indent || last_line_num < 1 
					" So the previous line and the line before are at the same
					" col. Now we just have to check if the line before is a ;$ or [}]$ ended line
					" we always check the most ahead line of the 2 lines so
					" it's useless to match ')$' since the lines couldn't have
					" the same indent...
					if previous_line =~# '[;}]'.endline || last_line_num < 1
						break
					endif
				endif
			endif
		endwhile

		if indent(last_match) != ind " if nothing was done lets the old script continue
			let ind = indent(last_match) " let's use the indent of the last line matched by the alhorithm above
			let b:PHP_CurrentIndentLevel = b:PHP_default_indenting "line added in version 1.02 to prevent optimized mode
			" from acting in some special cases
			return ind
		endif
	endif


	let plinnum = GetLastRealCodeLNum(lnum - 1)
	let pline = getline(plinnum) " previous to last line

	" REMOVE comments at end of line before treatment
	" the first par of the regex removes // from the end of line when they are
	" followed by a number of '"' which is a multiple of 2. The second part
	" removes // that are not followed by any '"'
	" Sorry for this unreadable thing...
	let last_line = substitute(last_line,"\\(//\\|#\\)\\(\\(\\([^\"']*\\([\"']\\)[^\"']*\\5\\)\\+[^\"']*$\\)\\|\\([^\"']*$\\)\\)",'','')

	" Indent blocks enclosed by {} or () (default indenting)
	if !LastLineClosed " the last line isn't a .*; or a }$ line
		" if the last line is a [{(]$ or a multiline function call (or array
		" declaration) with already one parameter on the opening ( line
		if last_line =~# '[{(]'.endline || last_line =~? '\h\w*\s*(.*,$' && pline !~ '[,(]'.endline
			let ind = ind + &sw
			if cline !~# '^\s*\%(default\|case\).*:' " case and default are not indented inside blocks
				let b:PHP_CurrentIndentLevel = ind
				return ind
			endif
		endif
	endif

	" If the current line closes a multiline function call or array def
	if cline =~  '^\s*);\='
		let ind = ind - &sw
	elseif cline =~# '^\s*\%(default\|case\).*:'
		let ind = ind - &sw
	endif

	if last_line =~# '^\s*\%(default\|case\).*:'
		let ind = ind + &sw
	endif

	let b:PHP_CurrentIndentLevel = ind
	return ind
endfunction

" vim: set ts=4 sw=4:
