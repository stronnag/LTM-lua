--[[
-- inav FrSky / CRSF Telemetry to LTM
-- Designed for the Radiomaster TX16S UART set to 'LUA' and invoked via
-- either a Global or Special Function
--
-- LTM can be used in INAV compatible ground stations such as mwp, ezgui or
--  mission planner for inav, as well as antenna trackers e.g u360gts
--
-- Licence : GPL 3 or later
--
-- (c) Jonathan Hudson 2020
-- https://github.com/stronnag/LTM-lua/
--
]]--

local S={}

-- Functionality
-- If you're just using this for an antenna tracker (vice GCS), then you probably don't
-- need the S, O and X frames. So change the line below from
--
-- S.onlyTracker = false
--  to
-- S.onlyTracker = true
--
S.onlyTracker = false

-- Debugging
-- Don't touch this unless you appreciate the consequences, particularly when not
-- in the simulator
-- S.LOGGER = true

-- 2.3.12 and later
S.baudrate = 115200

return S
