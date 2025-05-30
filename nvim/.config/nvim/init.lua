--[[
Based on Kickstart.nvim
-- USEFUL:
-- https://www.youtube.com/watch?v=vdn_pKJUda8&t=288s
--
--]]

-- ... etc. See `:help lspconfig-all` for a list of all the pre-configured LSPs
local servers = {
	tailwindcss = {},
	pyright = {},
	-- mypy = {},
	-- ruff_lsp = {},
	rust_analyzer = {},
	-- https://github.com/neovim/nvim-lspconfig/issues/3149
	-- "nvim-lspconfig": { "branch": "master", "commit": "74e14808cdb15e625449027019406e1ff6dda020" },
	svelte = {
		settings = {
			svelte = {
				plugin = {
					typescript = {
						diagnostics = {
							enable = true,
						},
					},
				},
			},
		},
		-- svelte = {
		-- 	settings = {
		-- 		plugin = {
		-- 			typescript = {
		-- 				diagnostics = {
		-- 					enable = true,
		-- 				},
		-- 			},
		-- 		},
		-- 	},
		-- },
	},
	html = {},
	cssls = {
		-- https://github.com/neovim/nvim-lspconfig/blob/master/doc/server_configurations.md#cssls
		init_options = {
			provideFormatter = false,
		},
		settings = {
			css = {
				validate = true,
			},
			less = {
				validate = true,
			},
			scss = {
				validate = true,
			},
		},
	},
	lua_ls = {
		settings = {

			Lua = {
				workspace = { checkThirdParty = false },
				telemetry = { enable = false },
			},
		},
	},
	marksman = {},
	typos_lsp = {},
	jsonls = {
		init_options = {
			provideFormatter = false,
		},
	},
	ts_ls = {
		init_options = { provideFormatter = false },
		settings = {
			-- logVerbosity = "verbose",
			logDirectory = "~/tslog/",
			diagnostics = {
				ignoredCodes = { 7016 },
			},
		},
		filetypes = {
			"javascript",
			"javascriptreact",
			"javascript.jsx",
			"typescript",
			"typescriptreact",
			"typescript.tsx",
		},
	},
	eslint = {
		settings = {
			workingDirectories = { mode = "auto" },
			experimental = {
				useFlatConfig = false,
			},
		},
	},
}

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
	vim.fn.system({
		"git",
		"clone",
		"--filter=blob:none",
		"https://github.com/folke/lazy.nvim.git",
		"--branch=stable", -- latest stable release
		lazypath,
	})
end
vim.opt.rtp:prepend(lazypath)

-- NOTE: Here is where you install your plugins.
--  You can configure plugins using the `config` key.
--
--  You can also configure plugins after the setup call,
--    as they will be available in your neovim runtime.
require("lazy").setup({
	-- "github/copilot.vim",
	-- "zbirenbaum/copilot.lua",
	-- NOTE: First, some plugins that don't require any configuration

	{
		"supermaven-inc/supermaven-nvim",
		config = function()
			require("supermaven-nvim").setup({
				disable_inline_completion = true, -- disables inline completion for use with cmp
				log_level = "off",            -- off, debug
			})
		end,
	},

	-- Git related plugins
	"tpope/vim-fugitive",
	"tpope/vim-rhubarb",

	-- Detect tabstop and shiftwidth automatically
	"tpope/vim-sleuth",
	{
		"folke/trouble.nvim",
		dependencies = { "nvim-tree/nvim-web-devicons" },
		opts = {
			-- your configuration comes here
			-- or leave it empty to use the default settings
			-- refer to the configuration section below
		},
	},
	-- NOTE: This is where your plugins related to LSP can be installed.
	--  The configuration is done below. Search for lspconfig to find it below.
	{
		-- LSP Configuration & Plugins
		"neovim/nvim-lspconfig",
		dependencies = {
			-- Automatically install LSPs to stdpath for neovim
			-- "williamboman/mason.nvim",
			-- "williamboman/mason-lspconfig.nvim",

			-- Useful status updates for LSP
			-- NOTE: `opts = {}` is the same as calling `require('fidget').setup({})`
			{ "mason-org/mason.nvim", opts = {} },
			"mason-org/mason-lspconfig.nvim",
			"WhoIsSethDaniel/mason-tool-installer.nvim",
			{
				"j-hui/fidget.nvim",
				tag = "legacy",
				event = "LspAttach",
				opts = {},
			},

			-- Additional lua configuration, makes nvim stuff amazing!
			"folke/neodev.nvim",
		},
		config = function()
			-- Brief aside: **What is LSP?**
			--
			-- LSP is an initialism you've probably heard, but might not understand what it is.
			--
			-- LSP stands for Language Server Protocol. It's a protocol that helps editors
			-- and language tooling communicate in a standardized fashion.
			--
			-- In general, you have a "server" which is some tool built to understand a particular
			-- language (such as `gopls`, `lua_ls`, `rust_analyzer`, etc.). These Language Servers
			-- (sometimes called LSP servers, but that's kind of like ATM Machine) are standalone
			-- processes that communicate with some "client" - in this case, Neovim!
			--
			-- LSP provides Neovim with features like:
			--  - Go to definition
			--  - Find references
			--  - Autocompletion
			--  - Symbol Search
			--  - and more!
			--
			-- Thus, Language Servers are external tools that must be installed separately from
			-- Neovim. This is where `mason` and related plugins come into play.
			--
			-- If you're wondering about lsp vs treesitter, you can check out the wonderfully
			-- and elegantly composed help section, `:help lsp-vs-treesitter`

			--  This function gets run when an LSP attaches to a particular buffer.
			--    That is to say, every time a new file is opened that is associated with
			--    an lsp (for example, opening `main.rs` is associated with `rust_analyzer`) this
			--    function will be executed to configure the current buffer
			vim.api.nvim_create_autocmd("LspAttach", {
				group = vim.api.nvim_create_augroup("kickstart-lsp-attach", { clear = true }),
				callback = function(event)
					-- NOTE: Remember that Lua is a real programming language, and as such it is possible
					-- to define small helper and utility functions so you don't have to repeat yourself.
					--
					-- In this case, we create a function that lets us more easily define mappings specific
					-- for LSP related items. It sets the mode, buffer and description for us each time.
					local map = function(keys, func, desc, mode)
						mode = mode or "n"
						vim.keymap.set(mode, keys, func, { buffer = event.buf, desc = "LSP: " .. desc })
					end

					-- Rename the variable under your cursor.
					--  Most Language Servers support renaming across files, etc.
					map("grn", vim.lsp.buf.rename, "[R]e[n]ame")

					-- Execute a code action, usually your cursor needs to be on top of an error
					-- or a suggestion from your LSP for this to activate.
					map("gra", vim.lsp.buf.code_action, "[G]oto Code [A]ction", { "n", "x" })

					-- Find references for the word under your cursor.
					map("grr", require("telescope.builtin").lsp_references, "[G]oto [R]eferences")

					-- Jump to the implementation of the word under your cursor.
					--  Useful when your language has ways of declaring types without an actual implementation.
					map("gri", require("telescope.builtin").lsp_implementations, "[G]oto [I]mplementation")

					-- Jump to the definition of the word under your cursor.
					--  This is where a variable was first declared, or where a function is defined, etc.
					--  To jump back, press <C-t>.
					map("grd", require("telescope.builtin").lsp_definitions, "[G]oto [D]efinition")

					-- WARN: This is not Goto Definition, this is Goto Declaration.
					--  For example, in C this would take you to the header.
					map("grD", vim.lsp.buf.declaration, "[G]oto [D]eclaration")

					-- Fuzzy find all the symbols in your current document.
					--  Symbols are things like variables, functions, types, etc.
					map("gO", require("telescope.builtin").lsp_document_symbols, "Open Document Symbols")

					-- Fuzzy find all the symbols in your current workspace.
					--  Similar to document symbols, except searches over your entire project.
					map("gW", require("telescope.builtin").lsp_dynamic_workspace_symbols, "Open Workspace Symbols")

					-- Jump to the type of the word under your cursor.
					--  Useful when you're not sure what type a variable is and you want to see
					--  the definition of its *type*, not where it was *defined*.
					map("grt", require("telescope.builtin").lsp_type_definitions, "[G]oto [T]ype Definition")

					-- This function resolves a difference between neovim nightly (version 0.11) and stable (version 0.10)
					---@param client vim.lsp.Client
					---@param method vim.lsp.protocol.Method
					---@param bufnr? integer some lsp support methods only in specific files
					---@return boolean
					local function client_supports_method(client, method, bufnr)
						if vim.fn.has("nvim-0.11") == 1 then
							return client:supports_method(method, bufnr)
						else
							return client.supports_method(method, { bufnr = bufnr })
						end
					end

					-- The following two autocommands are used to highlight references of the
					-- word under your cursor when your cursor rests there for a little while.
					--    See `:help CursorHold` for information about when this is executed
					--
					-- When you move your cursor, the highlights will be cleared (the second autocommand).
					local client = vim.lsp.get_client_by_id(event.data.client_id)
					if
							client
							and client_supports_method(client, vim.lsp.protocol.Methods.textDocument_documentHighlight, event.buf)
					then
						local highlight_augroup = vim.api.nvim_create_augroup("kickstart-lsp-highlight", { clear = false })
						vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
							buffer = event.buf,
							group = highlight_augroup,
							callback = vim.lsp.buf.document_highlight,
						})

						vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
							buffer = event.buf,
							group = highlight_augroup,
							callback = vim.lsp.buf.clear_references,
						})

						vim.api.nvim_create_autocmd("LspDetach", {
							group = vim.api.nvim_create_augroup("kickstart-lsp-detach", { clear = true }),
							callback = function(event2)
								vim.lsp.buf.clear_references()
								vim.api.nvim_clear_autocmds({ group = "kickstart-lsp-highlight", buffer = event2.buf })
							end,
						})
					end

					-- The following code creates a keymap to toggle inlay hints in your
					-- code, if the language server you are using supports them
					--
					-- This may be unwanted, since they displace some of your code
					if client and client_supports_method(client, vim.lsp.protocol.Methods.textDocument_inlayHint, event.buf) then
						map("<leader>th", function()
							vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({ bufnr = event.buf }))
						end, "[T]oggle Inlay [H]ints")
					end
				end,
			})

			-- Diagnostic Config
			-- See :help vim.diagnostic.Opts
			vim.diagnostic.config({
				severity_sort = true,
				float = { border = "rounded", source = "if_many" },
				underline = { severity = vim.diagnostic.severity.ERROR },
				signs = vim.g.have_nerd_font and {
					text = {
						[vim.diagnostic.severity.ERROR] = "󰅚 ",
						[vim.diagnostic.severity.WARN] = "󰀪 ",
						[vim.diagnostic.severity.INFO] = "󰋽 ",
						[vim.diagnostic.severity.HINT] = "󰌶 ",
					},
				} or {},
				virtual_text = {
					source = "if_many",
					spacing = 2,
					format = function(diagnostic)
						local diagnostic_message = {
							[vim.diagnostic.severity.ERROR] = diagnostic.message,
							[vim.diagnostic.severity.WARN] = diagnostic.message,
							[vim.diagnostic.severity.INFO] = diagnostic.message,
							[vim.diagnostic.severity.HINT] = diagnostic.message,
						}
						return diagnostic_message[diagnostic.severity]
					end,
				},
			})

			-- LSP servers and clients are able to communicate to each other what features they support.
			--  By default, Neovim doesn't support everything that is in the LSP specification.
			--  When you add blink.cmp, luasnip, etc. Neovim now has *more* capabilities.
			--  So, we create new capabilities with blink.cmp, and then broadcast that to the servers.
			-- local capabilities = require("blink.cmp").get_lsp_capabilities()
			local capabilities = vim.lsp.protocol.make_client_capabilities()
			capabilities = vim.tbl_deep_extend("force", capabilities, require("cmp_nvim_lsp").default_capabilities())

			-- Ensure the servers and tools above are installed
			--
			-- To check the current status of installed tools and/or manually install
			-- other tools, you can run
			--    :Mason
			--
			-- You can press `g?` for help in this menu.
			--
			-- `mason` had to be setup earlier: to configure its options see the
			-- `dependencies` table for `nvim-lspconfig` above.
			--
			-- You can add other tools here that you want Mason to install
			-- for you, so that they are available from within Neovim.
			local ensure_installed = vim.tbl_keys(servers or {})
			vim.list_extend(ensure_installed, {
				"stylua", -- Used to format Lua code
			})
			require("mason-tool-installer").setup({ ensure_installed = ensure_installed })

			require("mason-lspconfig").setup({
				ensure_installed = {}, -- explicitly set to an empty table (Kickstart populates installs via mason-tool-installer)
				automatic_installation = false,
				handlers = {
					function(server_name)
						local server = servers[server_name] or {}
						-- This handles overriding only values explicitly passed
						-- by the server configuration above. Useful when disabling
						-- certain features of an LSP (for example, turning off formatting for ts_ls)
						server.capabilities = vim.tbl_deep_extend("force", {}, capabilities, server.capabilities or {})
						require("lspconfig")[server_name].setup(server)
					end,
				},
			})
		end,
	},
	-- {
	-- 	"zbirenbaum/copilot-cmp",
	-- 	config = function()
	-- 		require("copilot_cmp").setup()
	-- 	end,
	-- },
	{

		"L3MON4D3/LuaSnip",
		version = "v2.*", -- Replace <CurrentMajor> by the latest released major (first number of latest release)
		-- install jsregexp (optional!).
		build = "make install_jsregexp",
	},
	{
		-- Autocompletion
		"hrsh7th/nvim-cmp",
		dependencies = {
			-- "zbirenbaum/copilot-cmp",
			"hrsh7th/cmp-nvim-lsp",
			"hrsh7th/cmp-buffer",
			"saadparwaiz1/cmp_luasnip",
			"FelipeLema/cmp-async-path",
		},
	},

	-- Useful plugin to show you pending keybinds.
	{ "folke/which-key.nvim",  opts = {} },
	{
		-- Adds git releated signs to the gutter, as well as utilities for managing changes
		"lewis6991/gitsigns.nvim",
		opts = {
			-- See `:help gitsigns.txt`
			signs = {
				add = { text = "+" },
				change = { text = "~" },
				delete = { text = "_" },
				topdelete = { text = "‾" },
				changedelete = { text = "~" },
			},
		},
	},
	{
		"ellisonleao/gruvbox.nvim",
		priority = 1000,
		config = function()
			vim.o.background = "dark"
			vim.cmd.colorscheme("gruvbox")
		end,
	},
	{
		"nvim-tree/nvim-tree.lua",
		version = "*",
		dependencies = {
			"nvim-tree/nvim-web-devicons",
		},
		config = function()
			require("nvim-tree").setup({
				sort_by = "case_sensitive",
				renderer = {
					group_empty = true,
				},
				filters = {
					dotfiles = false,
				},
			})
		end,
	},
	{
		"nvim-treesitter/nvim-treesitter-context",
	},
	{
		"tree-sitter/tree-sitter-jsdoc",
	},
	{
		-- Set lualine as statusline
		"nvim-lualine/lualine.nvim",
		-- See `:help lualine.txt`
		opts = {
			options = {
				icons_enabled = true,
				theme = "gruvbox",
				component_separators = "|",
				section_separators = "",
			},
		},
	},

	-- {
	-- 	-- Add indentation guides even on blank lines
	-- 	"lukas-reineke/indent-blankline.nvim",
	-- 	-- Enable `lukas-reineke/indent-blankline.nvim`
	-- 	-- See `:help indent_blankline.txt`
	-- 	main = "ibl",
	-- 	opts = {},
	-- 	-- opts = {
	-- 	-- 	char = "┊",
	-- 	-- 	show_trailing_blankline_indent = false,
	-- 	-- },
	-- },

	-- "gc" to comment visual regions/lines
	{ "numToStr/Comment.nvim", opts = {} },
	{
		"kelly-lin/telescope-ag",
		dependencies = { "nvim-telescope/telescope.nvim" },
		config = function()
			local telescope_ag = require("telescope-ag")
			telescope_ag.setup({
				cmd = telescope_ag.cmds.ag, -- defaults to telescope_ag.cmds.ag
			})
		end,
	},
	{
		"davidmh/mdx.nvim",
		config = true,
		dependencies = { "nvim-treesitter/nvim-treesitter" },
	},
	-- Fuzzy Finder (files, lsp, etc)
	{ "nvim-telescope/telescope.nvim", version = "*", dependencies = { "nvim-lua/plenary.nvim" } },

	-- Fuzzy Finder Algorithm which requires local dependencies to be built.
	-- Only load if `make` is available. Make sure you have the system
	-- requirements installed.
	{
		"nvim-telescope/telescope-fzf-native.nvim",
		-- NOTE: If you are having trouble with this installation,
		--       refer to the README for telescope-fzf-native for more instructions.
		build = "make",
		cond = function()
			return vim.fn.executable("make") == 1
		end,
	},

	{
		-- Highlight, edit, and navigate code
		"nvim-treesitter/nvim-treesitter",
		dependencies = {
			"nvim-treesitter/nvim-treesitter-textobjects",
		},
		config = function()
			pcall(require("nvim-treesitter.install").update({ with_sync = true }))
		end,
	},
	-- {
	-- 	"nvimtools/none-ls.nvim",
	-- 	dependencies = {
	-- 		"nvimtools/none-ls-extras.nvim",
	-- 	},
	-- },
	{
		"jay-babu/mason-null-ls.nvim",
		event = { "BufReadPre", "BufNewFile" },
		dependencies = {
			"williamboman/mason.nvim",
			"nvimtools/none-ls.nvim",
			-- "jose-elias-alvarez/null-ls.nvim",
		},
	},

	{
		"epwalsh/obsidian.nvim",
		version = "*", -- recommended, use latest release instead of latest commit
		lazy = true,
		ft = "markdown",
		-- Replace the above line with this if you only want to load obsidian.nvim for markdown files in your vault:
		-- event = {
		-- 	-- If you want to use the home shortcut '~' here you need to call 'vim.fn.expand'.
		-- 	-- E.g. "BufReadPre " .. vim.fn.expand "~" .. "/my-vault/**.md"
		-- 	"BufReadPre "
		-- 	.. vim.fn.expand("~")
		-- 	.. "/workspaces/brain/brain/**.md",
		-- 	"BufNewFile " .. vim.fn.expand("~") .. "/workspaces/brain/brain/**.md",
		-- },
		dependencies = {
			-- Required.
			"nvim-lua/plenary.nvim",
			"hrsh7th/nvim-cmp",
			"nvim-telescope/telescope.nvim",
		},
		opts = {
			completion = {
				nvim_cmp = true,
				min_chars = 2,
			},
			-- note_id_func = function(title)
			-- 	-- Create note IDs in a Zettelkasten format with a timestamp and a suffix.
			-- 	-- In this case a note with the title 'My new note' will be given an ID that looks
			-- 	-- like '1657296016-my-new-note', and therefore the file name '1657296016-my-new-note.md'
			-- 	local suffix = ""
			-- 	if title ~= nil then
			-- 		-- If title is given, transform it into valid file name.
			-- 		suffix = title:gsub(" ", "-"):gsub("[^A-Za-z0-9-]", ""):lower()
			-- 	else
			-- 		-- If title is nil, just add 4 random uppercase letters to the suffix.
			-- 		for _ = 1, 4 do
			-- 			suffix = suffix .. string.char(math.random(65, 90))
			-- 		end
			-- 	end
			-- 	-- return tostring(os.time()) .. "-" .. suffix
			-- 	return suffix
			-- end,
			mappings = {
				["<leader>of"] = {
					action = function()
						return require("obsidian").util.gf_passthrough()
					end,
					opts = { noremap = false, expr = true, buffer = true },
				},
			},

			workspaces = {
				{
					name = "brain",
					path = "~/workspaces/vaults/brain",
				},
			},
			new_notes_location = "current_dir",
			daily_notes = {
				folder = "Daily",
				template = "daily.md",
			},
			templates = {
				subdir = "Templates",
				date_format = "%Y%m%d",
				time_format = "%H%M",
			},
			-- see below for full list of options 👇
		},
	},
	-- {
	-- 	"folke/noice.nvim",
	-- 	event = "VeryLazy",
	-- 	opts = {
	-- 		-- add any options here
	-- 	},
	-- 	dependencies = {
	-- 		-- if you lazy-load any plugin below, make sure to add proper `module="..."` entries
	-- 		"MunifTanjim/nui.nvim",
	-- 		-- OPTIONAL:
	-- 		--   `nvim-notify` is only needed, if you want to use the notification view.
	-- 		--   If not available, we use `mini` as the fallback
	-- 		"rcarriga/nvim-notify",
	-- 	},
	-- },
	-- NOTE: Next Step on Your Neovim Journey: Add/Configure additional "plugins" for kickstart
	--       These are some example plugins that I've included in the kickstart repository.
	--       Uncomment any of the lines below to enable them.
	-- require("kickstart.plugins.autoformat"),
	-- { -- Autoformat
	-- 	"stevearc/conform.nvim",
	-- 	event = { "BufWritePre" },
	-- 	cmd = { "ConformInfo" },
	-- 	keys = {
	-- 		{
	-- 			"<leader>f",
	-- 			function()
	-- 				require("conform").format({ async = true, lsp_format = "fallback" })
	-- 			end,
	-- 			mode = "",
	-- 			desc = "[F]ormat buffer",
	-- 		},
	-- 	},
	-- 	opts = {
	-- 		notify_on_error = false,
	-- 		format_on_save = function(bufnr)
	-- 			-- Disable "format_on_save lsp_fallback" for languages that don't
	-- 			-- have a well standardized coding style. You can add additional
	-- 			-- languages here or re-enable it for the disabled ones.
	-- 			local disable_filetypes = { c = true, cpp = true }
	-- 			local lsp_format_opt
	-- 			if disable_filetypes[vim.bo[bufnr].filetype] then
	-- 				lsp_format_opt = "never"
	-- 			else
	-- 				lsp_format_opt = "fallback"
	-- 			end
	-- 			return {
	-- 				timeout_ms = 500,
	-- 				lsp_format = lsp_format_opt,
	-- 			}
	-- 		end,
	-- 		formatters_by_ft = {
	-- 			lua = { "stylua" },
	-- 			-- Conform can also run multiple formatters sequentially
	-- 			-- python = { "isort", "black" },
	-- 			--
	-- 			-- You can use 'stop_after_first' to run the first available formatter from the list
	-- 			javascript = { "prettierd", "prettier", stop_after_first = true },
	-- 			javascriptreact = { "prettierd", "prettier", stop_after_first = true },
	-- 			typescript = { "prettierd", "prettier", stop_after_first = true },
	-- 			typescriptreact = { "prettierd", "prettier", stop_after_first = true },
	-- 		},
	-- 	},
	-- },
	-- require 'kickstart.plugins.debug',

	-- NOTE: The import below automatically adds your own plugins, configuration, etc from `lua/custom/plugins/*.lua`
	--    You can use this folder to prevent any conflicts with this init.lua if you're interested in keeping
	--    up-to-date with whatever is in the kickstart repo.
	--
	--    For additional information see: https://github.com/folke/lazy.nvim#-structuring-your-plugins
	--
	--    An additional note is that if you only copied in the `init.lua`, you can just comment this line
	--    to get rid of the warning telling you that there are not plugins in `lua/custom/plugins/`.
	{ import = "custom.plugins" },
}, {})

-- [[ Setting options ]]
-- See `:help vim.o`

-- Set highlight on search
vim.o.hlsearch = false
--  highlight the current line
vim.o.cursorline = true
-- stop that ANNOYING beeping
vim.o.visualbell = false

-- Make line numbers default
vim.wo.number = true

-- Enable mouse mode
vim.o.mouse = "a"

-- Sync clipboard between OS and Neovim.
--  Remove this option if you want your OS clipboard to remain independent.
--  See `:help 'clipboard'`
vim.o.clipboard = "unnamedplus"

-- Enable break indent
vim.o.breakindent = true

-- Save undo history
vim.o.undofile = true

-- Case insensitive searching UNLESS /C or capital in search
vim.o.ignorecase = true
vim.o.smartcase = true

-- Keep signcolumn on by default
vim.wo.signcolumn = "yes"

-- Decrease update time
vim.o.updatetime = 250
vim.o.timeout = true
vim.o.timeoutlen = 300

-- Set completeopt to have a better completion experience
vim.o.completeopt = "menuone,noselect"

-- NOTE: You should make sure your terminal supports this
vim.o.termguicolors = true

vim.o.conceallevel = 1

vim.o.rnu = true

vim.o.ruler = true
-- NOTE: does not work for some reaseon
-- vim.o.showcmd = true
-- vim.o.colorcolumn = 80

-- More height for a messages
vim.o.cmdheight = 2

vim.g.matchparen_timeout = 20
vim.g.matchparen_insert_timeout = 20

-- nvim-tree
vim.g.loaded_netrw = 1

vim.g.loaded_netrwPlugin = 1

--
-- [[ Basic Keymaps ]]

-- Keymaps for better default experience
-- See `:help vim.keymap.set()`
vim.keymap.set({ "n", "v" }, "<Space>", "<Nop>", { silent = true })

-- Remap for dealing with word wrap
vim.keymap.set("n", "k", "v:count == 0 ? 'gk' : 'k'", { expr = true, silent = true })
vim.keymap.set("n", "j", "v:count == 0 ? 'gj' : 'j'", { expr = true, silent = true })

-- [[ Highlight on yank ]]
-- See `:help vim.highlight.on_yank()`
local highlight_group = vim.api.nvim_create_augroup("YankHighlight", { clear = true })
vim.api.nvim_create_autocmd("TextYankPost", {
	callback = function()
		vim.highlight.on_yank()
	end,
	group = highlight_group,
	pattern = "*",
})

-- [[ Configure Telescope ]]
-- See `:help telescope` and `:help telescope.setup()`
require("telescope").setup({
	defaults = {
		mappings = {
			i = {
				["<C-u>"] = false,
				["<C-d>"] = false,
				["<C-p"] = "which_key",
				["<C>-"] = "which_key",
			},
		},
	},
})

-- Enable telescope fzf native, if installed
pcall(require("telescope").load_extension, "fzf")
local builtin = require("telescope.builtin")

-- See `:help telescope.builtin`
vim.keymap.set("n", "<leader>?", builtin.oldfiles, { desc = "[?] Find recently opened files" })
vim.keymap.set("n", "<leader><space>", builtin.buffers, { desc = "[ ] Find existing buffers" })
vim.keymap.set("n", "<leader>ú", function()
	-- You can pass additional configuration to telescope to change theme, layout, etc.
	builtin.current_buffer_fuzzy_find(require("telescope.themes").get_dropdown({
		winblend = 10,
		previewer = false,
	}))
end, { desc = "[/] Fuzzily search in current buffer" })

-- vim.keymap.set('n', '<leader>sf', require('telescope.builtin').find_files, { desc = '[S]earch [F]iles' })
vim.keymap.set("n", "<leader>p", function()
	builtin.find_files({ hidden = false })
end, { desc = "Search Files" })

vim.keymap.set("n", "<leader>ph", function()
	builtin.find_files({ hidden = true })
end, { desc = "Search Hidden Files" })
vim.keymap.set("n", "<leader>sh", builtin.help_tags, { desc = "[S]earch [H]elp" })
vim.keymap.set("n", "<leader>sw", builtin.grep_string, { desc = "[S]earch current [W]ord" })
vim.keymap.set("n", "<leader>sg", builtin.live_grep, { desc = "[S]earch by [G]rep" })
vim.keymap.set("n", "<leader>sd", builtin.diagnostics, { desc = "[S]earch [D]iagnostics" })
vim.keymap.set("n", "<leader>s.", builtin.oldfiles, { desc = "[S]earch Recent Files" })
vim.keymap.set("n", "<leader>sq", builtin.quickfix, { desc = "[S] [Q]uickfix list" })

vim.keymap.set("n", "<leader>tn", function()
	require("trouble").next({ skip_groups = true, jump = true })
end, { desc = "Go to next trouble" })

vim.keymap.set("n", "<leader>sn", function()
	builtin.find_files({ cwd = vim.fn.stdpath("config") })
end, { desc = "[S]earch [N]eovim files" })

vim.keymap.set("n", "<leader>tp", function()
	require("trouble").previous({ skip_groups = true, jump = true })
end, { desc = "Go to previous trouble" })

-- [[ MY Keymaps ]]
--
--

-- Switch tumux workspaces
vim.api.nvim_set_keymap("n", "<C-f>", ":silent !tmux neww tmux-sessionizer<CR>", { silent = true, noremap = true })
-- nnoremap <leader>l :redraw!<CR>
-- nnoremap <silent> <C-f> :silent !tmux neww tmux-sessionizer<CR>:redraw!<CR>

-- Disable arrow keys
vim.api.nvim_set_keymap("n", "<up>", "<nop>", { noremap = true })
vim.api.nvim_set_keymap("n", "<down>", "<nop>", { noremap = true })
vim.api.nvim_set_keymap("n", "<left>", "<nop>", { noremap = true })
vim.api.nvim_set_keymap("n", "<right>", "<nop>", { noremap = true })
vim.api.nvim_set_keymap("i", "<up>", "<nop>", { noremap = true })
vim.api.nvim_set_keymap("i", "<down>", "<nop>", { noremap = true })
vim.api.nvim_set_keymap("i", "<left>", "<nop>", { noremap = true })
vim.api.nvim_set_keymap("i", "<right>", "<nop>", { noremap = true })

-- Set easier split navigation
vim.api.nvim_set_keymap("n", "<C-h>", "<C-w><C-h>", { noremap = true })
vim.api.nvim_set_keymap("n", "<C-j>", "<C-w><C-j>", { noremap = true })
vim.api.nvim_set_keymap("n", "<C-k>", "<C-w><C-k>", { noremap = true })
vim.api.nvim_set_keymap("n", "<C-l>", "<C-w><C-l>", { noremap = true })

-- "Better alternate buffer switching
vim.api.nvim_set_keymap("n", "ž", "<C-^>", { silent = true, noremap = true })

-- "Switch buffers
vim.api.nvim_set_keymap("n", "<C-n>", ":bnext<cr>", { silent = true, noremap = true })
vim.api.nvim_set_keymap("n", "<C-p>", ":bprevious<cr>", { silent = true, noremap = true })

-- https://stackoverflow.com/questions/4545275/vim-close-all-buffers-but-this-one
vim.api.nvim_set_keymap("n", "<C-b>", ":%bd|e#|bd#<cr>", { silent = true, noremap = true })

vim.api.nvim_set_keymap("n", "J", "mzJ`z", { noremap = true })
vim.api.nvim_set_keymap("n", "<C-d>", "<C-d>zz", { noremap = true })
vim.api.nvim_set_keymap("n", "<C-u>", "<C-u>zz", { noremap = true })
vim.api.nvim_set_keymap("n", "n", "nzzzv", { noremap = true })
vim.api.nvim_set_keymap("n", "N", "Nzzzv", { noremap = true })

vim.api.nvim_set_keymap("n", "<leader>on", "<cmd>ObsidianNew<cr>", { desc = "New Obsidian note" })
vim.api.nvim_set_keymap("n", "<leader>oo", "<cmd>ObsidianSearch<cr>", { desc = "Search Obsidian notes" })
vim.api.nvim_set_keymap("n", "<leader>os", "<cmd>ObsidianQuickSwitch<cr>", { desc = "Quick Switch" })
vim.api.nvim_set_keymap("n", "<leader>ob", "<cmd>ObsidianBacklinks<cr>", { desc = "Show location list of backlinks" })
vim.api.nvim_set_keymap("n", "<leader>ot", "<cmd>ObsidianTemplate<cr>", { desc = "Follow link under cursor" })

--------------------------------------------------------------------------------------------------------
--
-- https://github.com/nvim-tree/nvim-tree.lua/wiki/Open-At-Startup
local function open_nvim_tree()
	-- open the tree
	require("nvim-tree.api").tree.open()
end
vim.api.nvim_create_autocmd({ "VimEnter" }, { callback = open_nvim_tree })
vim.api.nvim_set_keymap("n", "<leader>e", ":NvimTreeFindFileToggle<cr>", { silent = true, noremap = true })

--
-- [[ Configure Treesitter ]]
-- See `:help nvim-treesitter`
require("nvim-treesitter.configs").setup({
	-- Add languages to be installed here that you want installed for treesitter
	ensure_installed = { "lua", "python", "rust", "tsx", "typescript", "help", "vim", "markdown", "markdown_inline" },
	-- Autoinstall languages that are not installed. Defaults to false (but you can change for yourself!)
	auto_install = true,
	highlight = { enable = true, disable = { "rust", "python", "lua" } },
	indent = { enable = true, disable = { "python" } },
	incremental_selection = {
		enable = true,
		keymaps = {
			init_selection = "<c-space>",
			node_incremental = "<c-space>",
			scope_incremental = "<c-s>",
			node_decremental = "<M-space>",
		},
	},
	textobjects = {
		select = {
			enable = true,
			lookahead = true, -- Automatically jump forward to textobj, similar to targets.vim
			keymaps = {
				-- You can use the capture groups defined in textobjects.scm
				["aa"] = "@parameter.outer",
				["ia"] = "@parameter.inner",
				["af"] = "@function.outer",
				["if"] = "@function.inner",
				["ac"] = "@class.outer",
				["ic"] = "@class.inner",
			},
		},
		move = {
			enable = true,
			set_jumps = true, -- whether to set jumps in the jumplist
			goto_next_start = {
				["]m"] = "@function.outer",
				["]]"] = "@class.outer",
			},
			goto_next_end = {
				["]M"] = "@function.outer",
				["]["] = "@class.outer",
			},
			goto_previous_start = {
				["[m"] = "@function.outer",
				["[["] = "@class.outer",
			},
			goto_previous_end = {
				["[M"] = "@function.outer",
				["[]"] = "@class.outer",
			},
		},
		swap = {
			enable = true,
			swap_next = {
				["<leader>a"] = "@parameter.inner",
			},
			swap_previous = {
				["<leader>A"] = "@parameter.inner",
			},
		},
	},
})

-- Diagnostic keymaps
-- vim.keymap.set("n", "[d", vim.diagnostic.goto_prev, { desc = "Go to previous diagnostic message" })
vim.keymap.set("n", "<leader>dn", vim.diagnostic.goto_next, { desc = "Go to next diagnostic message" })
vim.keymap.set("n", "<leader>dp", vim.diagnostic.goto_prev, { desc = "Go to previous diagnostic message" })
vim.keymap.set("n", "<leader>h", vim.diagnostic.open_float, { desc = "Open floating diagnostic message" })
vim.keymap.set("n", "<leader>q", vim.diagnostic.setloclist, { desc = "Open diagnostics list" })
--
-- -- LSP settings.
-- --  This function gets run when an LSP connects to a particular buffer.
-- local on_attach = function(_, bufnr)
-- 	-- NOTE: Remember that lua is a real programming language, and as such it is possible
-- 	-- to define small helper and utility functions so you don't have to repeat yourself
-- 	-- many times.
-- 	--
-- 	-- In this case, we create a function that lets us more easily define mappings specific
-- 	-- for LSP related items. It sets the mode, buffer and description for us each time.
-- 	local nmap = function(keys, func, desc)
-- 		if desc then
-- 			desc = "LSP: " .. desc
-- 		end
--
-- 		vim.keymap.set("n", keys, func, { buffer = bufnr, desc = desc })
-- 	end
--
-- 	nmap("<leader>rn", vim.lsp.buf.rename, "[R]e[n]ame")
-- 	nmap("<leader>ca", vim.lsp.buf.code_action, "[C]ode [A]ction")
--
-- 	nmap("gd", vim.lsp.buf.definition, "[G]oto [D]efinition")
-- 	nmap("gr", builtin.lsp_references, "[G]oto [R]eferences")
-- 	nmap("gI", vim.lsp.buf.implementation, "[G]oto [I]mplementation")
-- 	nmap("<leader>D", vim.lsp.buf.type_definition, "Type [D]efinition")
-- 	nmap("<leader>ds", builtin.lsp_document_symbols, "[D]ocument [S]ymbols")
-- 	nmap("<leader>ws", builtin.lsp_dynamic_workspace_symbols, "[W]orkspace [S]ymbols")
--
-- 	-- See `:help K` for why this keymap
-- 	nmap("K", vim.lsp.buf.hover, "Hover Documentation")
-- 	nmap("<C-k>", vim.lsp.buf.signature_help, "Signature Documentation")
--
-- 	-- Lesser used LSP functionality
-- 	nmap("gD", vim.lsp.buf.declaration, "[G]oto [D]eclaration")
-- 	nmap("<leader>wa", vim.lsp.buf.add_workspace_folder, "[W]orkspace [A]dd Folder")
-- 	nmap("<leader>wr", vim.lsp.buf.remove_workspace_folder, "[W]orkspace [R]emove Folder")
-- 	nmap("<leader>wl", function()
-- 		print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
-- 	end, "[W]orkspace [L]ist Folders")
--
-- 	-- Create a command `:Format` local to the LSP buffer
-- 	vim.api.nvim_buf_create_user_command(bufnr, "Format", function(_)
-- 		vim.lsp.buf.format()
-- 	end, { desc = "Format current buffer with LSP" })
-- end
-- Enable the following language servers
--  Feel free to add/remove any LSPs that you want here. They will automatically be installed.
--
--  Add any additional override configuration in the following tables. They will be passed to
--  the `settings` field of the server config. You must look up that documentation yourself.

-- Setup neovim lua configuration
require("neodev").setup()

-- nvim-cmp supports additional completion capabilities, so broadcast that to servers
local capabilities = vim.lsp.protocol.make_client_capabilities()
capabilities = require("cmp_nvim_lsp").default_capabilities(capabilities)
capabilities.textDocument.completion.completionItem.snippetSupport = true

-- copilot
--
-- require("copilot").setup({
-- 	suggestion = { enabled = true },
-- 	panel = { enabled = true },
-- })

-- vim.keymap.set("i", "<C-J>", 'copilot#Accept("\\<CR>")', {
-- 	expr = true,
-- 	replace_keycodes = false,
-- })
-- vim.g.copilot_no_tab_map = true

-- null-ls
local null_ls = require("null-ls")
local augroup = vim.api.nvim_create_augroup("LspFormatting", {})

local formatting = null_ls.builtins.formatting
local diagnostics = null_ls.builtins.diagnostics
--
-- local command_resolver = require("null-ls.helpers.command_resolver")

null_ls.setup({
	debug = false,
	sources = {
		-- diagnostics.eslint_d.with({
		-- 	extra_filetypes = { "svelte" },
		-- }),
		formatting.prettierd,
		formatting.stylua,
		-- formatting.black,
		-- diagnostics.mypy,
		-- diagnostics.ruff,

		-- formatting.eslint_d,
		-- diagnostics.eslint_d.with({
		-- 	extra_filetypes = { "svelte" },
		-- 	dynamic_command = command_resolver.from_node_modules(),
		-- 	-- only_local = "node_modules/.bin",
		-- 	-- dynamic_command = function(params)
		-- 	-- 	return command_resolver.from_node_modules(params)
		-- 	-- 			or command_resolver.from_yarn_pnp(params)
		-- 	-- 			or vim.fn.executable(params.command) == 1 and params.command
		-- 	-- end,
		-- }),
		-- formatting.eslint_d.with({
		-- 	extra_filetypes = { "svelte" },
		-- 	dynamic_command = command_resolver.from_node_modules(),
		-- 	-- only_local = "node_modules/.bin",
		-- 	-- dynamic_command = function(params)
		-- 	-- 	return command_resolver.from_node_modules(params)
		-- 	-- 			or command_resolver.from_yarn_pnp(params)
		-- 	-- 			or vim.fn.executable(params.command) == 1 and params.command
		-- 	-- end,
		-- }),
	},
	on_attach = function(client, bufnr)
		if client.supports_method("textDocument/formatting") then
			vim.api.nvim_clear_autocmds({ group = augroup, buffer = bufnr })
			vim.api.nvim_create_autocmd("BufWritePre", {
				group = augroup,
				buffer = bufnr,
				callback = function()
					-- on 0.8, you should use vim.lsp.buf.format({ bufnr = bufnr }) instead
					-- vim.lsp.buf.formatting_sync()
					vim.lsp.buf.format({ bufnr = bufnr })
				end,
			})
		end
	end,
})

-- -- Setup mason so it can manage external tooling
-- require("mason").setup()
--
-- -- Ensure the servers above are installed
-- local mason_lspconfig = require("mason-lspconfig")
-- mason_lspconfig.setup({
-- 	ensure_installed = vim.tbl_keys(servers),
-- })
--
-- mason_lspconfig.setup_handlers({
-- 	function(server_name)
-- 		-- local server_config = {
-- 		-- 	capabilities = capabilities,
-- 		-- 	on_attach = on_attach,
-- 		-- 	settings = servers[server_name].settings,
-- 		-- 	init_options = servers[server_name].init_options,
-- 		-- }
-- 		-- if servers[server_name] and servers[server_name].filetypes then
-- 		-- 	server_config.filetypes = servers[server_name].filetypes
-- 		-- end
--
-- 		-- local w = require("lspconfig")[server_name]
-- 		-- if w then
-- 		-- 	local x = w[server_name]
-- 		-- 	if x then
-- 		-- 		x.setup(server_config)
-- 		-- 	end
-- 		-- end
-- 	end,
-- })

local mason_null_ls = require("mason-null-ls")
mason_null_ls.setup({
	automatic_installation = true,
	ensure_installed = vim.tbl_keys(servers),
})

-- nvim-cmp setup
local cmp = require("cmp")
local luasnip = require("luasnip")

luasnip.config.setup({})

local has_words_before = function()
	if vim.api.nvim_buf_get_option(0, "buftype") == "prompt" then
		return false
	end
	local line, col = unpack(vim.api.nvim_win_get_cursor(0))
	return col ~= 0 and vim.api.nvim_buf_get_text(0, line - 1, 0, line - 1, col, {})[1]:match("^%s*$") == nil
end

cmp.setup({
	snippet = {
		expand = function(args)
			luasnip.lsp_expand(args.body)
		end,
	},
	mapping = cmp.mapping.preset.insert({
		["<C-d>"] = cmp.mapping.scroll_docs(-4),
		["<C-f>"] = cmp.mapping.scroll_docs(4),
		["<C-Space>"] = cmp.mapping.complete({}),
		["<CR>"] = cmp.mapping.confirm({
			-- behavior = cmp.ConfirmBehavior.Replace,
			behavior = cmp.ConfirmBehavior.Insert,
			select = true,
		}),
		["<Tab>"] = cmp.mapping(function(fallback)
			if cmp.visible() and has_words_before() then
				cmp.select_next_item({ behavior = cmp.SelectBehavior.Select })
			elseif cmp.visible() then
				cmp.select_next_item()
			elseif luasnip.expand_or_jumpable() then
				luasnip.expand_or_jump()
			else
				fallback()
			end
		end, { "i", "s" }),
		["<S-Tab>"] = cmp.mapping(function(fallback)
			if cmp.visible() then
				cmp.select_prev_item()
			elseif luasnip.jumpable(-1) then
				luasnip.jump(-1)
			else
				fallback()
			end
		end, { "i", "s" }),
	}),
	sorting = {
		priority_weight = 2,
		comparators = {
			-- require("copilot_cmp.comparators").prioritize,

			-- Below is the default comparator list and order for nvim-cmp
			cmp.config.compare.offset,
			-- cmp.config.compare.scopes, --this is commented in nvim-cmp too
			cmp.config.compare.exact,
			cmp.config.compare.score,
			cmp.config.compare.recently_used,
			cmp.config.compare.locality,
			cmp.config.compare.kind,
			cmp.config.compare.sort_text,
			cmp.config.compare.length,
			cmp.config.compare.order,
		},
	},
	sources = {
		{ name = "supermaven", group_index = 2 },
		-- { name = "copilot",    group_index = 2 },
		{ name = "nvim_lsp",   group_index = 2 },
		{ name = "buffer",     group_index = 2 },
		{ name = "async_path", group_index = 2 },
		{ name = "luasnip",    group_index = 2 },
	},
})

-- Comment
local ft = require("Comment.ft")
ft.set("scss", { "//%s", "/*%s*/" })

-- require("noice").setup({
-- 	lsp = {
-- 		-- override markdown rendering so that **cmp** and other plugins use **Treesitter**
-- 		override = {
-- 			["vim.lsp.util.convert_input_to_markdown_lines"] = true,
-- 			["vim.lsp.util.stylize_markdown"] = true,
-- 			["cmp.entry.get_documentation"] = true, -- requires hrsh7th/nvim-cmp
-- 		},
-- 	},
-- 	-- you can enable a preset for easier configuration
-- 	presets = {
-- 		bottom_search = true,       -- use a classic bottom cmdline for search
-- 		command_palette = true,     -- position the cmdline and popupmenu together
-- 		long_message_to_split = true, -- long messages will be sent to a split
-- 		inc_rename = false,         -- enables an input dialog for inc-rename.nvim
-- 		lsp_doc_border = false,     -- add a border to hover docs and signature help
-- 	},
-- })

-- The line beneath this is called `modeline`. See `:help modeline`
-- vim: ts=2 sts=2 sw=2 et
--
--
-- Enable tracing of LSP
-- vim.lsp.set_log_level("trace")
-- if vim.fn.has("nvim-0.5.1") == 1 then
--   require("vim.lsp.log").set_format_func(vim.inspect)
-- end
-- then run :LspLog
