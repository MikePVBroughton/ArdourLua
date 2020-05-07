# ArdourLua
Lua scripts written by me for Ardour 5.12.

Sracthpad

Add a midi note:

local midi_model = midi_region:model()
local notelist = ARDOUR.LuaAPI.note_list (midi_model)
local midi_command = midi_model:new_note_diff_command ("Description of Change")
for note in notelist:iter () do
  local newnote = ARDOUR.LuaAPI.new_noteptr (note:channel(), note:time (), note:length (), note:note(), note:velocity())
  midi_command:remove (note)
  midi_command:add (newnote)
end
midi_model:apply_command (Session, midi_command)


