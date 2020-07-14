local D,getTelemetryId = ...
local C={}

C.lastt = 0
D.sat_id = getTelemetryId("Sats")
D.rssi_id = getTelemetryId("1RSS")
D.pitch_id = getTelemetryId("Ptch")
D.roll_id = getTelemetryId("Roll")
D.hdg_id = getTelemetryId("Yaw")
D.thr_id = getTelemetryId("Thr")
D.curr_id = getTelemetryId("Capa")
D.volt_id = getTelemetryId("RxBt")

local function calc_speed(D)
   local spd = 0
   local tdiff = 0
   local now = getTime()
   if C.lastt > 0  and C.llat ~= 0 and C.llon ~= 0 then
      tdiff = now - C.lastt
      if tdiff > 0 then
	 -- Flat earth
	 local x = math.abs(math.rad(D.lon-C.llon) * math.cos(math.rad(D.lat)))
	 local y = math.abs(math.rad(D.lat - C.llat))
	 local d = math.sqrt(x*x+y*y) * 6371009.0
	 spd = d / tdiff
      end
   end
   C.lastt = now
   C.llat = D.lat
   C.llon = D.lon
   return spd
end

function C.get_status_info(D)
   local fm = getValue(D.fm_id)
   local armed = 1 -- assume armed for now
   local fs = 0
   local ltmmode = 0

   if fm == "0" then
      local thr = getValue(D.thr_id)
      if thr < -800 then
	 armed = 0
      end
   elseif fm == "OK" or fm == "WAIT" or fm == "!ERR" then
      armed = 0
   elseif fm == "ACRO" or fm == "AIR" then
      ltmmode = 4
   elseif fm == "ANGL" or fm == "STAB" then
      ltmmode = 2
   elseif fm == "HOR" then
      ltmmode = 3
   elseif fm == "MANU" then
      ltmmode = 0
   elseif fm == "AH" then
      ltmmode = 8
   elseif fm == "HOLD" then
      ltmmode = 9
   elseif fm == "CRS" or fm == "3CRS" then
      ltmmode = 18
   elseif fm == "WP" then
      ltmmode = 10
   elseif fm == "RTH" then
      ltmmode = 13
   elseif fm == "!FS!" then
      fs = 2
   end

   local status = bit32.bor(armed, fs, bit32.lshift(ltmflags,2))
   return status
end

function  C.alt_speed(D)
   D.alt = getValue(D.alt_id)
   D.gspd = calc_speed(D)
   D.vspd = D.gspd
end

function C.get_sat_info(D)
   D.nsats = getValue(D.sat_id)
   if D.nsats > 5 then
      D.nfix = 3
      D.hdop = (3.3 - D.nfix/12.0) * 100
      if D.hdop < 50 then
	 D.hdop = 50
      end
   elseif ns > 0 then
      D.nfix = 1
      D.hdop = 800
   else
      D.nfix = 0
      D.hdop = 999
   end
end

function C.get_attitude(D)
   D.pitch = 10 * math.deg(getValue(D.pitch_id))
   D.roll = 10 * math.deg(getValue(D.roll_id))
   D.hdg = math.deg(getValue(D.hdg_id) < 0 and getValue(D.hdg_id) + 6.55 or getValue(D.hdg_id))
end

return C
