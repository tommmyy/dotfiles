local highlight_group = vim.api.nvim_create_augroup("YankHighlight", { clear = true })
vim.api.nvim_create_autocmd("TextYankPost", {
	callback = function()
		vim.highlight.on_yank()
	end,
	group = highlight_group,
	pattern = "*",
})

-- Fix tab width in Telescope preview windows (guess-indent does not run there,
-- so tabbed files would otherwise render at the default tabstop of 8).
vim.api.nvim_create_autocmd("User", {
	pattern = "TelescopePreviewerLoaded",
	callback = function()
		vim.bo.tabstop = 2
		vim.wo.list = false
	end,
})

-- https://github.com/nvim-tree/nvim-tree.lua/wiki/Open-At-Startup
vim.api.nvim_create_autocmd("VimEnter", {
	callback = function()
		-- NOTE: to enable opening nvim without nvim-tree at start page: nvim --cmd "let g:no_tree=1"
		if not vim.g.no_tree and vim.fn.argc() == 0 then
			require("nvim-tree.api").tree.open()
		end
	end,
})
