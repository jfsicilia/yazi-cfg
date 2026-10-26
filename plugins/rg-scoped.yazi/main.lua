--- Live ripgrep through fzf (type to search), opens the picked hit in nvim at that line.
--- Args: "files"     -> selected files, or the hovered one if none are selected.
---       "workspace" -> current folder and its children.

local get_state = ya.sync(function()
	local files = {}
	for _, file in pairs(cx.active.selected) do
		files[#files + 1] = tostring(file.url)
	end
	if #files == 0 then
		local hovered = cx.active.current.hovered
		if hovered then
			files[1] = tostring(hovered.url)
		end
	end
	return files, tostring(cx.active.current.cwd)
end)

local function notify(content, level)
	ya.notify { title = "rg-scoped", content = content, level = level or "warn" }
end

local function entry(_, job)
	local mode = job.args[1]
	local files, cwd = get_state()

	if mode == "files" and #files == 0 then
		return notify("No file to search in")
	end

	-- fzf does the filtering itself (--disabled): every keystroke re-runs rg.
	local paths = { "." }
	if mode == "files" then
		paths = {}
		for _, f in ipairs(files) do
			paths[#paths + 1] = ya.quote(f)
		end
	end
	local reload = "[ -n {q} ] && rg --color=never --no-heading --with-filename --line-number --smart-case -- {q} "
		.. table.concat(paths, " ")
		.. " || true"

	local prompt
	if mode == "files" then
		prompt = #files == 1 and ("find in " .. files[1]:match("[^/]+$") .. "> ")
			or ("find in " .. #files .. " files> ")
	else
		prompt = "find in " .. (cwd:match("[^/]+$") or "") .. "/> "
	end

	local permit = ui.hide()

	local fzf, ferr = Command("fzf")
		:arg {
			"--disabled",
			"--delimiter", ":",
			"--prompt", prompt,
			"--bind", "change:reload:" .. reload,
			"--preview", "bat --color=always --style=numbers --highlight-line {2} {1}",
			"--preview-window", "right:60%:+{2}-/2",
		}
		:cwd(cwd)
		:stdin(Command.NULL)
		:stdout(Command.PIPED)
		:stderr(Command.INHERIT)
		:spawn()
	if not fzf then
		permit:drop()
		return notify("Failed to start fzf: " .. tostring(ferr), "error")
	end

	local output = fzf:wait_with_output()
	local file, line = (output and output.stdout or ""):match("^(.-):(%d+):")
	if not file then
		permit:drop()
		return
	end

	local nvim, nerr = Command("nvim")
		:arg { "+" .. line, file }
		:cwd(cwd)
		:stdin(Command.INHERIT)
		:stdout(Command.INHERIT)
		:stderr(Command.INHERIT)
		:spawn()
	if not nvim then
		permit:drop()
		return notify("Failed to start nvim: " .. tostring(nerr), "error")
	end

	nvim:wait()
	permit:drop()
	ya.emit("refresh", {})
end

return { entry = entry }
