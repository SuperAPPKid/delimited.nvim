local api = vim.api
local severity = vim.diagnostic.severity
local M = {}

M.settings = {}

function M.setup(tbl)
  M.settings = tbl
  vim.cmd [[
    highlight default link DelimitedError DiagnosticVirtualTextError
    highlight default link DelimitedWarn DiagnosticVirtualTextWarn
    highlight default link DelimitedInfo DiagnosticVirtualTextInfo
    highlight default link DelimitedHint DiagnosticVirtualTextHint
  ]]
end

function M.eval_config(tbl)
	if not tbl then return M.settings	end
	return vim.tbl_extend('force', M.settings, tbl)
end

local function hlgroup(d)
	if d.severity == severity.ERROR then
		return "DelimitedError"
	elseif d.severity == severity.WARN then
		return "DelimitedWarn"
	elseif d.severity == severity.HINT then
		return "DelimitedHint"
	elseif d.severity == severity.INFO then
		return "DelimitedInfo"
	end
end

local function diagnostic_hl(d, dopts)
	vim.g.edh_tracker = vim.g.edh_tracker or 0

	local bufnr = api.nvim_get_current_buf()
	local ns = api.nvim_create_namespace("delimited")

	local old_edh_tracker = vim.g.edh_tracker

	vim.g.edh_tracker = (vim.g.edh_tracker + 1) % 500

	api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
	if dopts.pre then
		dopts.pre()
	end
	vim.highlight.range(bufnr, ns, hlgroup(d), { d.lnum, d.col }, { d.end_lnum, d.end_col })

	return old_edh_tracker
end

local function diagnostic_hl_set_trigger(bufnr, old_tracker, dopts)
	local old_cursor = api.nvim_win_get_cursor(0)
	local ns = api.nvim_create_namespace("delimited")
	api.nvim_create_autocmd({ "CursorMoved" }, {
		callback = function()
			local cursor = api.nvim_win_get_cursor(0)
			if old_cursor[1] == cursor[1] and old_cursor[2] == cursor[2] then
				return
			end
			if vim.g.edh_tracker == (old_tracker + 1) % 500 then
				api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
				if dopts.post then
					dopts.post()
				end
			end
			return true
		end,
	})
end

function M.goto_next(opts, dopts)
	dopts = M.eval_config(dopts)
	local bufnr = api.nvim_get_current_buf()
	local d = vim.diagnostic.get_next(opts)
	if not d or not d.end_lnum or not d.end_col then
		vim.diagnostic.goto_next(opts)
		return
	end
	local old_tracker = diagnostic_hl(d, dopts)
	vim.diagnostic.goto_next(opts)
	diagnostic_hl_set_trigger(bufnr, old_tracker, dopts)
end

function M.goto_prev(opts, dopts)
	dopts = M.eval_config(dopts)
	local bufnr = api.nvim_get_current_buf()
	local d = vim.diagnostic.get_prev(opts)
	if not d or not d.end_lnum or not d.end_col then
		vim.diagnostic.goto_prev(opts)
		return
	end
	local old_tracker = diagnostic_hl(d, dopts)
	vim.diagnostic.goto_prev(opts)
	diagnostic_hl_set_trigger(bufnr, old_tracker, dopts)
end

function M.open_float(opts, dopts)
	dopts = M.eval_config(dopts)

	local bufnr = api.nvim_get_current_buf()
	local cursor_position = vim.api.nvim_win_get_cursor(0)
	local cursor_line = cursor_position[1] - 1

	local diagnostics = vim.diagnostic.get(bufnr, opts)

	local d
	for _, diag in ipairs(diagnostics) do
		if diag.lnum == cursor_line then
			d = diag
			break
		end
	end

	if not d or not d.end_lnum or not d.end_col then
		vim.diagnostic.open_float(opts)
		return
	end

	local old_tracker = diagnostic_hl(d, dopts)
	vim.diagnostic.open_float(opts)
	diagnostic_hl_set_trigger(bufnr, old_tracker, dopts)
end

return M
