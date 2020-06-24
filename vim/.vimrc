" Vundle ... {{{
	set nocompatible              " be iMproved, required
	filetype off                  " required

	" set the runtime path to include Vundle and initialize
	set rtp+=~/.vim/bundle/Vundle.vim
	call vundle#begin()

	Plugin 'VundleVim/Vundle.vim'
	Plugin 'tpope/vim-surround'
	Plugin 'tpope/vim-repeat'
	Plugin 'tpope/vim-speeddating'
	Plugin 'tpope/vim-fireplace'
	Plugin 'tpope/vim-commentary'
	Plugin 'tpope/vim-eunuch'
	Plugin 'bhurlow/vim-parinfer'
	Plugin 'prabirshrestha/async.vim'
	Plugin 'prabirshrestha/vim-lsp'
	Plugin 'wlemuel/vim-tldr'
	" visualizes the Vim undo tree.
	Plugin 'simnalamburt/vim-mundo'
	Plugin 'mhinz/vim-startify'

	"
	" IDE
	"
	Plugin 'editorconfig/editorconfig-vim'
	Plugin 'w0rp/ale'
	Plugin 'neoclide/coc.nvim'

	"
	" Languages
	"
	" Plugin 'ElmCast/elm-vim'
	" Plugin 'reasonml-editor/vim-reason-plus'
	" Plugin 'pangloss/vim-javascript'
	" Plugin 'mxw/vim-jsx'
	" Plugin 'jparise/vim-graphql'
	" Plugin 'jph00/swift-apple'
	" Plugin 'vim-scripts/VimClojure'
	Plugin 'sheerun/vim-polyglot'
	" Plugin 'jxnblk/vim-mdx-js'
	Plugin 'mzlogin/vim-markdown-toc'

	"
	" Navigation
	"
	Plugin 'scrooloose/nerdtree'
	Plugin 'Xuyuanp/nerdtree-git-plugin'
	Plugin 'mileszs/ack.vim'
	Plugin 'srstevenson/vim-picker'
  Plugin 'christoomey/vim-tmux-navigator'
	Plugin 'schickling/vim-bufonly'
	Plugin 'nelstrom/vim-visual-star-search'

	"
	" Git
	"
	Plugin 'tpope/vim-fugitive'
	Plugin 'zivyangll/git-blame.vim'
	" adds git column
	Plugin 'airblade/vim-gitgutter'

	"
	" Colors
	"

	Plugin 'flazz/vim-colorschemes'
	Plugin 'gruvbox-community/gruvbox'
	Plugin 'phanviet/vim-monokai-pro'
	Plugin 'sainnhe/gruvbox-material'
	Plugin 'bling/vim-airline'
	Plugin 'edkolev/tmuxline.vim'
	Plugin 'vim-airline/vim-airline-themes'
	Plugin 'kien/rainbow_parentheses.vim'
	" colorize all text in the form #rgb, #rgba, #rrggbb, #rrgbbaa, rgb(...), rgba(...)
	Plugin 'lilydjwg/colorizer'
	" Make the yanked region apparent
	Plugin 'machakann/vim-highlightedyank'

	" until the https://github.com/vim/vim/issues/4738 is fixed
	Plugin 'tyru/open-browser.vim'
	"
	" Tried, did not liked it
	"
	" Plugin 'haya14busa/incsearch.vim'
	" Plugin 'ctrlpvim/ctrlp.vim'
	" Plugin 'lervag/vimtex'
	" Plugin 'Valloric/YouCompleteMe'
	" Plugin 'epilande/vim-es2015-snippets'
	" Plugin 'epilande/vim-react-snippets'
	" Plugin 'SirVer/ultisnips'

	" All of your Plugins must be added before the following line
	call vundle#end()            " required

	filetype plugin indent on    " required
" }}}

"General {{{"
"	" Type :so % to refresh .vimrc after making changes

	" Use Vim settings, rather then Vi settings. This setting must be as early as
	" possible, as it has side effects.

	syntax on
	set hlsearch
	set ruler
	set showcmd
	set ruler
	set colorcolumn=80
	set conceallevel=1
	set hidden
	" If set the UltiSnips plugin will stop working
	" set paste
	set autoindent
	set smartindent
	" Having longer updatetime (default is 4000 ms = 4 s) leads to noticeable
	" " delays and poor user experience.
	set updatetime=300
	" Don't pass messages to |ins-completion-menu|.
	set shortmess+=c
	" Give more space for displaying messages.
	set cmdheight=2

	" Reload files changed outside vim
	set autoread
	" Use the OS clipboard by default (on versions compiled with `+clipboard`)
	" set clipboard=unnamed
	set clipboard=unnamed,unnamedplus

	" Trigger autoread when changing buffers or coming back to vim in terminal.
	au FocusGained,BufEnter * :silent! !
	"Set default font in mac vim and gvim
	set guifont=Inconsolata\ for\ Powerline:h24
	set cursorline    " highlight the current line
	set visualbell    " stop that ANNOYING beeping
	set wildmenu
	set wildmode=list:longest,full
	" Disable arrow keys
	nnoremap <up>    <nop>
	nnoremap <down>  <nop>
	nnoremap <left>  <nop>
	nnoremap <right> <nop>
	inoremap <up>    <nop>
	inoremap <down>  <nop>
	inoremap <left>  <nop>
	inoremap <right> <nop>

	" Set easier split navigation
	nnoremap <C-j> <C-w><C-j>
	nnoremap <C-k> <C-w><C-k>
	nnoremap <C-l> <C-w><C-l>
	nnoremap <C-h> <C-w><C-h>

	nnoremap <Space>r *Ncgn

	"Allow usage of mouse in iTerm
	set ttyfast
	set mouse=a

	"Set the root directories for :find command
	set path=~/Workspaces/**;~/Downloads/**;~/.dotfiles/**
	set wildignore+=**/node_modules/**

	"Switch tabs by f8
	set switchbuf=usetab
	nnoremap <F8> :sbnext<CR>
	nnoremap <S-F8> :sbprevious<CR>

	"Switch buffers
	:nnoremap <C-n> :bnext<CR>
	:nnoremap <C-p> :bprevious<CR>

	"Better alternate buffer switching
	nnoremap ž <C-^>
	nnoremap <Leader>b :ls<CR>:b<Space>

	"Find occurence of visually selected text
	vnoremap // y/\V<C-r>=escape(@",'/\')<CR><CR>

	" Change CWD
	nnoremap <leader>cd :cd %:p:h<CR>:pwd<CR>

	" https://vim.fandom.com/wiki/Switching_case_of_characters
	function! TwiddleCase(str)
		if a:str ==# toupper(a:str)
			let result = tolower(a:str)
		elseif a:str ==# tolower(a:str)
			let result = substitute(a:str,'\(\<\w\+\>\)', '\u\1', 'g')
		else
			let result = toupper(a:str)
		endif
		return result
	endfunction
	vnoremap ~ y:call setreg('', TwiddleCase(@"), getregtype(''))<CR>gv""Pgv

	let g:netrw_nogx = 1 " disable netrw's gx mapping.
	" let g:netrw_browsex_viewer='open'
	nmap gx <Plug>(openbrowser-smart-search)
	vmap gx <Plug>(openbrowser-smart-search)

	" spelling for md, mdx
	" autocmd BufRead,BufNewFile *.mdx,*.md setlocal spell
	" turn on the autocompletion
	set complete+=kspell


" }}}

" Macros {{{
	"js
	"extract Ramda
	nnoremap <Leader>1 ggqaq:%s/R\.\([a-zA-Z]*\)/\=setreg('A', submatch(1), 'V')/gn:put! Agg$$A,gv:sort ugvoo} from 'ramda';ggiimport {vi{=:%s/R\.//g

	"MD
	" js codeblock
	nnoremap <Leader>2 i```js<CR><CR>```ki
" }}}

" Colors {{{
	" This is only necessary if you use "set termguicolors" for tmux
	" https://github.com/vim/vim/issues/3608
	let &t_8f = "\<Esc>[38;2;%lu;%lu;%lum"
	let &t_8b = "\<Esc>[48;2;%lu;%lu;%lum"

	set termguicolors

	" Must go before `colorscheme`
	let g:gruvbox_contrast_dark='hard'
	let g:airline_powerline_fonts = 1
	let g:airline_theme='gruvbox'
	let g:gruvbox_improved_strings = 1
	let g:gruvbox_improved_warnings = 1

	" Necessary to make it work with ALE errors
	" https://github.com/morhetz/gruvbox/issues/266
	let g:gruvbox_guisp_fallback = 'bg'

	colorscheme gruvbox

	" important to for tmux to work properly
	set background=dark
	set t_Co=256
" }}}

" Markdown {{{
	let g:vim_markdown_fenced_languages = ['c++=cpp', 'viml=vim', 'bash=sh', 'ini=dosini', 'js=javascript', 'css=stylesheet']
	let g:markdown_minlines = 100
" }}}

" Startify {{{
	let g:startify_list_order = [
		 \ [' Recent'],
		 \ 'files',
		 \ [' Last modified'],
		 \ 'dir',
		 \ [' Sessions:'],
		 \ 'sessions',
		 \ ]

	let g:startify_session_persistence = 1
	let g:startify_change_to_vcs_root = 1
" }}}

" ctags {{{
	" creates command for generationg tags file
	command! MakeTags !ctags -R .
" }}}

" VimTex {{{
        let g:tex_flavor = 'latex'
" }}}

" NERDTree {{{
	"map <silent> <leader>n :NERDTreeFind<CR>
	"map <silent> <leader>nt :NERDTreeToggle<CR>

	"map <silent> <leader>n :NERDTreeFind<CR>

	:nmap <leader>e :NERDTreeFind<CR>
	autocmd bufenter * if (winnr("$") == 1 && exists("b:NERDTree") && b:NERDTree.isTabTree()) | q | endif

	let NERDTreeShowHidden = 1
	let NERDTreeMinimalUI = 1
	let NERDTreeDirArrows = 1
" }}}

" Scrolling {{{
	set scrolloff=4         "Start scrolling when we're 8 lines away from margins
	set sidescrolloff=15
	set sidescroll=1

	"Toggle relative numbering, and set to absolute on loss of focus or insert mode
	set rnu
	function! ToggleNumbersOn()
	    set nu!
	    set rnu
	endfunction
	function! ToggleRelativeOn()
	    set rnu!
	    set nu
	endfunction
	autocmd FocusLost * call ToggleRelativeOn()
	autocmd FocusGained * call ToggleRelativeOn()
	autocmd InsertEnter * call ToggleRelativeOn()
	autocmd InsertLeave * call ToggleRelativeOn()
" }}}

" vim-javascript
	let g:javascript_plugin_jsdoc = 1
	let g:javascript_plugin_flow = 1
	let g:javascript_conceal_function = "ƒ"
	let g:javascript_conceal_null                 = "ø"
	let g:javascript_conceal_this                 = "@"
	let g:javascript_conceal_return               = "⇚"
	let g:javascript_conceal_undefined            = "¿"
	let g:javascript_conceal_NaN                  = "ℕ"
	let g:javascript_conceal_prototype            = "¶"
	let g:javascript_conceal_static               = "•"
	let g:javascript_conceal_super                = "Ω"
	let g:javascript_conceal_arrow_function       = "⇒"
" }}}

" ALE {{{
	nmap <silent> <leader>a :ALEFirst<CR>
	nmap <silent> <leader>an :ALENext<CR>
	nmap <F8> <Plug>(ale_fix)

	let g:ale_linters = {
	\   'javascript': ['eslint', 'stylelint'],
	\   'scss': ['stylelint'],
	\   'css': ['stylelint'],
	\}
	   " 'reason': ['reason-language-server'],

	let g:ale_fixers = {
	\   'javascript': ['prettier', 'eslint'],
	\   'html': ['prettier'],
	\   'json': ['prettier'],
	\   'scss': ['stylelint'],
	\   'css': ['stylelint'],
	\   'reason': ['refmt'],
	\   'swift': ['swiftformat'],
	\   'mdx': ['prettier', 'eslint'],
	\}

	let g:ale_reason_ls_executable = '~/Workspaces/reason/reason-language-server'

	let g:ale_fix_on_save = 1
	let g:ale_completion_enabled = 1
" }}}

" CtrlP {{{
"	let g:ctrlp_map = '<c-p>'
"	let g:ctrlp_cmd = 'CtrlP'
"        " set root directory to dir with .git
"	let g:ctrlp_working_path_mode = 'ra'
"        let g:ctrlp_custom_ignore = {
"	\ 'dir':  '\v[\/]\.(git|hg|svn)$',
"	\ 'file': '\v\.(exe|so|dll)$',
"	\ 'link': 'SOME_BAD_SYMBOLIC_LINKS',
"	\ }
" }}}


" RainbowParentheses {{{
	let g:rbpt_max = 16
	let g:rbpt_loadcmd_toggle = 0
	let g:rbpt_colorpairs = [
    \ ['brown',       'RoyalBlue3'],
    \ ['darkgray',    'DarkOrchid3'],
    \ ['darkgreen',   'firebrick3'],
    \ ['darkcyan',    'RoyalBlue3'],
    \ ['darkred',     'SeaGreen3'],
    \ ['Darkblue',    'SeaGreen3'],
    \ ['darkmagenta', 'DarkOrchid3'],
    \ ['brown',       'firebrick3'],
    \ ['gray',        'RoyalBlue3'],
    \ ['black',       'SeaGreen3'],
    \ ['darkmagenta', 'DarkOrchid3'],
    \ ['darkgreen',   'RoyalBlue3'],
    \ ['darkcyan',    'SeaGreen3'],
    \ ['darkred',     'DarkOrchid3'],
    \ ['red',         'firebrick3'],
    \ ['gray',    'RoyalBlue3'],
    \ ]

	au VimEnter * RainbowParenthesesToggle
	au Syntax * RainbowParenthesesLoadRound
	au Syntax * RainbowParenthesesLoadSquare
	au Syntax * RainbowParenthesesLoadBraces
" }}}

" Elm-Vim {{{
	let g:elm_setup_keybindings = 0
" }}}

" YCM {{{
	let g:ycm_min_num_of_chars_for_completion = 3
	let g:ycm_min_num_identifier_candidate_chars = 4
	let g:ycm_enable_diagnostic_highlighting = 0
	" Don't show YCM's preview window [ I find it really annoying ]
	set completeopt-=preview
	let g:ycm_add_preview_to_completeopt = 0
	let g:ycm_semantic_triggers = {
	\ 'elm' : ['.'],
	\}
" }}}

" UltiSnips {{{
	" Trigger configuration. Do not use <tab> if you use
	" https://github.com/Valloric/YouCompleteMe.
	" let g:UltiSnipsExpandTrigger="<c-space>"
	" let g:UltiSnipsListSnippets="<c-h>"
	" let g:UltiSnipsJumpForwardTrigger="<c-b>"
	" let g:UltiSnipsJumpBackwardTrigger="<c-n>"
	" let g:UltiSnipsSnippetDirectories=["mysnippets"]
	" let g:UltiSnipsSnippetDirectories=[\"UltiSnips\", \"mysnippets\"]

	" If you want :UltiSnipsEdit to split your window.
	" let g:UltiSnipsEditSplit="vertical"
" }}}

" mileszs/ack.vim {{{
	 let g:ackprg = 'ag --nogroup --nocolor --column'
" }}}
"

" Reason-plus {{{
let g:LanguageClient_serverCommands = {
    \ 'reason': ['~/Workspaces/reason/reason-language-server']
    \ }
" }}}

" vim-markdown {{{
	let g:markdown_fenced_languages = [
				\'html',
				\'python',
				\'javascript=javascript.jsx',
				\'jsx=javascript.jsx',
				\'js=javascript.jsx',
				\'json',
				\'json5',
				\'bash=sh']

	" Do not indent shift+O in list context
	let g:vim_markdown_new_list_item_indent = 0
" }}}

" swift {{{
	if executable('sourcekit-lsp')
			au User lsp_setup call lsp#register_server({
					\ 'name': 'sourcekit-lsp',
					\ 'cmd': {server_info->['sourcekit-lsp']},
					\ 'whitelist': ['swift'],
					\ })
	endif
" }}}


" schickling/vim-bufonly {{{
	nnoremap <C-b> :Bufonly <CR>
" }}}
"
" Vim-picker {{{
	nmap <unique> <leader>p <Plug>(PickerEdit)
	nmap <unique> <leader>pb <Plug>(PickerBuffer)
	"
	" nmap <unique> <leader>pe <Plug>(PickerEdit)
	" nmap <unique> <leader>ps <Plug>(PickerSplit)
	" nmap <unique> <leader>pt <Plug>(PickerTabedit)
	" nmap <unique> <leader>pv <Plug>(PickerVsplit)
	" nmap <unique> <leader>pb <Plug>(PickerBuffer)
	" nmap <unique> <leader>p] <Plug>(PickerTag)
	" nmap <unique> <leader>pw <Plug>(PickerStag)
	" nmap <unique> <leader>po <Plug>(PickerBufferTag)
		" nmap <unique> <leader>ph <Plug>(PickerHelp)
" }}}

" Coc {{{
	let g:coc_global_extensions = [
							\   'coc-tsserver',
							\   'coc-json',
							\   'coc-syntax',
							\   'coc-highlight',
							\   'coc-emoji',
							\   'coc-marketplace',
							\   'coc-sh',
							\   'coc-word',
							\   'coc-yaml',
							\]

							" \   'coc-tag',
							" \   'coc-webpack',
							" \   'coc-sourcekit',
	" Use tab for trigger completion with characters ahead and navigate.
	" NOTE: Use command ':verbose imap <tab>' to make sure tab is not mapped by
	" other plugin before putting this into your config.
	inoremap <silent><expr> <TAB>
				\ pumvisible() ? "\<C-n>" :
				\ <SID>check_back_space() ? "\<TAB>" :
				\ coc#refresh()
	inoremap <expr><S-TAB> pumvisible() ? "\<C-p>" : "\<C-h>"

	function! s:check_back_space() abort
		let col = col('.') - 1
		return !col || getline('.')[col - 1]  =~# '\s'
	endfunction

	" Use <c-space> to trigger completion.
	inoremap <silent><expr> <c-space> coc#refresh()

	" GoTo code navigation.
	nmap <silent> gd <Plug>(coc-definition)
	nmap <silent> gy <Plug>(coc-type-definition)
	nmap <silent> gi <Plug>(coc-implementation)
	nmap <silent> gr <Plug>(coc-references)
	nmap <leader>rr <Plug>(coc-rename)

	" Use K to show documentation in preview window.
	nnoremap <silent> K :call <SID>show_documentation()<CR>

	function! s:show_documentation()
		if (index(['vim','help'], &filetype) >= 0)
			execute 'h '.expand('<cword>')
		else
			call CocAction('doHover')
		endif
	endfunction

	" set statusline^=%{coc#status()}%{get(b:,'coc_current_function','')}
" }}}

" vim-mundo {{{
	let g:mundo_preview_bottom = 1
	nnoremap <F5> :MundoToggle<CR>
" }}}

" incsearch {{{
	" map /  <Plug>(incsearch-forward)
	" map ?  <Plug>(incsearch-backward)
	" map g/ <Plug>(incsearch-stay)
	" set hlsearch
	" " let g:incsearch#auto_nohlsearch = 1
	" map n  <Plug>(incsearch-nohl-n)
	" map N  <Plug>(incsearch-nohl-N)
	" map *  <Plug>(incsearch-nohl-*)
	" map #  <Plug>(incsearch-nohl-#)
	" map g* <Plug>(incsearch-nohl-g*)
	" map g# <Plug>(incsearch-nohl-g#)
" }}}

" vim-markdown-toc {{{
	let g:vmt_fence_text='TOC'
	let g:vmt_list_item_char='-'
" }}}

