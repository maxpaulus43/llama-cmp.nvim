--- Ollama HTTP client for llama-cmp
--- Uses vim.fn.jobstart + curl for streaming HTTP requests (no plenary dependency)
local config = require("llama-cmp.config")
local util = require("llama-cmp.util")

local M = {}

--- Current job state
local state = {
	job_id = nil,
	tmpfile = nil,
}

--- Check if a request is currently running
---@return boolean
function M.is_running()
	return state.job_id ~= nil
end

--- Cancel the current request
function M.cancel()
	if state.job_id then
		pcall(vim.fn.jobstop, state.job_id)
		state.job_id = nil
	end
	if state.tmpfile then
		pcall(vim.fn.delete, state.tmpfile)
		state.tmpfile = nil
	end
end

--- Generate completion from Ollama
---@param prompt string The FIM prompt
---@param opts table|nil Options override
---@param on_token function Callback for each token: function(token: string)
---@param on_complete function Callback when done: function()
---@param on_error function Callback on error: function(err: string)
function M.generate(prompt, opts, on_token, on_complete, on_error)
	-- Cancel any existing request
	M.cancel()

	local cfg = config.get()
	opts = opts or {}

	local endpoint = opts.endpoint or cfg.endpoint
	local model = opts.model or cfg.model
	local gen_opts = cfg.generation

	-- Build request body
	local body = {
		model = model,
		prompt = prompt,
		stream = true,
		raw = true, -- Use raw mode for FIM
		options = {
			num_predict = opts.max_tokens or gen_opts.max_tokens,
			temperature = opts.temperature or gen_opts.temperature,
			stop = opts.stop or gen_opts.stop,
		},
	}

	-- Write body to temp file (avoids shell escaping issues with complex prompts)
	local tmpfile = vim.fn.tempname()
	local json_body = vim.fn.json_encode(body)
	local ok = pcall(vim.fn.writefile, { json_body }, tmpfile)

	if not ok then
		on_error("Failed to write request body to temp file")
		return
	end

	state.tmpfile = tmpfile

	-- Buffer for incomplete JSON chunks
	local buffer = ""
	local got_response = false

	-- Build curl command
	local url = endpoint .. "/api/generate"
	local cmd = {
		"curl",
		"--silent",
		"--no-buffer",
		"--max-time",
		"60",
		"-X",
		"POST",
		"-H",
		"Content-Type: application/json",
		"-d",
		"@" .. tmpfile,
		url,
	}

	util.debug("Starting request to %s with model %s", url, model)

	state.job_id = vim.fn.jobstart(cmd, {
		on_stdout = function(_, data, _)
			if not data then
				return
			end

			for _, chunk in ipairs(data) do
				if chunk and chunk ~= "" then
					buffer = buffer .. chunk
				end
			end

			-- Process complete JSON lines
			while true do
				local newline_pos = buffer:find("\n")
				if not newline_pos then
					-- Also try to parse if buffer looks like complete JSON
					if buffer:match("^%s*{.*}%s*$") then
						local json_str = buffer
						buffer = ""

						local parse_ok, obj = pcall(vim.fn.json_decode, json_str)
						if parse_ok and obj then
							got_response = true

							if obj.error then
								vim.schedule(function()
									on_error(obj.error)
								end)
								return
							end

							if obj.response and obj.response ~= "" then
								vim.schedule(function()
									on_token(obj.response)
								end)
							end

							if obj.done then
								vim.schedule(function()
									on_complete()
								end)
							end
						end
					end
					break
				end

				local json_str = buffer:sub(1, newline_pos - 1)
				buffer = buffer:sub(newline_pos + 1)

				if json_str ~= "" then
					local parse_ok, obj = pcall(vim.fn.json_decode, json_str)
					if parse_ok and obj then
						got_response = true

						if obj.error then
							vim.schedule(function()
								on_error(obj.error)
							end)
							return
						end

						if obj.response and obj.response ~= "" then
							vim.schedule(function()
								on_token(obj.response)
							end)
						end

						if obj.done then
							vim.schedule(function()
								on_complete()
							end)
						end
					end
				end
			end
		end,

		on_stderr = function(_, data, _)
			if data and #data > 0 then
				local stderr = table.concat(data, "\n")
				if stderr ~= "" then
					util.debug("curl stderr: %s", stderr)
				end
			end
		end,

		on_exit = function(_, code, _)
			-- Cleanup
			if state.tmpfile then
				pcall(vim.fn.delete, state.tmpfile)
				state.tmpfile = nil
			end
			state.job_id = nil

			-- Handle exit
			if code ~= 0 then
				vim.schedule(function()
					if not got_response then
						if code == 7 then
							on_error("Could not connect to Ollama. Is it running?")
						elseif code == 28 then
							on_error("Request timed out")
						else
							on_error("curl exited with code " .. code)
						end
					end
				end)
			end
		end,
	})

	if state.job_id <= 0 then
		pcall(vim.fn.delete, tmpfile)
		state.tmpfile = nil
		on_error("Failed to start curl process")
	end
end

--- Check if Ollama is accessible
---@param callback function Callback: function(ok: boolean, err: string|nil)
function M.health_check(callback)
	local cfg = config.get()
	local url = cfg.endpoint .. "/api/tags"

	local cmd = {
		"curl",
		"--silent",
		"--max-time",
		"5",
		url,
	}

	vim.fn.jobstart(cmd, {
		on_exit = function(_, code, _)
			vim.schedule(function()
				if code == 0 then
					callback(true, nil)
				elseif code == 7 then
					callback(false, "Could not connect to Ollama at " .. cfg.endpoint)
				else
					callback(false, "Health check failed with code " .. code)
				end
			end)
		end,
	})
end

--- List available models
---@param callback function Callback: function(models: table|nil, err: string|nil)
function M.list_models(callback)
	local cfg = config.get()
	local url = cfg.endpoint .. "/api/tags"

	local output = {}

	vim.fn.jobstart({
		"curl",
		"--silent",
		"--max-time",
		"5",
		url,
	}, {
		on_stdout = function(_, data, _)
			if data then
				for _, chunk in ipairs(data) do
					if chunk ~= "" then
						table.insert(output, chunk)
					end
				end
			end
		end,
		on_exit = function(_, code, _)
			vim.schedule(function()
				if code ~= 0 then
					callback(nil, "Failed to list models")
					return
				end

				local json_str = table.concat(output, "")
				local ok, result = pcall(vim.fn.json_decode, json_str)

				if ok and result and result.models then
					local models = {}
					for _, m in ipairs(result.models) do
						table.insert(models, m.name)
					end
					callback(models, nil)
				else
					callback(nil, "Failed to parse model list")
				end
			end)
		end,
	})
end

return M
