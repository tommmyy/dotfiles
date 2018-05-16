" Vundle ... {{{
	set nocompatible              " be iMproved, required
	filetype off                  " required

	" set the runtime path to include Vundle and initialize
	set rtp+=~/.vim/bundle/Vundle.vim
	call vundle#begin()

	Plugin 'VundleVim/Vundle.vim'
	Plugin 'tpope/vim-fugitive'
	Plugin 'pangloss/vim-javascript'
	Plugin 'mxw/vim-jsx'
	Plugin 'editorconfig/editorconfig-vim'
	Plugin 'scrooloose/nerdtree'
	Plugin 'tpope/vim-surround'
	Plugin 'w0rp/ale'

	" All of your Plugins must be added before the following line
	call vundle#end()            " required

	filetype plugin indent on    " required
" }}}

"General {{{"
	" Type :so % to refresh .vimrc after making changes

	" Use Vim settings, rather then Vi settings. This setting must be as early as
	" possible, as it has side effects.
	syntax on
	set ruler
	set showcmd
	set ruler
	set conceallevel=1
	" Reload files changed outside vim
	set autoread     
	" Use the OS clipboard by default (on versions compiled with `+clipboard`)
	set clipboard=unnamed
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
	
	"Allow usage of mouse in iTerm
	set ttyfast
	set mouse=a
	" set ttymouse=xterm2
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
	let g:ale_linters = {
	\   'javascript': ['eslint'],
	\}		
	
	let g:ale_fixers = {
	\   'javascript': ['prettier', 'eslint'],
	\}

	let g:ale_fix_on_save = 1

" }}}
