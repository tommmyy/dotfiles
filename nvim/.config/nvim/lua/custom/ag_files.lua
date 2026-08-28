local M = {}

local function build_command(pattern)
	if vim.fn.executable("ag") == 1 then
		return { "ag", "--hidden", "--nocolor", "--nogroup", "--", pattern }, "ag"
	end

	return { "rg", "--hidden", "--no-heading", "--color=never", "--line-number", "--column", "--", pattern }, "rg"
end

function M.search(pattern)
	local pickers = require("telescope.pickers")
	local finders = require("telescope.finders")
	local conf = require("telescope.config").values
	local actions = require("telescope.actions")
	local action_state = require("telescope.actions.state")

	local cmd, executable = build_command(pattern)
	local opts = {
		entry_maker = function(entry)
			local path, lnum = entry:match("^(.-):(%d+):")
			if not path or not lnum then
				return nil
			end

			return {
				value = entry,
				display = entry,
				ordinal = path,
				filename = path,
				path = vim.uv.fs_realpath(path),
				lnum = tonumber(lnum),
			}
		end,
		attach_mappings = function(prompt_bufnr)
			actions.select_default:replace(function()
				actions.close(prompt_bufnr)
				local selection = action_state.get_selected_entry()
				if selection and selection.path then
					vim.cmd(":e +" .. selection.lnum .. " " .. selection.path)
				end
			end)
			return true
		end,
	}

	pickers
		.new(opts, {
			prompt_title = "Ag - " .. executable .. " " .. pattern,
			finder = finders.new_oneshot_job(cmd, opts),
			previewer = conf.grep_previewer(opts),
			sorter = conf.file_sorter(opts),
		})
		:find()
end

return M
