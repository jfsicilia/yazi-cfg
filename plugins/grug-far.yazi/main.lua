--- Opens nvim with grug-far.nvim (search & replace).
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

local function entry(_, job)
	local mode = job.args[1]
	local files, cwd = get_state()

	if mode == "files" and #files == 0 then
		return ya.notify { title = "grug-far", content = "No file to search in", level = "warn" }
	end

	local label, paths
	if mode == "files" then
		label = #files == 1 and ("replace in " .. files[1]:match("[^/]+$"))
			or ("replace in " .. #files .. " files")
		for i, f in ipairs(files) do
			if f:find("%s") then
				files[i] = '"' .. f .. '"'
			end
		end
		paths = table.concat(files, " ")
	else
		label = "replace in " .. (cwd:match("[^/]+$") or "") .. "/"
		paths = ""
	end

	local lua = "lua require('grug-far').open({ windowCreationCommand = 'topleft vertical split',"
		.. " instanceName = vim.env.YAZI_GRUG_LABEL,"
		.. (mode == "files" and " prefills = { paths = vim.env.YAZI_GRUG_PATHS }," or "")
		.. " })"

	local permit = ui.hide()
	local child, err = Command("nvim")
		:arg { "-c", lua }
		:cwd(cwd)
		:env("YAZI_GRUG_PATHS", paths)
		:env("YAZI_GRUG_LABEL", label)
		:stdin(Command.INHERIT)
		:stdout(Command.INHERIT)
		:stderr(Command.INHERIT)
		:spawn()

	if not child then
		permit:drop()
		return ya.notify { title = "grug-far", content = "Failed to start nvim: " .. tostring(err), level = "error" }
	end

	child:wait()
	permit:drop()
	ya.emit("refresh", {})
end

return { entry = entry }
