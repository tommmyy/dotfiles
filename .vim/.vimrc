" Vundle ... {{{
	set nocompatible              " be iMproved, required
	filetype off                  " required

	" set the runtime path to include Vundle and initialize
	set rtp+=~/.vim/bundle/Vundle.vim
	call vundle#begin()

	Plugin 'VundleVim/Vundle.vim'
	Plugin 'tpope/vim-fugitive'
	Plugin 'tpope/vim-surround'
	Plugin 'tpope/vim-repeat'
	Plugin 'tpope/vim-speeddating'
	Plugin 'tpope/vim-fireplace'
	Plugin 'tpope/vim-commentary'
	Plugin 'tpope/vim-eunuch'
	Plugin 'tpope/vim-markdown'
	Plugin 'scrooloose/nerdtree'
	Plugin 'Xuyuanp/nerdtree-git-plugin'
	" Plugin 'ctrlpvim/ctrlp.vim'
	Plugin 'bling/vim-airline'
	Plugin 'editorconfig/editorconfig-vim'
	Plugin 'w0rp/ale'
	Plugin 'pangloss/vim-javascript'
	Plugin 'mxw/vim-jsx'
	Plugin 'neoclide/jsonc.vim'
	Plugin 'vim-scripts/VimClojure'
	Plugin 'bhurlow/vim-parinfer'
	Plugin 'kien/rainbow_parentheses.vim'
	Plugin 'srstevenson/vim-picker'
	Plugin 'lervag/vimtex'
	Plugin 'christoomey/vim-tmux-navigator'
	" Plugin 'Valloric/YouCompleteMe'
	Plugin 'jxnblk/vim-mdx-js'
	Plugin 'ElmCast/elm-vim'
	" Plugin 'epilande/vim-es2015-snippets'
	" Plugin 'epilande/vim-react-snippets'
	Plugin 'SirVer/ultisnips'
	Plugin 'zivyangll/git-blame.vim'
	Plugin 'lilydjwg/colorizer'
	Plugin 'mileszs/ack.vim'
	Plugin 'schickling/vim-bufonly'
	Plugin 'nelstrom/vim-visual-star-search'
	Plugin 'neoclide/coc.nvim'
	Plugin 'reasonml-editor/vim-reason-plus'
	Plugin 'jph00/swift-apple'
	Plugin 'prabirshrestha/async.vim'
	Plugin 'prabirshrestha/vim-lsp'

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
	set conceallevel=1
	set hidden
	" If set the UltiSnips plugin will stop working
	" set paste
	set autoindent
	set smartindent

	" Reload files changed outside vim
	set autoread
	" Use the OS clipboard by default (on versions compiled with `+clipboard`)
	" set clipboard=unnamed

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
	nnoremap <C-J> <C-W><C-J>
	nnoremap <C-K> <C-W><C-K>
	nnoremap <C-L> <C-W><C-L>
	nnoremap <C-H> <C-W><C-H>

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

	vnoremap <Leader>c :'<,'>w !pbcopy<CR><CR>

	"Find occurence of visually selected text
	vnoremap // y/\V<C-r>=escape(@",'/\')<CR><CR>

	"Find occurence of visually selected text
	vnoremap <Leader>a y:Ack <C-r>=fnameescape(@")<CR><CR>

	let &t_SI = "\<Esc>Ptmux;\<Esc>\<Esc>]50;CursorShape=1\x7\<Esc>\\"
	let &t_SR = "\<Esc>Ptmux;\<Esc>\<Esc>]50;CursorShape=2\x7\<Esc>\\"
	let &t_EI = "\<Esc>Ptmux;\<Esc>\<Esc>]50;CursorShape=0\x7\<Esc>\\"

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

	let NERDTreeShowHidden=1
	let NERDTreeMinimalUI = 1
	let NERDTreeDirArrows = 1
" }}}

" Scrolling {{{
	set scrolloff=8         "Start scrolling when we're 8 lines away from margins
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

" vim-javascript {{{
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
	\   'mdx': ['prettier'],
	\   'json': ['prettier'],
	\   'scss': ['stylelint'],
	\   'css': ['stylelint'],
	\   'reason': ['refmt'],
	\   'swift': ['swiftformat'],
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

" Vim-picker {{{
       " let g:picker_selector_executable = 'fzy-tmux'
        nmap <leader>p <Plug>PickerEdit
        nmap <leader>pp <Plug>PickerBuffer
       " nmap <unique> <leader>ps <Plug>PickerSplit
       " nmap <unique> <leader>pt <Plug>PickerTabedit
       " nmap <unique> <leader>pv <Plug>PickerVsplit
       " nmap <unique> <leader>p] <Plug>PickerTag
       " nmap <unique> <leader>pw <Plug>PickerStag
       " nmap <unique> <leader>po <Plug>PickerBufferTag
       " nmap <unique> <leader>ph <Plug>PickerHelp
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
	let g:UltiSnipsExpandTrigger="<c-space>"
	let g:UltiSnipsListSnippets="<c-h>"
	let g:UltiSnipsJumpForwardTrigger="<c-b>"
	let g:UltiSnipsJumpBackwardTrigger="<c-n>"
	let g:UltiSnipsSnippetDirectories=["mysnippets"]
	" let g:UltiSnipsSnippetDirectories=[\"UltiSnips\", \"mysnippets\"]

	" If you want :UltiSnipsEdit to split your window.
	let g:UltiSnipsEditSplit="vertical"
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
	let g:markdown_fenced_languages = ['html', 'python', 'javascript=javascript.jsx', 'jsx=javascript.jsx', 'js=javascript.jsx', 'json', 'jsonc', 'bash=sh']
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
