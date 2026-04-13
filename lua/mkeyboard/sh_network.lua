--[[
    When you press/release a note, those events aren't transmitted to the server
    (and broadcasted to nearby players) right away. We keep those events on a buffer,
    and then periodically send those buffered events in one network message.

    Here, we define the amount of time between each transmission.

    Shorter values reduces latency (so other players hear your notes sooner),
    but increases network usage.

    Longer values reduce network usage, but might cause some events to be dropped,
    since there's a limit to how many events one transmission can store.
]]
MKeyboard.TRANSMIT_BUFFER_INTERVAL = 0.3 -- In seconds

-- Max. number of note events per net message.
-- Must stay within the limits of net.WriteUInt.
MKeyboard.MAX_NOTE_EVENTS = 60

-- The amount of bits used to store event count/active note count.
-- This must accomodate the `MKeyboard.MAX_NOTE_EVENTS` number.
local NOTE_COUNT_BITS = 6
local Clamp = math.Clamp

do
    local WriteUInt = net.WriteUInt
    local WriteBool = net.WriteBool
    local WriteFloat = net.WriteFloat

    function MKeyboard.WriteEvents( events )
        local eventCount = Clamp( #events, 0, MKeyboard.MAX_NOTE_EVENTS )
        local event, isNoteOn

        WriteUInt( eventCount, NOTE_COUNT_BITS )

        for i = 1, eventCount do
            event = events[i]
            isNoteOn = event.instrumentIndex ~= nil

            WriteFloat( event.time )
            WriteUInt( event.note, 7 )
            WriteUInt( event.channelIndex, 4 )
            WriteBool( isNoteOn )

            if isNoteOn then
                WriteUInt( event.instrumentIndex, 7 )
                WriteUInt( event.velocity, 7 )
                WriteBool( event.isAutomated )
            else
                WriteFloat( Clamp( event.additionalReleaseTime or 0, 0, 0.8 ) )
            end
        end
    end
end

do
    local CurTime = CurTime
    local ReadUInt = net.ReadUInt
    local ReadBool = net.ReadBool
    local ReadFloat = net.ReadFloat

    local MIDI_CHANNEL_ID_MIN = MKeyboard.MIDI_CHANNEL_ID_MIN
    local MIDI_CHANNEL_ID_MAX = MKeyboard.MIDI_CHANNEL_ID_MAX

    function MKeyboard.ReadEvents()
        local eventCount = net.ReadUInt( NOTE_COUNT_BITS )
        eventCount = Clamp( eventCount, 0, MKeyboard.MAX_NOTE_EVENTS )

        local t = CurTime()
        local maxDeviation = MKeyboard.TRANSMIT_BUFFER_INTERVAL * 10

        local events = {}
        local event, isNoteOn

        for i = 1, eventCount do
            event = {
                time = Clamp( ReadFloat(), t - maxDeviation, t + maxDeviation ),
                note = ReadUInt( 7 ),
                channelIndex = Clamp( ReadUInt( 4 ), MIDI_CHANNEL_ID_MIN, MIDI_CHANNEL_ID_MAX ),
            }

            isNoteOn = ReadBool()

            if isNoteOn then
                event.instrumentIndex = ReadUInt( 7 )
                event.velocity = ReadUInt( 7 )
                event.isAutomated = ReadBool()
            else
                event.additionalReleaseTime = ReadFloat()
            end

            events[i] = event
        end

        return events
    end
end

-- Workaround for the button hooks that only run serverside on single-player
if not game.SinglePlayer() then return end

if SERVER then
    util.AddNetworkString( "mkeyboard.button_event" )

    hook.Add( "PlayerButtonDown", "MKeyboard.ButtonDownWorkaround", function( ply, button )
        net.Start( "mkeyboard.button_event", true )
        net.WriteUInt( button, 8 )
        net.WriteBool( true )
        net.Send( ply )
    end )

    hook.Add( "PlayerButtonUp", "MKeyboard.ButtonUpWorkaround", function( ply, button )
        net.Start( "mkeyboard.button_event", true )
        net.WriteUInt( button, 8 )
        net.WriteBool( false )
        net.Send( ply )
    end )
end

if CLIENT then
    net.Receive( "mkeyboard.button_event", function()
        local button = net.ReadUInt( 8 )
        local pressed = net.ReadBool()

        if IsValid( MKeyboard.entity ) then
            if pressed then
                MKeyboard:OnButtonPress( button )
            else
                MKeyboard:OnButtonRelease( button )
            end
        end
    end )
end
