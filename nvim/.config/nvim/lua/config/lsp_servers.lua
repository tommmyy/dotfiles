-- See `:help lspconfig-all` for all pre-configured LSPs.
return {
	astro = {},
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
		root_dir = function(fname)
			local util = require("lspconfig.util")
			return util.root_pattern("yarn.lock", ".git")(fname) or util.path.dirname(fname)
		end,
		init_options = {
			provideFormatter = false,
			preferences = {
				provideFormatter = false,
				noSemicolons = false,
				includeCompletionsForModuleExports = true,
				includeCompletionsForImportStatements = true,
				includeCompletionsWithSnippetText = true,
				includeAutomaticOptionalChainCompletions = true,
				includeInlayParameterNameHints = "all",
				includeInlayParameterNameHintsWhenArgumentMatchesName = false,
				includeInlayFunctionParameterTypeHints = true,
				includeInlayVariableTypeHints = true,
				includeInlayPropertyDeclarationTypeHints = true,
				includeInlayFunctionLikeReturnTypeHints = true,
				includeInlayEnumMemberValueHints = true,
				-- Key setting for type display
				displayPartsForJSDoc = true,
				generateReturnInDocTemplate = true,
			},
		},
		settings = {
			-- logVerbosity = "verbose",
			logDirectory = "~/tslog/",
			diagnostics = {
				ignoredCodes = { 7016 },
			},
			typescript = {
				inlayHints = {
					includeInlayParameterNameHints = "all",
					includeInlayParameterNameHintsWhenArgumentMatchesName = false,
					includeInlayFunctionParameterTypeHints = true,
					includeInlayVariableTypeHints = true,
					includeInlayPropertyDeclarationTypeHints = true,
					includeInlayFunctionLikeReturnTypeHints = true,
					includeInlayEnumMemberValueHints = true,
				},
			},
			javascript = {
				inlayHints = {
					includeInlayParameterNameHints = "all",
					includeInlayParameterNameHintsWhenArgumentMatchesName = false,
					includeInlayFunctionParameterTypeHints = true,
					includeInlayVariableTypeHints = true,
					includeInlayPropertyDeclarationTypeHints = true,
					includeInlayFunctionLikeReturnTypeHints = true,
					includeInlayEnumMemberValueHints = true,
				},
			},
		},
		filetypes = {
			"javascript",
			"javascriptreact",
			"typescript",
			"typescriptreact",
			"astro",
		},
	},
	eslint = {
		filetypes = {
			"javascript",
			"javascriptreact",
			"typescript",
			"typescriptreact",
			"svelte",
			"astro",
		},
		root_dir = function(fname)
			local util = require("lspconfig.util")
			return util.root_pattern(
				"eslint.config.js",
				"eslint.config.cjs",
				"eslint.config.mjs",
				".eslintrc",
				".eslintrc.js",
				".eslintrc.cjs",
				".eslintrc.json",
				"package.json",
				".git"
			)(fname)
		end,
		settings = {
			validate = "on",
			workingDirectory = { mode = "location" },
			-- ESLint 9 flat config (eslint.config.js). Legacy eslintrc projects
			-- still work: ESLint 9 auto-detects, and `true` matches our repos.
			useFlatConfig = true,
		},
		on_new_config = function(new_config, new_root_dir)
			new_config.settings = new_config.settings or {}
			new_config.settings.workingDirectory = {
				directory = new_root_dir,
				["!cwd"] = true,
			}
		end,
	},
	-- Fast Rust linter (PER-233). In-buffer diagnostics via oxc_language_server;
	-- roots on .oxlintrc.json. Runs alongside eslint (which keeps import
	-- resolution). :OxcFixAll applies --fix to the buffer.
	oxlint = {},
}
