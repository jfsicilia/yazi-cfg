--- Yanks like `y` and also puts the files on the system clipboard (Wayland,
--- as a text/uri-list) so they can be pasted into a browser (Gmail, WhatsApp
--- web, ...). The selection is read before yanking, because yank clears it.

local get_files = ya.sync(function()
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
	return files
end)

local function notify(content, level)
	ya.notify { title = "yank-clip", content = content, level = level or "info", timeout = 3 }
end

local function to_uri(path)
	return "file://" .. path:gsub("[^%w%-%._~/]", function(c) return string.format("%%%02X", c:byte()) end)
end

local function entry()
	local files = get_files()
	ya.emit("yank", {})
	if #files == 0 then
		return
	end

	local uris = {}
	for _, f in ipairs(files) do
		uris[#uris + 1] = to_uri(f)
	end

	-- wl-copy stays in the background serving the clipboard, so no pipes are kept open.
	local status, err = Command("sh")
		:arg { "-c", 'printf "%s" "$URIS" | wl-copy --type text/uri-list' }
		:env("URIS", table.concat(uris, "\r\n") .. "\r\n")
		:stdin(Command.NULL)
		:stdout(Command.NULL)
		:stderr(Command.NULL)
		:status()
	if not status or not status.success then
		return notify("Could not set the clipboard: " .. tostring(err or "wl-copy failed"), "warn")
	end
	notify("Copied " .. #files .. " file(s) to the clipboard")
end

return { entry = entry }
