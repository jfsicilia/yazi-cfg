--- fzf over the current folder and its children.
--- Picking a folder opens it in yazi; picking a file reveals it.
--- Args: "all"  -> files and folders
---       "dirs" -> folders only

local get_cwd = ya.sync(function() return tostring(cx.active.current.cwd) end)

local function notify(content, level)
	ya.notify { title = "fzf-scoped", content = content, level = level or "warn" }
end

local function entry(_, job)
	local mode = job.args[1]
	local cwd = get_cwd()

	local fd_args = { "--hidden", "--exclude", ".git", "--color=never" }
	if mode == "dirs" then
		fd_args[#fd_args + 1] = "--type"
		fd_args[#fd_args + 1] = "d"
	end

	local permit = ui.hide()

	local fd, err = Command("fd"):arg(fd_args):cwd(cwd):stdout(Command.PIPED):stderr(Command.NULL):spawn()
	if not fd then
		permit:drop()
		return notify("Failed to start fd: " .. tostring(err), "error")
	end

	local fzf, ferr = Command("fzf")
		:arg {
			"--prompt", mode == "dirs" and "folders> " or "files/folders> ",
			"--preview", "[ -d {} ] && ls -A --color=always {} || bat --color=always --style=numbers {}",
		}
		:cwd(cwd)
		:stdin(fd:take_stdout())
		:stdout(Command.PIPED)
		:stderr(Command.INHERIT)
		:spawn()
	if not fzf then
		permit:drop()
		return notify("Failed to start fzf: " .. tostring(ferr), "error")
	end

	local output = fzf:wait_with_output()
	permit:drop()

	local rel = (output and output.stdout or ""):match("^[^\n]+")
	if not rel then
		return
	end

	local target = cwd .. "/" .. rel
	if mode == "dirs" then
		ya.emit("cd", { target })
	else
		-- `reveal` enters a file's parent folder; for a folder we want to go inside it.
		local is_dir = Command("test"):arg { "-d", target }:status()
		ya.emit(is_dir and is_dir.success and "cd" or "reveal", { target })
	end
end

return { entry = entry }
