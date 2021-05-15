
os.loadAPI("lib/f")
os.loadAPI("lib/button")

local reactorSide = "back"
local fluxgateSide = "left"

local targetStrength = 50
local maxTemp = 8000
local safeTemp = 3000
local lowFieldPer = 15

local activateOnCharge = true

local version = 0.1

local autoInputGate = 1
local curInputGate = 222000

local mon, monitor, monX, monY

local reactor
local fluxgate
local inputFluxgate

local ri

local action = "None since reboot"
local actioncolor = colors.gray
local emergencyCharge = false
local emergencyTemp = false

monitor = f.periphSearch("monitor")
inputFluxgate = f.periphSearch("flux_gate")
fluxgate = peripheral.wrap(fluxgateSide)
reactor = peripheral.wrap(reactorSide)

if monitor == null then
	error("No valid monitor was found")
end

if fluxgate == null then
	error("No valid fluxgate was found")
end

if reactor == null then
	error("No reactor was found")
end

monX, monY = monitor.getSize()
mon = {}
mon.monitor, mon.X, mon.Y = monitor, monX, monY

function mon.clear()
	mon.monitor.setBackgroundColor(colors.black)
	mon.monitor.clear()
	mon.monitor.setCursorPos(1,1)
	button.screen()
end

mon.clear()

function save_config()
	sw = fs.open("reactorconfig.txt", "w")
	sw.writeLine(version)
	sw.writeLine(autoInputGate)
	sw.writeLine(curInputGate)
	sw.close()
end

function load_config()
	sr = fs.open("reactorconfig.txt", "r")
	version = sr.readLine()
	autoInputGate = tonumber(sr.readLine())
	curInputGate = tonumber(sr.readLine())
	sr.close()
end

if fs.exists("reactorconfig.txt") == false then
	save_config()
else
	load_config()
end

function reset()
	term.clear()
	term.setCursorPos(1,1)
end

function reactorStatus(r)
	local tbl = {}
	if r == "running" then
		tbl = {"Online", colors.green}
	elseif r == "cold" then
		tbl = {"Offline", colors.gray}
	elseif r =="warming_up" then
		tbl = {"Charging", colors.orange}
	elseif r == "cooling" then
		tbl = {"Cooling Down", colors.blue}
	else
		tbl = {"Shutting Down", colors.red}
	end
	return tbl
end

function reactorControl()
	ri = reactor.getReactorInfo()

	if ri == nil then
		error("Reactor not setup correctly")
	end

	for k, v in pairs(ri) do
		print(k..": "..tostring(v))
	end
	print("Output Gate: ", fluxgate.getSignalLowFlow())
	print("Input Gate: ", inputFluxgate.getSignalLowFlow())

	if emergencyCharge == true then
		reactor.chargeReactor()
	end

	if ri.status == "warming_up" then
		inputFluxgate.setSignalLowFlow(900000)
		emergencyCharge = false
	end

	if emergencyTemp == true and ri.status == "stopping" and ri.temperature < safeTemp then
		reactor.activateReactor()
		emergencyTemp = false
	end

	if ri.status == "warming_up" and activateOnCharge == true then
		reactor.activateOnCharge()
	end

	if ri.status == "running" then
		if autoInputGate == 1 then
			fluxval = ri.fieldDrainRate / (1 - (targetStrength/100))
			print("Target Gate: "..fluxval)
			inputFluxgate.setSignalLowFlow(fluxval)
		else
			inputFluxgate.setSignalLowFlow(curInputGate)
		end
	end

	--safe guards
	local fuelPercent
    fuelPercent = 100 - math.ceil(ri.fuelConversion / ri.maxFuelConversion * 10000)*.01
	
	local fieldPercent
    fieldPercent = math.ceil(ri.fieldStrength / ri.maxFieldStrength * 10000)*.01

    if fuelPercent <= 10 then
    	reactor.stopReactor()
    	actioncolor = colors.red
    	action = "Fuel is low. Refuel"
    	ActionMenu()
    end

	if fieldPercent <= lowFieldPer and ri.status == "running" then
		actioncolor = colors.red
		action = "Field str < "..lowFieldPer.."%"
		ActionMenu()
		reactor.stopReactor()
		reactor.chargeReactor()
		emergencyCharge = true
	end

	if ri.temperature > maxTemp then
		reactor.stopReactor()
		actioncolor = colors.red
		action = "Reactor overheated"
		ActionMenu()
		emergencyTemp = true
	end

	sleep(0.2)
end

local MenuText = "Loading..."

function toggleReactor()
	ri = reactor.getReactorInfo()

	if ri.status == "running" then
		reactor.stopReactor()
	elseif ri.status == "stopping" then
		reactor.activateReactor()
	else
		reactor.chargeReactor()
	end
end

function ActionMenu()

	button.setButton("action", action, buttonMain, 2, 23, monX-1, 25, 0, 0, colors.red)

end

function rebootSystem()
	os.reboot()
end

function buttonControls()

	mon.clear()
	button.clearTable()

	MenuText = "CONTROLS"

	local sLength = 4+(string.len("Toggle Reactor")+1)

	button.setButton("toggle", "Toggle Reactor", toggleReactor, 4, 28, sLength, 30, 0, 0, colors.blue)

	local sLength2 = (sLength+10+(string.len("Reboot")+1))
	button.setButton("reboot", "Reboot", rebootSystem, sLength+10, 28, sLength2, 30, 0, 0, colors.blue)

	local sLength3 = 4+(string.len("Back")+1)
	button.setButton("back", "Back", buttonMain, 4, 32, sLength3, 34, 0, 0, colors.blue)
	
	button.screen()
end

function changeOutputValue(num, val)
	local cFlow = fluxgate.getSignalLowFlow()
	
	if val == 1 then
		cFlow = cFlow+num
	else
		cFlow = cFlow-num
	end
	fluxgate.setSignalLowFlow(cFlow)
end

function outputMenu()

	button.clearTable()

	MenuText = "OUTPUT"

	local sLengthX = monX-3-(string.len(">>>")+1)
	local sLength = sLengthX+string.len(">>>")+1
	button.setButton("+100,000", ">>>", changeOutputValue, sLengthX, 28, sLength, 30, 100000, 1, colors.blue)
	
	local sLengthX2 = sLengthX-3-string.len(">>")
	local sLength2 = sLengthX2+string.len(">>")+1
	button.setButton("+10,000", ">>", changeOutputValue, sLengthX2, 28, sLength2, 30, 10000, 1, colors.blue)

	local sLengthX3 = sLengthX2-3-string.len(">")
	local sLength3 = sLengthX3+string.len(">")+1
	button.setButton("+1,000", ">", changeOutputValue, sLengthX3, 28, sLength3, 30, 1000, 1, colors.blue)
	

	local nLength = 4+(string.len("<<<")+1)
	button.setButton("-100,000", "<<<", changeOutputValue, 4, 28, nLength, 30, 100000, 0, colors.blue)

	local nLength2 = nLength+2+(string.len("<<")+1)
	button.setButton("-10,000", "<<", changeOutputValue, nLength+2, 28, nLength2, 30, 10000, 0, colors.blue)

	local nLength3 = nLength2+2+(string.len("<")+1)
	button.setButton("-1,000", "<", changeOutputValue, nLength2+2, 28, nLength3, 30, 1000, 0, colors.blue)
	
	local sLength4 = 4+(string.len("Back")+1)
	button.setButton("back", "Back", buttonMain, 4, 32, sLength4, 34, 0, 0, colors.blue)
	

end


function buttonMain()

	mon.clear()
	button.clearTable()

	MenuText = "MAIN MENU"

	local sLength = 4+(string.len("Controls")+1)
	button.setButton("controls", "Controls", buttonControls, 4, 28, sLength, 30, 0, 0, colors.blue)

	local sLength2 = (sLength+13+(string.len("Output"))+1)
	button.setButton("output", "Output", outputMenu, sLength+13, 28, sLength2, 30, 0, 0, colors.blue)

	button.screen()

end

buttonMain()

function reactorInfoScreen()

	reset()
	mon.clear()

	f.draw_text(mon, 2, 38, "Made by: StormFusions  v"..version, colors.gray, colors.black)

	--Info Box
	f.draw_line(mon, 2, 22, monX-2, colors.gray)
	f.draw_line(mon, 2, 2, monX-2, colors.gray)
	
	f.draw_line_y(mon, 2, 2, 22, colors.gray)
	f.draw_line_y(mon, monX-1, 2, 22, colors.gray)
	f.draw_text(mon, 4, 2, " INFO ", colors.white, colors.black)

	--Button Box
	f.draw_line(mon, 2, 26, monX-2, colors.gray)
	f.draw_line(mon, 2, monY-1, monX-2, colors.gray)

	f.draw_line_y(mon, 2, 26, monY-1, colors.gray)
	f.draw_line_y(mon, monX-1, 26, monY-1, colors.gray)
	f.draw_text(mon, 4, 26, " "..MenuText.." ", colors.white, colors.black)

	--f.draw_text(mon, 5, 28, MenuText, colors.white, colors.black)

	ri = reactor.getReactorInfo()

	local stat = reactorStatus(ri.status)
	
	f.draw_text_lr(mon, 4, 4, 3, "Status:", stat[1], colors.white, stat[2], colors.black)
	f.draw_text_lr(mon, 4, 5, 3, "Generation:", f.format_int(ri.generationRate).." rf/t", colors.white, colors.lime, colors.black)
	
	local tempColor = colors.red
	if ri.temperature <= 5000 then tempColor = colors.green end
	if ri.temperature >= 5000 and ri.temperature <= 6500 then tempColor = colors.orange end
	f.draw_text_lr(mon, 4, 7, 3, "Temperature:", f.format_int(ri.temperature).."C", colors.white, tempColor, colors.black)

	f.draw_text_lr(mon, 4, 9, 3, "Output Gate:", f.format_int(fluxgate.getSignalLowFlow()).." rf/t", colors.white, colors.blue, colors.black)
	f.draw_text_lr(mon, 4, 10, 3, "Input Gate:", f.format_int(inputFluxgate.getSignalLowFlow()).." rf/t", colors.white, colors.blue, colors.black)
	
	local satPercent 
	satPercent = math.ceil(ri.energySaturation / ri.maxEnergySaturation * 10000)*.01

	f.draw_text_lr(mon, 4, 12, 3, "Energy Saturation:", satPercent.."%", colors.white, colors.green, colors.black)
	f.progress_bar(mon, 4, 13, monX-7, satPercent, 100, colors.green, colors.white)

	local fieldPercent, fieldColor
	fieldPercent = math.ceil(ri.fieldStrength / ri.maxFieldStrength * 10000)*.01

	fieldColor = colors.red
	if fieldPercent >= 50 then fieldColor = colors.blue end
	if fieldPercent < 50 and fieldPercent > 30 then fieldColor = colors.orange end

	if autoInputGate == 1 then
		f.draw_text_lr(mon, 4, 15, 3, "Field Strength T:"..targetStrength, fieldPercent.."%", colors.white, fieldColor, colors.black)
	else
		f.draw_text_lr(mon, 4, 15, 3, "Field Strength:", fieldPercent.."%", colors.white, fieldColor, colors.black)
	end
	f.progress_bar(mon, 4, 16, monX-7, fieldPercent, 100, fieldColor, colors.white)

	local fuelPercent, fuelColor
	fuelPercent = 100 - math.ceil(ri.fuelConversion / ri.maxFuelConversion * 10000)*.01

	fuelColor = colors.red
	if fuelPercent >=70 then fuelColor = colors.green end
	if fuelPercent < 70 and fuelPercent > 30 then fuelColor = colors.orange end

	f.draw_text_lr(mon, 4, 18, 3, "Fuel:", fuelPercent.."%", colors.white, fuelColor, colors.black)

	f.progress_bar(mon, 4, 19, monX-7, fuelPercent, 100, fuelColor, colors.white)

	sleep(1.25)

	while true do
		parallel.waitForAny(reactorInfoScreen, reactorControl, button.clickEvent)
	end

end

mon.monitor.setTextScale(0.5)

reactorInfoScreen()