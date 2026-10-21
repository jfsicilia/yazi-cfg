local M = {}

local dir = os.getenv("HOME") .. "/.config/yazi/plugins/stl-preview.yazi"

function M:peek(job)
	local cache = ya.file_cache(job)
	if not cache then
		return
	end

	local cha = fs.cha(cache)
	if not cha or cha.len == 0 then
		local area = job.area
		local input = tostring(job.file.url)
		local tmp

		if input:lower():match("%.3mf$") then
			tmp = tostring(cache) .. ".stl"
			local conv = Command("python3"):arg({ "-I", dir .. "/3mf2stl.py", input, tmp }):stderr(Command.PIPED):output()
			if not conv or not conv.status.success then
				local msg = conv and conv.stderr or "3mf conversion failed"
				return ya.preview_widget(job, ui.Text(msg):area(job.area):wrap(ui.Wrap.YES))
			end
			input = tmp
		end

		local output, err = Command("f3d")
			:arg({
				"--no-config",
				input,
				"--output=" .. tostring(cache),
				"--rendering-backend=egl",
				"--resolution=" .. math.max(400, area.w * 10) .. "," .. math.max(300, area.h * 20),
				"--up=+Z",
				"--no-background",
				"--color=0.45,0.65,1",
				"--roughness=0.5",
				"--light-intensity=1.5",
				"--ambient-occlusion",
				"--anti-aliasing=ssaa",
				"--camera-azimuth-angle=-40",
				"--camera-elevation-angle=25",
				"--filename=false",
				"--grid=false",
				"--axis=false",
				"--verbose=quiet",
			})
			:stderr(Command.PIPED)
			:output()

		if tmp then
			os.remove(tmp)
		end

		if not output or not output.status.success then
			local msg = err and tostring(err) or (output and output.stderr) or "unknown error"
			return ya.preview_widget(job, ui.Text(msg):area(job.area):wrap(ui.Wrap.YES))
		end
	end

	ya.image_show(cache, job.area)
	ya.preview_widget(job, {})
end

function M:seek() end

return M
