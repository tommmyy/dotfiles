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
	Plugin 'scrooloose/nerdtree'
	Plugin 'Xuyuanp/nerdtree-git-plugin'
	" Plugin 'ctrlpvim/ctrlp.vim'
	Plugin 'bling/vim-airline'	
	Plugin 'editorconfig/editorconfig-vim'
	Plugin 'w0rp/ale'
	Plugin 'pangloss/vim-javascript'
	Plugin 'mxw/vim-jsx'
	Plugin 'vim-scripts/VimClojure'
	Plugin 'bhurlow/vim-parinfer'
	Plugin 'kien/rainbow_parentheses.vim'
	Plugin 'srstevenson/vim-picker'
	Plugin 'lervag/vimtex'
	Plugin 'christoomey/vim-tmux-navigator'
	Plugin 'Valloric/YouCompleteMe'

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

	"Better alternate buffer switching
	nnoremap ž <C-^> 
	nnoremap <Leader>b :ls<CR>:b<Space>

	"Find occurence of visually selected text
	vnoremap // y/\V<C-r>=escape(@",'/\')<CR><CR>

" }}}

" VimTex {{{
        let g:tex_flavor = 'latex'
" }}}

" NERDTree {{{
        map <silent> <C-n> :NERDTreeFind<CR>
        map <silent> <C-n>t :NERDTreeToggle<CR>

	let NERDTreeShowHidden=1
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
	let g:ale_completion_enabled = 1
        nmap <F8> <Plug>(ale_fix)
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
        nmap <c-p> <Plug>PickerEdit
        nmap <c-p>b <Plug>PickerBuffer
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

" YCM {{{
     let g:ycm_min_num_of_chars_for_completion = 3 
     let g:ycm_min_num_identifier_candidate_chars = 4
     let g:ycm_enable_diagnostic_highlighting = 0
     " Don't show YCM's preview window [ I find it really annoying ]
     set completeopt-=preview
     let g:ycm_add_preview_to_completeopt = 0
" }}}
