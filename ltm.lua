--[[
-- inav FrSky Telemetry to LTM
-- Designed for the Radiomaster TX16S UART set to 'LUA' and invoked via
-- either a Global or Special Function
--
-- LTM can be used in INAV compatible ground stations such as mwp, eagui or mw4i
--
-- Licence : GPL 3 or later
--
-- (c) Jonathan Hudson 2020
  ]]--

local D = {}
local lastt = 0
-- Debugging
local LOGGER = false

local function dolog(str)
   if LOGGER then
      if D.fh == nil then
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
	 D.fh = io.open(s,"w")
      end
      if D.fh ~= nil then
	 io.write(D.fh, str, "\n")
      end
   end
   if D.sim then
      print(str)
   end
end

local function dump(binstr)
   local s=''
   for i = 1, string.len(binstr), 1 do
      s = s..string.format("%02x ", string.byte(binstr, i))
   end
   dolog(s)
end

local function t2s(t)
   local s=''
   for i=1,#t do
      s = s..string.char(t[i])
   end
   dump(s)
   return s
end

local function crc(msg)
   local c = 0
   for i = 4, #msg do
      c = bit32.bxor(msg[i],c)
   end
   return c
end

local function s32(val)
   b={}
   b[0] = bit32.band(val,0xFF)
   b[1] = bit32.band(bit32.rshift(val,8) ,0xFF)
   b[2] = bit32.band(bit32.rshift(val,16) ,0xFF)
   b[3] = bit32.band(bit32.rshift(val,24) ,0xFF)
   return b
end

local function s16(val)
   b={}
   b[0] = bit32.band(val,0xFF)
   b[1] = bit32.band(bit32.rshift(val,8) ,0xFF)
   return b
end

local function ltm_gframe()
   local ilat = math.floor(D.lat*1e7)
   local ilon = math.floor(D.lon*1e7)
   local ispd = math.floor(D.spd)
   local ialt = math.floor(D.alt*100)
   local sbyte = D.nfix + (D.nsats * 4) -- FIXME bitops
   local msg = {}

   if ispd < 0 then
      ispd = 0
   end

   msg[1] = 0x24
   msg[2] = 0x54
   msg[3] = string.byte('G')
   local b = s32(ilat)
   msg[4] = b[0]
   msg[5] = b[1]
   msg[6] = b[2]
   msg[7] = b[3]
   b = s32(ilon)
   msg[8] = b[0]
   msg[9] = b[1]
   msg[10] = b[2]
   msg[11] = b[3]
   msg[12] = bit32.band(ispd,0xff) -- 12
   b =s32(ialt)
   msg[13] = b[0]
   msg[14] = b[1]
   msg[15] = b[2]
   msg[16] = b[3]
   msg[17] = bit32.band(sbyte,0xff) -- 17
   msg[18] = crc(msg)
   local ltm = t2s(msg)
   serialWrite(ltm)
end

local function ltm_sframe(status)
   local vb = math.floor(D.volts*1000)
   local rssi = math.floor(255*D.rssi/100)
   local ispd = math.floor(D.spd)

   if ispd < 0 then
      ispd = 0
   end

   local msg = {}
   msg[1] = 0x24
   msg[2] = 0x54
   msg[3] = string.byte('S')
   local b = s16(vb)
   msg[4] = b[0]
   msg[5] = b[1]
   b = s16(D.mah)
   msg[6] = b[0]
   msg[7] = b[1]
   msg[8] = bit32.band(rssi,0xff)
   msg[9] = bit32.band(ispd,0xff)
   msg[10] = bit32.band(status,0xff)
   msg[11] = crc(msg)
   local ltm = t2s(msg)
   serialWrite(ltm)
end

local function ltm_oframe()
   local ilat = math.floor(D.hlat*1e7)
   local ilon = math.floor(D.hlon*1e7)
   local msg = {}
   msg[1] = 0x24
   msg[2] = 0x54
   msg[3] = string.byte('O')
   local b = s32(ilat)
   msg[4] = b[0]
   msg[5] = b[1]
   msg[6] = b[2]
   msg[7] = b[3]
   b = s32(ilon)
   msg[8] = b[0]
   msg[9] = b[1]
   msg[10] = b[2]
   msg[11] = b[3]
   b = s32(ilon)
   msg[8] = b[0]
   msg[9] = b[1]
   msg[10] = b[2]
   msg[11] = b[3]
   msg[12] = 0
   msg[13] = 0
   msg[14] = 0
   msg[15] = 0
   msg[16] = bit32.band(1,0xff)
   msg[17] = bit32.band(D.nfix,0xff)
   msg[18] = crc(msg)
   local ltm = t2s(msg)
   serialWrite(ltm)
end

local function ltm_aframe()
   local msg = {}
   msg[1] = 0x24
   msg[2] = 0x54
   msg[3] = string.byte('A')
   local b = s16(D.pitch)
   msg[4] = b[0]
   msg[5] = b[1]
   b = s16(D.roll)
   msg[6] = b[0]
   msg[7] = b[1]
   b = s16(D.hdg)
   msg[8] = b[0]
   msg[9] = b[1]
   msg[10] = crc(msg)
   local ltm = t2s(msg)
   serialWrite(ltm)
end

local function ltm_xframe()
   local msg = {}
   msg[1] = 0x24
   msg[2] = 0x54
   msg[3] = string.byte('X')
   b = s16(D.hdop)
   msg[4] = b[0]
   msg[5] = b[1]
   msg[6] = bit32.band(0,0xff)
   msg[7] = bit32.band(D.xcount,0xff)
   msg[8] = bit32.band(0,0xff)
   msg[9] = bit32.band(0,0xff)
   msg[10] = crc(msg)
   local ltm = t2s(msg)
   serialWrite(ltm)
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
   D.alt = getValue(D.alt_id) or 0
   D.spd = getValue(D.spd_id) or 0

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

   if bit32.band(gfix, 2) then
      dolog("SAT_ID SET home with have_home = "..tostring(D.have_home))
      if D.armed == 1 and D.have_home == false then
	 D.hlat = D.lat
	 D.hlon = D.lon
	 dolog("Setting home "..D.hlat.." "..D.hlon)
	 D.have_home = true
      end
   end
--[[
   if bit32.band(gfix, 4) then
      dolog("SAT_ID RESET home with have_home = "..tostring(D.have_home))

      if D.have_home == true then
	 D.hlat = D.lat
	 D.hlon = D.lon
      end
   end
]]--
   local hdp = (val % 1000)/100
   D.hdop = 550 - (hdp * 50)

   dolog(string.format("GFrame: Lat %.6f Lon %.6f Alt %.2f Spd %.1f fix %d sats %d hdop %d",
		       D.lat, D.lon, D.alt, D.spd, D.nfix, D.nsats, D.hdop))
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

   if bit32.band(modeU, 4) == 4 then
      armed = 1
   else
      armed = 0
      if D.armed == 1 then
	 D.have_home = false
      end
   end
   if D.armed ~= armed then
      dolog("Armed State change "..armed)
   end
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

   if bit32.band(modeH, 2) == 2 then
      ltmflags = 8 -- Alt Hold
   elseif bit32.band(modeH, 4) == 4 then
      ltmflags = 9 -- PH
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

   local status = armed + failsafe + (ltmflags * 4)
   return status
end

local function send_sframe()
   D.volts = getValue(D.volt_id)
   D.mah = getValue(D.curr_id) or 0
   local status = get_ltm_status()
   local ival = getValue(D.mode_id)
   dolog(string.format("SFrame: Volts %.1f mah %.1f rssi %d air %1.f mode %d status %02x",
		       D.volts, D.mah, D.rssi, D.spd, ival, status))
   ltm_sframe(status)
end

local function send_aframe()
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
   dolog(string.format("AFrame: pitch %d roll %d heading %d", D.pitch, D.roll, D.hdg))
   ltm_aframe()
end

local function send_xframe()
   dolog(string.format("XFrame: hdop %d xcount %d",  D.hdop, D.xcount))
   ltm_xframe()
   D.xcount = (1+D.xcount) % 256
end

local function send_nframe()
   dolog("Nframe")
end

local function send_oframe()
   dolog(string.format("Oframe: %.6f %.6f sats %d fix %d home %s", D.hlat, D.hlon, D.nsats, D.nfix,D.have_home))
   ltm_oframe()
end

-- Runtime functions --

local function init()
   local v, r, m, i, e = getVersion()
   lastt = getTime()
   D = {
      volt_id = getTelemetryId("VFAS"),
      sat_id = getTelemetryId("Tmp2"),
      mode_id = getTelemetryId("Tmp1"),
      alt_id = getTelemetryId("Alt"),
      gps_id = getTelemetryId("GPS"),
      hdg_id = getTelemetryId("Hdg"),
      curr_id = getTelemetryId("Curr"),
      spd_id = getTelemetryId("VSpd"),
      have_home = false,
      lat  = 0,
      lon = 0,
      alt = 0,
      spd = 0,
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
   }
   if D.gps_id > -1 then
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
      if string.sub(r, -4) == "simu" then
	 D.sim = true
      end
      dolog("vid".." "..D.volt_id)
      dolog("sat".." "..D.sat_id)
      dolog("mode".." "..D.mode_id)
      dolog("alt".." "..D.alt_id)
      dolog("gps".." "..D.gps_id)
      dolog("hdr".." "..D.hdg_id)
      dolog("curr".." "..D.curr_id)
   end
end

-- Main
local function run(event)
   if D.gps_id > -1 then
      local timenow = getTime()
      local tdif = timenow - lastt
      if tdif > 9 then
	 lastt = timenow
	 local rssi = getRSSI()
	 if rssi ~= nil then
	    D.rssi = rssi
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
		  send_nframe()
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
