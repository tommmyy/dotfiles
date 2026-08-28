vim.keymap.set({ "n", "v" }, "<Space>", "<Nop>", { silent = true })

-- Remap for dealing with word wrap.
vim.keymap.set("n", "k", "v:count == 0 ? 'gk' : 'k'", { expr = true, silent = true })
vim.keymap.set("n", "j", "v:count == 0 ? 'gj' : 'j'", { expr = true, silent = true })

vim.keymap.set("n", "<leader>tn", function()
	require("trouble").next({ skip_groups = true, jump = true })
end, { desc = "Go to next trouble" })

vim.keymap.set("n", "<leader>tp", function()
	require("trouble").previous({ skip_groups = true, jump = true })
end, { desc = "Go to previous trouble" })

local function make_copy_path_fn(relative)
	return function()
		local filepath
		if relative then
			filepath = vim.fn.expand("%:.")
		else
			filepath = vim.fn.expand("%:p")
		end
		local mode = vim.fn.mode()
		local text

		if mode == "v" or mode == "V" or mode == "\22" then
			local start_line = vim.fn.line("v")
			local end_line = vim.fn.line(".")

			if start_line > end_line then
				start_line, end_line = end_line, start_line
			end

			text = string.format("%s:L%d-L%d", filepath, start_line, end_line)
		else
			text = filepath
		end

		vim.fn.setreg("+", text)
		print("Copied: " .. text)
	end
end

vim.keymap.set({ "n", "x" }, "<leader>cp", make_copy_path_fn(false), {
	desc = "Copy absolute file path or selected line range",
})

vim.keymap.set({ "n", "x" }, "<leader>cr", make_copy_path_fn(true), {
	desc = "Copy relative file path (from PWD) or selected line range",
})

-- Switch tumux workspaces.
vim.api.nvim_set_keymap("n", "<C-f>", ":silent !tmux neww tmux-sessionizer<CR>", { silent = true, noremap = true })

-- Disable arrow keys.
vim.api.nvim_set_keymap("n", "<up>", "<nop>", { noremap = true })
vim.api.nvim_set_keymap("n", "<down>", "<nop>", { noremap = true })
vim.api.nvim_set_keymap("n", "<left>", "<nop>", { noremap = true })
vim.api.nvim_set_keymap("n", "<right>", "<nop>", { noremap = true })
vim.api.nvim_set_keymap("i", "<up>", "<nop>", { noremap = true })
vim.api.nvim_set_keymap("i", "<down>", "<nop>", { noremap = true })
vim.api.nvim_set_keymap("i", "<left>", "<nop>", { noremap = true })
vim.api.nvim_set_keymap("i", "<right>", "<nop>", { noremap = true })

-- Easier split navigation.
vim.api.nvim_set_keymap("n", "<C-h>", "<C-w><C-h>", { noremap = true })
vim.api.nvim_set_keymap("n", "<C-j>", "<C-w><C-j>", { noremap = true })
vim.api.nvim_set_keymap("n", "<C-k>", "<C-w><C-k>", { noremap = true })
vim.api.nvim_set_keymap("n", "<C-l>", "<C-w><C-l>", { noremap = true })

-- Terminal split navigation: <c-\><c-n> leaves terminal mode.
vim.api.nvim_set_keymap("t", "<C-h>", [[<C-\><C-n><C-w>h]], { noremap = true })
vim.api.nvim_set_keymap("t", "<C-j>", [[<C-\><C-n><C-w>j]], { noremap = true })
vim.api.nvim_set_keymap("t", "<C-k>", [[<C-\><C-n><C-w>k]], { noremap = true })
vim.api.nvim_set_keymap("t", "<C-l>", [[<C-\><C-n><C-w>l]], { noremap = true })

vim.api.nvim_set_keymap("n", "ž", "<C-^>", { silent = true, noremap = true })
vim.api.nvim_set_keymap("n", "<C-n>", ":bnext<cr>", { silent = true, noremap = true })
vim.api.nvim_set_keymap("n", "<C-p>", ":bprevious<cr>", { silent = true, noremap = true })
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

vim.api.nvim_set_keymap("n", "<leader>e", ":NvimTreeFindFileToggle<cr>", { silent = true, noremap = true })

-- Diagnostic keymaps.
vim.keymap.set("n", "<leader>dn", vim.diagnostic.goto_next, { desc = "Go to next diagnostic message" })
vim.keymap.set("n", "<leader>dp", vim.diagnostic.goto_prev, { desc = "Go to previous diagnostic message" })
vim.keymap.set("n", "<leader>h", vim.diagnostic.open_float, { desc = "Open floating diagnostic message" })
vim.keymap.set("n", "<leader>q", vim.diagnostic.setloclist, { desc = "Open diagnostics list" })
