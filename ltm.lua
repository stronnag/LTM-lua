--[[
-- inav FrSky Telemetry to LTM
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

-- User editable settings -- see LTM/config.lua
local S = {}
-- Common data
local D = {}
-- CRSF specific data and functions
local C = {}

local lastt = 0

local function openlog()
   local dt = getDateTime()
   local s = ''
   if type(dt) == "table" then
      s = string.format("/LOGS/%04d%02d%02d%02d%02d%02d.txt",
			dt.year, dt.mon, dt.day, dt.hour,dt.min,dt.sec)
   else
      s = "/LOGS/ltmtst.dat"
   end
   if D.sim then
      print("Open "..s)
   end
   fh = io.open(s,"wb")
   return fh
end

local function dolog(str)
   if D.sim then
      print(str)
   end
end

local function mlog(ltm)
   if S.LOGGER then
      D.fh = D.fh or openlog()
      io.write(D.fh, ltm)
   end
end

local function crc(binstr)
   c= 0
   for i = 1, string.len(binstr), 1 do
      c = bit32.bxor(c, string.byte(binstr, i))
   end
   return c
end

local function s16(val)
   return string.char( bit32.band(val,0xFF)) .. string.char(bit32.band(bit32.rshift(val,8) ,0xFF))
end

local function s32(val)
   return string.char( bit32.band(val,0xFF)) .. string.char(bit32.band(bit32.rshift(val,8) ,0xFF)) .. string.char(bit32.band(bit32.rshift(val,16) ,0xFF)) ..  string.char(bit32.band(bit32.rshift(val,24) ,0xFF))
end

local function ltm_gframe()
   local ilat = math.floor(D.lat*1e7)
   local ilon = math.floor(D.lon*1e7)
   local ispd = math.floor(D.gspd)
   local ialt = math.floor(D.alt*100)
   local sbyte = bit32.bor(D.nfix, bit32.lshift(D.nsats,2))
   if ispd < 0 then
      ispd = 0
   end
   local m = s32(ilat)
   m = m .. s32(ilon)
   m = m .. string.char(bit32.band(ispd,0xFF))
   m = m .. s32(ialt)
   m = m .. string.char(bit32.band(sbyte,0xFF))
   m = m .. string.char(crc(m))
   m = "$TG"..m
   serialWrite(m)
   mlog(m)
end

local function ltm_sframe(status)
   local vb = math.floor(D.volts*1000)
   local rssi = math.floor(255*D.rssi/100)
   local ispd

   ispd = math.floor(D.vspd)
   local ialt = math.floor(D.alt*100)
   if ispd < 0 then
      ispd = math.floor(D.gspd)
      if ispd < 0 then
	 ispd = 0
      end
   end
   local m = s16(vb)
   m = m .. s16(D.mah)
   m = m .. string.char(bit32.band(rssi,0xff))
   m = m .. string.char(bit32.band(ispd,0xff))
   m = m .. string.char(bit32.band(status,0xff))
   m = m .. string.char(crc(m))
   m = "$TS"..m
   serialWrite(m)
   mlog(m)
end

local function ltm_oframe()
   local ilat = math.floor(D.hlat*1e7)
   local ilon = math.floor(D.hlon*1e7)
   local m = s32(ilat)
   m = m .. s32(ilon)
   m = m .. "\000\000\000\000\001"
   m = m .. string.char(bit32.band(D.nfix,0xff))
   m = m .. string.char(crc(m))
   m = "$TO"..m
   serialWrite(m)
   mlog(m)
end

local function ltm_aframe()
   local m = s16(D.pitch)
   m = m .. s16(D.roll)
   m = m .. s16(D.hdg)
   m = m .. string.char(crc(m))
   m = "$TA"..m
   serialWrite(m)
   mlog(m)
end

local function ltm_xframe()
   local m = s16(D.hdop)
   m = m .. '\000'
   m = m .. string.char(bit32.band(D.xcount,0xff))
   m = m .. "\000\000"
   m = m .. string.char(crc(m))
   m = "$TX"..m
   serialWrite(m)
   mlog(m)
end

local function getTelemetryId(n)
   local field = getFieldInfo(n)
   return field and field.id or -1
end

local function send_gframe()
   local gps = getValue(D.gps_id)
   if type(gps) == "table" then
      D.lat = gps.lat
      D.lon = gps.lon
   end
   if D.crsf then
      C.alt_speed(D)
   else
      D.alt = getValue(D.alt_id) or 0
      D.gspd = getValue(D.gspd_id) or 0
      D.vspd = getValue(D.vspd_id) or 0
      -- knots to m/s
      D.gspd = D.gspd * 0.51444
      D.vspd = D.vspd * 0.51444
   end

   if D.crsf then
      C.get_sat_info(D)
   else
      local val = getValue(D.sat_id) or 0
      D.nsats = val % 100
      local gfix = val / 1000
      if bit32.band(gfix, 1) then
	 if D.nsats > 4 then
	    D.nfix = 3
	 elseif D.nsats > 0 then
	    D.nfix = 1
	 else
	    D.nfix = 0
	 end
      end
      local hdp = (val % 1000)/100
      D.hdop = 550 - (hdp * 50)
      if bit32.band(gfix, 2) then
	 if D.armed == 1 and D.have_home == false then
	    D.hlat = D.lat
	    D.hlon = D.lon
	    D.have_home = true
	 end
      end
   end
   dolog(string.format("\nGFrame: Lat %.6f Lon %.6f Alt %.2f Spd %.1f fix %d sats %d hdop %d",		       D.lat, D.lon, D.alt, D.gspd, D.nfix, D.nsats, D.hdop))
   ltm_gframe()
end

local function get_ltm_status()
   local armed = 0
   local failsafe = 0
   local ltmflags = 0

   local ival = getValue(D.mode_id)
   local modeU = math.floor(ival % 10)
   local modeT = math.floor((ival % 100) / 10)
   local modeH = math.floor((ival % 1000) / 100)
   local modeK = math.floor((ival % 10000) / 1000)
   local modeJ = math.floor(ival / 10000)

   if bit32.band(modeU, 4) == 4 then
      armed = 1
   else
      armed = 0
      if D.armed == 1 then
	 D.have_home = false
      end
   end

   if D.armed ~= armed then dolog("Armed State change "..armed)  end

   D.armed = armed

   if modeT == 0 then
      ltmflags = 4 -- Acro
   elseif modeT == 1 then
      ltmflags = 2 -- Angle
   elseif modeT == 2 then
      ltmflags = 3 -- Horizon
   elseif modeT == 4 then
      ltmflags = 0 -- Manual
   end

   if bit32.band(modeH, 4) == 4 then
      ltmflags = 9 -- PH
   elseif bit32.band(modeH, 2) == 2 then
      ltmflags = 8 -- Alt Hold
   end

   if modeK == 1 then
      ltmflags = 13 -- RTH
   elseif modeK == 2 then
      ltmflags = 10 -- WP
   elseif modeK == 8 then
      ltmflags = 18 -- Cruise
   end

   if modeJ == 4 then
      failsafe = 2
   end
   local status = bit32.bor(armed, failsafe, bit32.lshift(ltmflags,2))
   return status
end

local function send_sframe()
   local status = 0
   D.volts = getValue(D.volt_id) or 0
   D.mah = getValue(D.curr_id) or 0
   if D.crsf then
      status = C.get_status_info(D)
   else
      status = get_ltm_status()
   end
   dolog(string.format("SFrame: Volts %.1f mah %.1f rssi %d air %1.f status %02x", D.volts, D.mah, D.rssi, D.vspd, status))
   ltm_sframe(status)
end

local function send_aframe()
   if D.crsf then
      C.get_attitude(D)
      -- set D.pitch, D.roll, D.hdg
   else
      if D.useacc then
	 local accx = getValue(D.accx_id) or 0
	 local accy = getValue(D.accy_id) or 0
	 local accz = getValue(D.accz_id) or 0
	 D.pitch = math.deg(math.atan2(accx * (accz >= 0 and -1 or 1), math.sqrt(accy * accy + accz * accz)))
	 D.roll = math.deg(math.atan2(accy * (accz >= 0 and 1 or -1), math.sqrt(accx * accx + accz * accz)))
      else
	 local v_pitch = getValue(D.pitch_id)
	 local v_roll = getValue(D.roll_id)
	 D.pitch = (math.abs(v_roll) > 900 and -1 or 1) * (270 - v_pitch * 0.1) % 180
	 D.roll = (270 - data.roll * 0.1) % 180
      end
   end
   dolog(string.format("\nAFrame: pitch %d roll %d heading %d", D.pitch, D.roll, D.hdg))
   ltm_aframe()
end

local function send_xframe()
   dolog(string.format("XFrame: hdop %d xcount %d",  D.hdop, D.xcount))
   ltm_xframe()
   D.xcount = (1+D.xcount) % 256
end

local function send_nframe()
--   dolog("Nframe")
end

local function send_oframe()
   dolog(string.format("Oframe: %.6f %.6f sats %d fix %d home %s", D.hlat, D.hlon, D.nsats, D.nfix,D.have_home))
   ltm_oframe()
end

-- Runtime functions --

local function init()
   local vers, radiov, rmaj, rmin, rrev = getVersion()
   lastt = getTime()
   D = {
      volt_id = getTelemetryId("VFAS"),
      sat_id = getTelemetryId("Tmp2"),
      mode_id = getTelemetryId("Tmp1"),
      alt_id = getTelemetryId("Alt"),
      gps_id = getTelemetryId("GPS"),
      hdg_id = getTelemetryId("Hdg"),
      curr_id = getTelemetryId("Curr"),
      gspd_id = getTelemetryId("GSpd"),
      vspd_id = getTelemetryId("VSpd"),
      have_home = false,
      lat  = 0,
      lon = 0,
      alt = 0,
      gspd = 0,
      vspd = 0,
      nsats = 0,
      nfix = 0,
      hlat = 0,
      hlon = 0,
      hdg = 0,
      volts = 0,
      mah = 0,
      xcount = 0,
      mcount = 0,
      roll = 0,
      pitch = 0,
      hdop = 999,
      sim = false,
      armed = 0,
      crsf = false,
      fm_id = getTelemetryId("FM")
   }

   if string.sub(radiov, -4) == "simu" then
      D.sim = true
   end

   S = loadScript("/SCRIPTS/FUNCTIONS/LTM/config.lua")
   dolog("Tracker only " .. string.format("%s",S.onlyTracker))
   if rmaj >= 2 and rmin >= 3 and rrev >= 12 then
      if S.baudrate > 0 then
	 setSerialBaudrate(S.baudrate)
      end
   end
   -- Testing Crossfire
   -- if D.sim then D.fm_id = 1 end

   if D.fm_id > -1 then
      D.crsf = true
      C = loadScript("/SCRIPTS/FUNCTIONS/LTM/crsf.lua")(D,getTelemetryId)
      dolog("Loaded CROSSFIRE")
   else
      local pitchRoll = ((getTelemetryId("0430") > -1 or getTelemetryId("0008") > -1 or getTelemetryId("Ptch") > -1) and (getTelemetryId("0440") > -1 or getTelemetryId("0020") > -1 or getTelemetryId("Roll") > -1))
      if pitchRoll then
	 local pitchSensor = getTelemetryId("Ptch") > -1 and "Ptch" or (getTelemetryId("0430") > -1 and "0430" or "0008")
	 local rollSensor = getTelemetryId("Roll") > -1 and "Roll" or (getTelemetryId("0440") > -1 and "0440" or "0020")
	 D.pitch_id = getTelemetryId(pitchSensor)
	 D.roll_id = getTelemetryId(rollSensor)
      else
	 D.accx_id = getTelemetryId("AccX")
	 D.accy_id = getTelemetryId("AccY")
	 D.accz_id = getTelemetryId("AccZ")
	 D.useacc = true
      end
      dolog("Using Smartport")
   end
   dolog("vid  "..D.volt_id)
   dolog("sat  "..D.sat_id)
   dolog("mode "..D.mode_id)
   dolog("alt "..D.alt_id)
   dolog("gps "..D.gps_id)
   dolog("hdr "..D.hdg_id)
   dolog("curr "..D.curr_id)
end

-- Main
local function run(event)
   if D.gps_id > -1 then
      local timenow = getTime()
      local tdif = timenow - lastt
      if tdif > 9 then
	 lastt = timenow
	 local rssi,r0,r1
	    rssi, r0, r1 = getRSSI()
	 if rssi ~= nil then
	    D.rssi = rssi
	    if S.onlyTracker then
	       send_gframe()
	       send_aframe()
	    else
	       send_aframe()
	       if (D.mcount % 2) == 0 then
		  send_gframe()
	       else
		  send_sframe()
		  if D.mcount == 1 then
		     send_oframe()
		  elseif D.mcount == 5 then
		     send_xframe()
		  else
		     send_nframe() -- noop for now
		  end
	       end
	    end
	    D.mcount = (D.mcount + 1) % 10
	 end
      end
   end
   collectgarbage()
  return 0
end

return { init=init, run=run}
