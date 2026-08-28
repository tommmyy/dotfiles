local Source = {}
Source.__index = Source

local function label_text(text)
	local function shorten(str)
		local short_prefix = string.sub(str, 1, 20)
		local short_suffix = string.sub(str, math.max(string.len(str) - 15, 1), string.len(str))
		return short_prefix .. " ... " .. short_suffix
	end

	text = text:gsub("^%s*", "")
	return string.len(text) > 40 and shorten(text) or text
end

local function get_following_line(buffer, cursor)
	return function(index)
		local line = vim.api.nvim_buf_get_lines(buffer, cursor[1] + index - 1, cursor[1] + index, false)[1]
		return line or ""
	end
end

local function get_completion(buffer, cursor)
	local ok_binary, binary = pcall(require, "supermaven-nvim.binary.binary_handler")
	local ok_util, util = pcall(require, "supermaven-nvim.util")
	if not ok_binary or not ok_util or not binary:is_running() then
		return nil
	end

	local text_split = util.get_text_before_after_cursor(cursor)
	if not text_split.text_before_cursor or not text_split.text_after_cursor then
		return nil
	end

	local ok_prefix, prefix = pcall(util.get_cursor_prefix, buffer, cursor)
	if not ok_prefix then
		return nil
	end

	local query_state_id = binary:submit_query(buffer, prefix)
	if not query_state_id then
		return nil
	end

	local completion = binary:check_state(
		prefix,
		text_split.text_before_cursor,
		text_split.text_after_cursor,
		false,
		get_following_line(buffer, cursor),
		query_state_id,
		nil
	)

	if not completion or completion.kind ~= "text" or not completion.text or completion.text == "" then
		return nil
	end

	if completion.dedent == nil or (#completion.dedent > 0 and not util.ends_with(text_split.text_before_cursor, completion.dedent)) then
		return nil
	end

	while
		#completion.dedent > 0
		and #completion.text > 0
		and completion.dedent:sub(1, 1) == completion.text:sub(1, 1)
	do
		completion.text = completion.text:sub(2)
		completion.dedent = completion.dedent:sub(2)
	end

	completion.text = util.trim_end(completion.text)
	if completion.text == "" then
		return nil
	end

	return completion
end

function Source.new()
	return setmetatable({}, Source)
end

function Source:enabled()
	local ok_api, api = pcall(require, "supermaven-nvim.api")
	return ok_api and api.is_running()
end

function Source:get_trigger_characters()
	return { "*" }
end

function Source:get_keyword_pattern()
	return "."
end

function Source:get_completions(ctx, callback)
	local buffer = vim.api.nvim_get_current_buf()
	local cursor = vim.api.nvim_win_get_cursor(0)
	local started = vim.uv.now()
	local timer = vim.uv.new_timer()

	local function finish(items, incomplete)
		if timer and not timer:is_closing() then
			timer:stop()
			timer:close()
		end

		callback({
			context = ctx,
			is_incomplete_forward = incomplete or false,
			is_incomplete_backward = incomplete or false,
			items = items,
		})
	end

	local function poll()
		local completion = get_completion(buffer, cursor)
		if completion then
			local first_line = vim.split(completion.text, "\n", { plain = true })[1]
			local line = cursor[1] - 1
			local col = cursor[2]
			local current_line = vim.api.nvim_buf_get_lines(buffer, cursor[1] - 1, cursor[1], false)[1] or ""

			finish({
				{
					label = label_text(first_line),
					kind = vim.lsp.protocol.CompletionItemKind.Text,
					insertTextFormat = vim.lsp.protocol.InsertTextFormat.PlainText,
					sortText = "0000",
					textEdit = {
						newText = completion.text,
						range = {
							start = {
								line = line,
								character = math.max(col - #completion.dedent, 0),
							},
							["end"] = {
								line = line,
								character = #current_line,
							},
						},
					},
					documentation = {
						kind = vim.lsp.protocol.MarkupKind.Markdown,
						value = "```" .. vim.bo.filetype .. "\n" .. completion.text .. "\n```",
					},
				},
			}, completion.is_incomplete)
			return
		end

		if vim.uv.now() - started > 750 then
			finish({}, true)
		end
	end

	timer:start(0, 25, vim.schedule_wrap(poll))
	return function()
		if timer and not timer:is_closing() then
			timer:stop()
			timer:close()
		end
	end
end

return Source
