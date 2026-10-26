--- Extract and compress with ouch (https://github.com/ouch-org/ouch).
--- Works on the selected files, or the hovered one if none are selected.
--- Args: "extract"  -> each archive goes into its own folder (name without extension)
---       "compress" -> asks for the output name; the extension picks the format

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
	ya.notify { title = "ouch-archive", content = content, level = level or "info", timeout = 6 }
end

local function basename(path)
	return path:match("[^/]+$") or path
end

-- `--no` answers "no" to any question (e.g. overwrite), so nothing is clobbered.
-- No pipes are used: `status()` just waits for the exit code.
local function ouch(args, cwd)
	local status, err = Command("ouch")
		:arg(args)
		:cwd(cwd)
		:stdin(Command.NULL)
		:stdout(Command.NULL)
		:stderr(Command.NULL)
		:status()
	if not status then
		return false, "Failed to start ouch: " .. tostring(err)
	end
	if status.success then
		return true
	end
	return false, "ouch exited with code " .. tostring(status.code)
end

-- Folder ouch creates for an archive: its name without extension (and without a trailing ".tar").
local function extract_dir(path)
	local name = basename(path):gsub("%.[^.]+$", ""):gsub("%.tar$", "")
	return name
end

local function extract(files, cwd)
	local ok_count, first_dir = 0, nil
	for _, f in ipairs(files) do
		local ok, err = ouch({ "decompress", "--no", f }, cwd)
		if ok then
			ok_count = ok_count + 1
			local dir = cwd .. "/" .. extract_dir(f)
			local is_dir = Command("test"):arg({ "-d", dir }):status()
			if not first_dir and is_dir and is_dir.success then
				first_dir = dir
			end
		else
			notify(basename(f) .. ": " .. tostring(err):gsub("%s+$", ""), "error")
		end
	end
	if ok_count > 0 then
		notify("Extracted " .. ok_count .. " archive(s)")
		-- Drop the selection and hover the new folder.
		ya.emit("escape", { select = true })
		if first_dir then
			ya.emit("reveal", { first_dir })
		end
	end
end

local function compress(files, cwd)
	local suggestion = (#files == 1 and basename(files[1]) or basename(cwd)) .. ".tar.gz"
	local out, event = ya.input {
		pos = { "center", w = 60 },
		title = "Compress to (extension sets the format):",
		value = suggestion,
	}
	if event ~= 1 or not out or out == "" then
		return
	end

	local exists = Command("test"):arg({ "-e", cwd .. "/" .. out }):status()
	if exists and exists.success then
		return notify(out .. " already exists", "warn")
	end

	local args = { "compress", "--no" }
	for _, f in ipairs(files) do
		args[#args + 1] = basename(f)
	end
	args[#args + 1] = out

	local ok, err = ouch(args, cwd)
	if ok then
		notify("Created " .. out)
		-- Drop the selection (so a following extract acts on the new archive) and hover it.
		ya.emit("escape", { select = true })
		ya.emit("reveal", { cwd .. "/" .. out })
	else
		notify(tostring(err):gsub("%s+$", ""), "error")
	end
end

local function entry(_, job)
	local files, cwd = get_state()
	if #files == 0 then
		return notify("No file selected", "warn")
	end
	if job.args[1] == "compress" then
		compress(files, cwd)
	else
		extract(files, cwd)
	end
end

return { entry = entry }
