ardour {
	["type"] = "EditorAction",
	name = "Split Midi Notes to Tracks 1",
	author = "Miike Broughton",
	description = [[Creates tracks as required for each note in a selected region(s).]]
}

function factory () return function ()

	local function has_value (checklist, checkvalue)
		for key,value  in ipairs ( checklist ) do
			if value == checkvalue then
				return true
			end
		end
		return false
	end

	local function compare(a,b)
		return a < b
	end

	local function sort_comma( list )
		local chan_string = "";
		table.sort ( list, compare )
		for key,value  in ipairs(list) do
			chan_string = chan_string..", "..value
		end
		return string.sub(chan_string, 3)
	end

	local function create_track(name)

		local chanFrom = ARDOUR.ChanCount(ARDOUR.DataType("midi"),1)
		local chanTo = ARDOUR.ChanCount(ARDOUR.DataType("audio"),2)
		local instru = ARDOUR.PluginInfo()

		local newMidi = 
			Session:new_midi_track(
			chanFrom,
			chanTo,
			true,
			instru,   --plugininfo
			nil, --routegroup
			nil,
			1,
			name,
			ARDOUR.PresentationInfo.max_order,
			ARDOUR.TrackMode.Normal)

		return newMidi

	end

	local sel = Editor:get_selection ()
	local sr = Session:nominal_frame_rate ()
	local start_time = Session:current_end_frame ()
	local end_time = Session:current_start_frame ()

	local channel_list = {}
	local note_list = {}

	for r in sel.regions:regionlist ():iter () do
		local midi_region = r:to_midiregion()
		if not midi_region:isnil() then
			print("Midi Region >> " .. midi_region:name())
			local model = midi_region:model()
			local notes = ARDOUR.LuaAPI.note_list(model)
			for note in notes:iter () do
				--- CHECK MIDI CHANNELS
				local mid_cha = note:channel() + 1;
				if not has_value( channel_list , mid_cha ) then
					table.insert(channel_list, mid_cha)
				end
				--- CHECK NOTES
				if not has_value( note_list , note:note() ) then
					table.insert(note_list, note:note())
				end
			end
		else
			print("AUDIO Region")
		end
	end


	local chan_string =  sort_comma(channel_list)
	local note_string = sort_comma(note_list)

	--{ type="", key="", default="", title="" },
	local d_options = {

		{ type="heading", key="tit", default="hello", title="Below are all midi channels in your selection.\nRemove the channels you want to delete, or leave as\nis to keep all." },
		{ type="entry", key="midichannels", default=chan_string, title="Keep these midi channels." },
		{ type="heading", key="tit", default="hello", title="Put a midi note below ONLY if you want to delete\neverything above or below it.  By default, everything\nbeneath it is deleted" },
		{ type="entry", key="splitpoint", default="", title="Remove all notes below this note\nBlank means ignore." },
		{ type="checkbox", key="deleteBelow", default=true, title="Delete everything below the above note.\nUnchecked = delete above." },
		{ type="heading", key="tit", default="hello", title="All notes found in the regions seleced are listed below.\nRemove the notes that you do NOT want to keep." },
		{ type="entry", key="notechannels", default=note_string, title="Keep only these notes" }
	}

	local od = LuaDialog.Dialog("Midi Split(ish)", d_options)
	local d_results = od:run()

	if d_results then
		print("Processing...")
		for r in sel.regions:regionlist ():iter () do
			local midi_region = r:to_midiregion()
			if not midi_region:isnil() then
				print("Midi Region >> " .. midi_region:name())
				local model = midi_region:model()

				-- Create an undo point
				local midi_command = model:new_note_diff_command("Midi Split(ish)")
		
				local notes = ARDOUR.LuaAPI.note_list(model)
				for note in notes:iter () do
					--- CHECK MIDI CHANNELS
					local mid_cha = note:channel() + 1;
					local delete_note = true;
					for iter_check in d_results["midichannels"]:gmatch("[^,%s]+") do
						if mid_cha == tonumber(iter_check) then
							delete_note = false
							break
						end
					end
				
					-- Only check if the channel hasn't stripped it out.
					if delete_note == false then
						delete_note = true
						-- INDIVIDUAL NOTE or RANGE delete check
						if d_results["splitpoint"] == "" then
 							-- CHECK NOTES.
							for iter_check in d_results["notechannels"]:gmatch("[^,%s]+") do
								if note:note() == tonumber(iter_check) then
									delete_note = false
									break
								end
							end
						else
							-- Above or below
							if d_results["deleteBelow"] then
								-- Check for note BELOW and KEEP
								if note:note() >= tonumber(d_results["splitpoint"]) then
									delete_note = false
								end
							else
								-- Check for note ABOVE and KEEP
								if note:note() <= tonumber(d_results["splitpoint"]) then
									delete_note = false
								end
							end
						end
					end

					-- Perform the actual delete
					if delete_note then
						midi_command:remove(note)
					end
	
				end
				
				--Commit!
				model:apply_command(Session, midi_command)
			end
		end

			end

	print("Finished")


end end -- function factory
