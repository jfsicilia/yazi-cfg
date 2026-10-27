--- Opens the selected files (or the hovered one) in another program, mirroring
--- ~/bin/open_with.sh used by the dolphin kanata actions.
--- Args: "chrome"   -> new chrome window with the paths
---       "terminal" -> a foot window per unique folder (a file uses its parent)
---       "nvim"     -> a foot window running nvim with the paths

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
	ya.notify { title = "open-in", content = content, level = level or "warn", timeout = 5 }
end

-- Runs a command detached from yazi (it keeps running if yazi exits).
local function detach(args, cwd)
	local status, err = Command("setsid")
		:arg({ "-f", table.unpack(args) })
		:cwd(cwd)
		:stdin(Command.NULL)
		:stdout(Command.NULL)
		:stderr(Command.NULL)
		:status()
	if not status then
		notify("Failed to start " .. args[1] .. ": " .. tostring(err), "error")
	end
end

local function is_dir(path)
	local status = Command("test"):arg({ "-d", path }):status()
	return status and status.success
end

local function entry(_, job)
	local mode = job.args[1]
	local files, cwd = get_state()
	if #files == 0 then
		return notify("No file selected")
	end

	if mode == "chrome" then
		local args = { "google-chrome-stable", "--new-window" }
		for _, f in ipairs(files) do
			args[#args + 1] = f
		end
		detach(args, cwd)
	elseif mode == "terminal" then
		local seen = {}
		for _, f in ipairs(files) do
			local dir = is_dir(f) and f or (f:match("^(.*)/[^/]+$") or cwd)
			if dir == "" then
				dir = "/"
			end
			if not seen[dir] then
				seen[dir] = true
				detach({ "foot", "--maximized", "--working-directory=" .. dir }, cwd)
			end
		end
	elseif mode == "nvim" then
		local args = { "foot", "--maximized", "nvim" }
		for _, f in ipairs(files) do
			args[#args + 1] = f
		end
		detach(args, cwd)
	end
end

return { entry = entry }
