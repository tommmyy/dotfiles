--[[
Based on Kickstart.nvim
-- USEFUL:
-- https://www.youtube.com/watch?v=vdn_pKJUda8&t=288s
--
--]]

if vim.loader then
	vim.loader.enable()
end

-- Disable netrw before lazy.nvim/plugin registration; nvim-tree owns file browsing.
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

require("config.filetypes")

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

require("lazy").setup({
	{
		"supermaven-inc/supermaven-nvim",
		event = "InsertEnter",
		config = function()
			require("supermaven-nvim").setup({
				disable_inline_completion = false,
				disable_keymaps = true,
				log_level = "off", -- off, debug
			})
			require("supermaven-nvim.completion_preview").disable_inline_completion = true
		end,
	},
	-- Git related plugins
	"tpope/vim-fugitive",
	"tpope/vim-rhubarb",

	-- Detect tabstop and shiftwidth automatically
	"nmac427/guess-indent.nvim",
	{
		"folke/trouble.nvim",
		cmd = "Trouble",
		dependencies = { "nvim-tree/nvim-web-devicons" },
		opts = {
			-- your configuration comes here
			-- or leave it empty to use the default settings
			-- refer to the configuration section below
		},
	},
	{ "j-hui/fidget.nvim", event = "VeryLazy", opts = {} },
	{ "folke/lazydev.nvim", ft = "lua", opts = {} },
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
			"saghen/blink.cmp",
		},
		config = function()
			require("config.lsp").setup()
		end,
	},
	{
		-- Highlight, edit, and navigate code
		"nvim-treesitter/nvim-treesitter",
		dependencies = {
			"nvim-treesitter/nvim-treesitter-textobjects",
		},
		build = ":TSUpdate",
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
		config = function()
			require("luasnip").config.setup({})
		end,
	},
	{
		-- Autocompletion
		"saghen/blink.cmp",
		version = "1.*",
		event = "InsertEnter",
		dependencies = { "L3MON4D3/LuaSnip", "supermaven-inc/supermaven-nvim" },
		---@module 'blink.cmp'
		---@type blink.cmp.Config
		opts = {
			keymap = {
				preset = "enter",
				["<C-d>"] = { "scroll_documentation_up", "fallback" },
				["<C-f>"] = { "scroll_documentation_down", "fallback" },
				["<Tab>"] = { "select_next", "snippet_forward", "fallback" },
				["<S-Tab>"] = { "select_prev", "snippet_backward", "fallback" },
			},
			completion = {
				documentation = { auto_show = false },
				list = { selection = { preselect = true, auto_insert = false } },
			},
				sources = {
					default = { "lsp", "path", "buffer", "snippets", "lazydev", "supermaven" },
					providers = {
						lazydev = {
							name = "LazyDev",
							module = "lazydev.integrations.blink",
							score_offset = 100,
						},
						supermaven = {
							name = "Supermaven",
							module = "custom.supermaven_blink",
							async = true,
							score_offset = 100,
						},
					},
				},
			snippets = { preset = "luasnip" },
			fuzzy = { implementation = "lua" },
			signature = { enabled = true },
		},
	},

	-- Useful plugin to show you pending keybinds.
	{ "folke/which-key.nvim", event = "VeryLazy", opts = {} },
	{
		-- Adds git releated signs to the gutter, as well as utilities for managing changes
		"lewis6991/gitsigns.nvim",
		event = "VeryLazy",
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
		cmd = { "NvimTreeClose", "NvimTreeFindFile", "NvimTreeFindFileToggle", "NvimTreeOpen", "NvimTreeToggle" },
		dependencies = {
			"nvim-tree/nvim-web-devicons",
		},
		config = function()
			require("nvim-tree").setup({
				sort_by = "case_sensitive",
				view = {
					width = 45,
				},
				renderer = {
					group_empty = true,
				},
				filters = {
					git_ignored = true,
					dotfiles = false,
					exclude = { "/private[^/]*", ".env*" },
				},
			})
		end,
	},
	{
		"nvim-treesitter/nvim-treesitter-context",
		event = "VeryLazy",
	},
	{
		"tree-sitter/tree-sitter-jsdoc",
	},
	{
		-- Set lualine as statusline
		"nvim-lualine/lualine.nvim",
		event = "VeryLazy",
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
	-- "gc" to comment visual regions/lines
	{
		"numToStr/Comment.nvim",
		dependencies = { "JoosepAlviste/nvim-ts-context-commentstring" },
		opts = function()
			return {
				pre_hook = require("ts_context_commentstring.integrations.comment_nvim").create_pre_hook(),
			}
		end,
	},
	{
		"davidmh/mdx.nvim",
		ft = { "markdown", "markdown.mdx", "mdx" },
		dependencies = { "nvim-treesitter/nvim-treesitter" },
	},
	-- Fuzzy Finder (files, lsp, etc)
	{
		"nvim-telescope/telescope.nvim",
		version = "*",
		cmd = { "Telescope", "Ag" },
		dependencies = {
			"nvim-lua/plenary.nvim",
			{
				"nvim-telescope/telescope-fzf-native.nvim",
				-- NOTE: If you are having trouble with this installation,
				--       refer to the README for telescope-fzf-native for more instructions.
				build = "make",
				cond = function()
					return vim.fn.executable("make") == 1
				end,
			},
		},
		keys = {
			{ "<leader>?", function() require("telescope.builtin").oldfiles() end, desc = "[?] Find recently opened files" },
			{ "<leader><space>", function() require("telescope.builtin").buffers() end, desc = "[ ] Find existing buffers" },
			{
				"<leader>ú",
				function()
					require("telescope.builtin").current_buffer_fuzzy_find(require("telescope.themes").get_dropdown({
						winblend = 10,
						previewer = false,
					}))
				end,
				desc = "[/] Fuzzily search in current buffer",
			},
			{ "<leader>p", function() require("telescope.builtin").find_files({ hidden = false }) end, desc = "Search Files" },
			{ "<leader>ph", function() require("telescope.builtin").find_files({ hidden = true }) end, desc = "Search Hidden Files" },
			{ "<leader>sh", function() require("telescope.builtin").help_tags() end, desc = "[S]earch [H]elp" },
			{ "<leader>sw", function() require("telescope.builtin").grep_string() end, desc = "[S]earch current [W]ord" },
			{ "<leader>sg", function() require("telescope.builtin").live_grep() end, desc = "[S]earch by [G]rep" },
			{ "<leader>sd", function() require("telescope.builtin").diagnostics() end, desc = "[S]earch [D]iagnostics" },
			{ "<leader>s.", function() require("telescope.builtin").oldfiles() end, desc = "[S]earch Recent Files" },
			{ "<leader>sq", function() require("telescope.builtin").quickfix() end, desc = "[S] [Q]uickfix list" },
			{
				"<leader>sn",
				function()
					require("telescope.builtin").find_files({ cwd = vim.fn.stdpath("config") })
				end,
				desc = "[S]earch [N]eovim files",
			},
		},
		opts = {
			defaults = {
				path_display = { "truncate" },
				-- Show the full path of the SELECTED entry as the preview window's title
				-- (top border), updating as you move the cursor.
				dynamic_preview_title = true,
				layout_strategy = "flex",
				layout_config = {
					width = 0.95,
					height = 0.95,
					preview_cutoff = 1,
					horizontal = { preview_width = 0.6 },
					vertical = { preview_height = 0.6 },
				},
				mappings = {
					i = {
						["<C-u>"] = false,
						["<C-d>"] = false,
						["<C-p"] = "which_key",
						["<C>-"] = "which_key",
					},
				},
			},
		},
		config = function(_, opts)
			require("telescope").setup(opts)
			pcall(require("telescope").load_extension, "fzf")
			vim.api.nvim_create_user_command("Ag", function(command)
				require("custom.ag_files").search(command.args)
			end, { nargs = "+" })
		end,
	},

	{
		"stevearc/conform.nvim",
		opts = {
			formatters_by_ft = {
				astro = { "prettierd" },
				css = { "prettierd" },
				html = { "prettierd" },
				javascript = { "prettierd" },
				javascriptreact = { "prettierd" },
				json = { "prettierd" },
				jsonc = { "prettierd" },
				lua = { "stylua" },
				markdown = { "prettierd" },
				["markdown.mdx"] = { "prettierd" },
				scss = { "prettierd" },
				svelte = { "prettierd" },
				typescript = { "prettierd" },
				typescriptreact = { "prettierd" },
				yaml = { "prettierd" },
			},
			format_on_save = false,
		},
		config = function(_, opts)
			local conform = require("conform")
			conform.setup(opts)

			vim.api.nvim_create_autocmd("BufWritePre", {
				group = vim.api.nvim_create_augroup("format-and-fix-on-save", { clear = true }),
				callback = function(event)
					conform.format({ bufnr = event.buf, async = false, lsp_format = "fallback", timeout_ms = 3000 })

					local oxlint = vim.lsp.get_clients({ bufnr = event.buf, name = "oxlint" })[1]
					if oxlint then
						local _, err = oxlint:request_sync("workspace/executeCommand", {
							command = "oxc.fixAll",
							arguments = { { uri = vim.uri_from_bufnr(event.buf) } },
						}, 3000, event.buf)
						if err then
							vim.notify("Oxlint fix on save failed: " .. err.message, vim.log.levels.WARN)
						end
					end

					if vim.lsp.get_clients({ bufnr = event.buf, name = "eslint" })[1] then
						vim.lsp.buf.format({ bufnr = event.buf, name = "eslint", timeout_ms = 3000 })
					end
				end,
			})
		end,
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
			"nvim-telescope/telescope.nvim",
		},
		opts = {
			completion = {
				nvim_cmp = false,
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
			-- NOTE: https://github.com/epwalsh/obsidian.nvim/issues/664
			ui = { enable = false },
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
		},
	},
	{
		"MeanderingProgrammer/render-markdown.nvim",
		ft = { "markdown", "markdown.mdx" },
		opts = {
			completions = { blink = { enabled = true } },
		},
	},
	-- <AI SHIT> --
	{
		"NickvanDyke/opencode.nvim",
		dependencies = {
			-- Recommended for `ask()` and `select()`.
			-- Required for `snacks` provider.
			---@module 'snacks' <- Loads `snacks.nvim` types for configuration intellisense.
			{ "folke/snacks.nvim", opts = { input = {}, picker = {}, terminal = {} } },
		},
		config = function()
			---@type opencode.Opts
			vim.g.opencode_opts = {
				-- Your configuration, if any — see `lua/opencode/config.lua`, or "goto definition".
			}

			-- Required for `opts.events.reload`.
			vim.o.autoread = true

			-- To switch back from OC to nvim pane:
			-- 1. exit terminal mode: double tap Esc or <C-\><C-n>
			-- 2. you can press <C-h> (or <C-w><C-h>) to navigate to next pane
			-- UPDATE: i rebind the ctrl+h,j,k,l to work in terminal mode
			-- See: split navigation below

			vim.keymap.set({ "n", "x" }, "<C-a>", function()
				require("opencode").ask("@this: ", { submit = true })
			end, { desc = "Ask opencode" })

			vim.keymap.set({ "n", "x" }, "<leader>ap", function()
				require("opencode").select()
			end, { desc = "Execute opencode action…" })

			vim.keymap.set({ "n", "t" }, "<leader>at", function()
				require("opencode").toggle()
			end, { desc = "Toggle opencode" })

			vim.keymap.set({ "n", "x" }, "<leader>aa", function()
				require("opencode").prompt("@this")
			end, { desc = "Add to opencode" })

			vim.keymap.set("n", "<S-C-u>", function()
				require("opencode").command("session.half.page.up")
			end, { desc = "opencode half page up" })

			vim.keymap.set("n", "<S-C-d>", function()
				require("opencode").command("session.half.page.down")
			end, { desc = "opencode half page down" })
			-- You may want these if you stick with the opinionated "<C-a>" and "<C-x>" above — otherwise consider "<leader>o".
			-- vim.keymap.set("n", "+", "<C-a>", { desc = "Increment", noremap = true })
			-- vim.keymap.set("n", "-", "<C-x>", { desc = "Decrement", noremap = true })
		end,
	},
	-- </AI SHIT> --
	{ import = "custom.plugins" },
}, {})

require("config.options")
require("config.keymaps")
require("config.autocmds")
require("config.treesitter")
require("config.comment")

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
