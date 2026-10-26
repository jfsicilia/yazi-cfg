--- Forces a full repaint: hides yazi to the secondary screen and restores it.
--- Fixes cells blanked behind the renderer's back (e.g. after sixel images).

local function entry()
	local permit = ui.hide()
	permit:drop()
end

return { entry = entry }
