os.loadAPI("lib/f")
os.loadAPI("lib/button")

local targetStrength = 20

local maxTemp = 8000
local safeTemp = 3000
local lowFieldPer = 10

local targetGeneration = 4000000000

local autoOutputGate = true
local outputRampRate = 0.10
local outputMinStep = 1000000

local reactorPowerMultiplier = 1600

local normalStartupInput = 1350000
local scaledStartupInput = normalStartupInput * reactorPowerMultiplier

local startupInputLimit = 2140000000
local reactorStartupInput = math.min(scaledStartupInput, startupInputLimit)

local activateOnCharge = true

local version = 0.4

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

local outputTarget = 0
local lastAutoOutput = 0

monitor = f.periphSearch("monitor")
reactor = f.periphSearch("draconic_reactor")

function detectFlowGates()
    local gates = { peripheral.find("flow_gate") }

    if #gates < 2 then
        error("Error: Less than 2 flow gates detected!")
        return nil, nil
    end

    print("Please set input flow gate to **10 RF/t** manually.")

    local inputGate, outputGate
    local inputName, outputName

    while not inputGate do
        sleep(1)

        for _, name in pairs(peripheral.getNames()) do
            if peripheral.getType(name) == "flow_gate" then
                local gate = peripheral.wrap(name)
                local setFlow = gate.getSignalLowFlow()

                if setFlow == 10 then
                    inputGate = gate
                    inputName = name
                    print("Detected input gate:", name)
                elseif not outputGate then
                    outputGate = gate
                    outputName = name
                end
            end
        end
    end

    if not outputGate then
        print("Error: Could not identify output gate!")
        return nil, nil
    end

    return inputGate, outputGate, inputName, outputName
end

function saveFlowGateNames(inputName, outputName)
    local file = fs.open("flowgate_names.txt", "w")

    file.writeLine(inputName)
    file.writeLine(outputName)

    file.close()

    print("Saved flow gate names for reboot!")
end

function loadFlowGateNames()
    if not fs.exists("flowgate_names.txt") then
        print("No saved flow gate names found! Running detection again...")
        return nil, nil, nil, nil
    end

    local file = fs.open("flowgate_names.txt", "r")

    local inputName = file.readLine()
    local outputName = file.readLine()

    file.close()

    print("Loaded saved flow gate names:", inputName, outputName)

    if peripheral.isPresent(inputName) and peripheral.isPresent(outputName) then
        return peripheral.wrap(inputName),
               peripheral.wrap(outputName),
               inputName,
               outputName
    else
        print("Saved peripherals not found! Running detection again...")
        return nil, nil, nil, nil
    end
end

function setupFlowGates()
    local inputFluxgate, outputFluxgate, inputName, outputName =
        loadFlowGateNames()

    if not inputFluxgate or not outputFluxgate then
        inputFluxgate, outputFluxgate, inputName, outputName =
            detectFlowGates()

        if inputFluxgate and outputFluxgate then
            saveFlowGateNames(inputName, outputName)
        else
            error(
                "Flow gate setup failed! " ..
                "Make sure to set the input flow gate to 10 before running the script again!"
            )

            return nil, nil
        end
    end

    return inputFluxgate, outputFluxgate
end

inputFluxgate, fluxgate = setupFlowGates()

if monitor == nil then
    error("No valid monitor was found")
end

if fluxgate == nil then
    error("No valid flow gate was found")
end

if inputFluxgate == nil then
    error("No input flow gate was found. Please put the low signal value to 10")
end

if reactor == nil then
    error("No reactor was found")
end

monX, monY = monitor.getSize()

mon = {}
mon.monitor, mon.X, mon.Y = monitor, monX, monY

f.firstSet(mon)

function mon.clear()
    mon.monitor.setBackgroundColor(colors.black)
    mon.monitor.clear()
    mon.monitor.setCursorPos(1, 1)
    button.screen()
end

function save_config()
    local sw = fs.open("reactorconfig.txt", "w")

    sw.writeLine(autoInputGate)
    sw.writeLine(curInputGate)

    sw.close()
end

function load_config()
    local sr = fs.open("reactorconfig.txt", "r")

    autoInputGate = tonumber(sr.readLine())
    curInputGate = tonumber(sr.readLine())

    sr.close()

    if autoInputGate == nil then
        autoInputGate = 1
    end

    if curInputGate == nil then
        curInputGate = 222000
    end
end

if fs.exists("reactorconfig.txt") == false then
    save_config()
else
    load_config()
end

function reset()
    term.clear()
    term.setCursorPos(1, 1)
end

function reactorStatus(r)
    local statusTable = {
        running = {"Online", colors.green},
        cold = {"Offline", colors.gray},
        warming_up = {"Charging", colors.orange},
        cooling = {"Cooling Down", colors.blue},
        stopping = {"Shutting Down", colors.red}
    }

    return statusTable[r] or statusTable["stopping"]
end

local lastTerminalValues = {}

function drawTerminalText(x, y, label, newValue)
    local key = label

    if lastTerminalValues[key] ~= newValue then
        term.setCursorPos(x, y)
        term.clearLine()
        term.write(label .. ": " .. newValue)
        lastTerminalValues[key] = newValue
    end
end

function calculateInputGate(ri)
    if autoInputGate ~= 1 then
        return curInputGate
    end

    if ri.fieldDrainRate == nil then
        return reactorStartupInput
    end

    local targetFraction = targetStrength / 100

    if targetFraction >= 1 then
        targetFraction = 0.99
    end

    local requiredInput =
        ri.fieldDrainRate / (1 - targetFraction)

    if requiredInput < 0 then
        requiredInput = 0
    end

    return requiredInput
end

function calculateOutputTarget(ri)
    if not autoOutputGate then
        return fluxgate.getSignalLowFlow()
    end

    local currentOutput = fluxgate.getSignalLowFlow()

    if currentOutput < 0 then
        currentOutput = 0
    end

    local difference = targetGeneration - ri.generationRate

    local adjustment = math.abs(difference) * outputRampRate

    if adjustment < outputMinStep then
        adjustment = outputMinStep
    end

    local newOutput = currentOutput

    if difference > 0 then
        newOutput = currentOutput + adjustment
    else
        newOutput = currentOutput - adjustment
    end

    if newOutput < 0 then
        newOutput = 0
    end

    local maximumRequestedOutput = targetGeneration * 2

    if newOutput > maximumRequestedOutput then
        newOutput = maximumRequestedOutput
    end

    return math.floor(newOutput)
end

function reactorControl()
    reset()

    while true do
        local reactorInfo = reactor.getReactorInfo()

        if not reactorInfo then
            print("Reactor not setup correctly. Retrying in 2s...")
            sleep(2)
        else
            local i = 1

            for k, v in pairs(reactorInfo) do
                drawTerminalText(1, i, k, tostring(v))
                i = i + 1
            end

            i = i + 1

            drawTerminalText(
                1,
                i,
                "Output Gate",
                tostring(fluxgate.getSignalLowFlow())
            )

            i = i + 1

            drawTerminalText(
                1,
                i,
                "Input Gate",
                tostring(inputFluxgate.getSignalLowFlow())
            )

            if emergencyCharge then
                reactor.chargeReactor()
            end

            if reactorInfo.status == "warming_up" then

                inputFluxgate.setSignalLowFlow(reactorStartupInput)

                emergencyCharge = false

            elseif reactorInfo.status == "stopping"
                and reactorInfo.temperature < safeTemp
                and emergencyTemp then

                reactor.activateReactor()

                emergencyTemp = false

            elseif reactorInfo.status == "running" then

                local inputTarget = calculateInputGate(reactorInfo)

                inputFluxgate.setSignalLowFlow(inputTarget)

                drawTerminalText(
                    1,
                    i + 1,
                    "Target Input",
                    tostring(math.floor(inputTarget))
                )

                if autoOutputGate then
                    local newOutputTarget =
                        calculateOutputTarget(reactorInfo)

                    fluxgate.setSignalLowFlow(newOutputTarget)

                    outputTarget = newOutputTarget
                    lastAutoOutput = newOutputTarget
                end

                drawTerminalText(
                    1,
                    i + 2,
                    "Target Output",
                    tostring(math.floor(
                        autoOutputGate
                        and outputTarget
                        or fluxgate.getSignalLowFlow()
                    ))
                )

            elseif reactorInfo.status == "cold" then

                emergencyCharge = false

            end

            checkReactorSafety(reactorInfo)

            sleep(0.2)
        end
    end
end

function checkReactorSafety(reactorInfo)

    if not reactorInfo then
        return
    end

    local fuelPercent =
        100 -
        math.ceil(
            reactorInfo.fuelConversion /
            reactorInfo.maxFuelConversion *
            10000
        ) * 0.01

    local fieldPercent =
        math.ceil(
            reactorInfo.fieldStrength /
            reactorInfo.maxFieldStrength *
            10000
        ) * 0.01

    if fuelPercent <= 15 then
        emergencyShutdown(
            string.format(
                "Fuel Low! (%.2f%%) Refuel Now!",
                fuelPercent
            )
        )

    elseif fieldPercent <= lowFieldPer
        and reactorInfo.status == "running" then

        emergencyShutdown(
            string.format(
                "Field Strength Below %d%%! (%.2f%%)",
                lowFieldPer,
                fieldPercent
            )
        )

        reactor.chargeReactor()

        emergencyCharge = true

    elseif reactorInfo.temperature > maxTemp
        and reactorInfo.status == "running" then

        emergencyShutdown("Reactor Overheated!")

        emergencyTemp = true
    end
end

function emergencyShutdown(message)
    reactor.stopReactor()

    fluxgate.setSignalLowFlow(0)

    actioncolor = colors.red
    action = message

    ActionMenu()
end

local MenuText = "Loading..."

function clearMenuArea()

    for i = 26, monY - 1 do
        f.draw_line(
            mon,
            2,
            i,
            monX - 2,
            colors.black
        )
    end

    button.clearTable()

    f.draw_line(
        mon,
        2,
        26,
        monX - 2,
        colors.gray
    )

    f.draw_line(
        mon,
        2,
        monY - 1,
        monX - 2,
        colors.gray
    )

    f.draw_line_y(
        mon,
        2,
        26,
        monY - 1,
        colors.gray
    )

    f.draw_line_y(
        mon,
        monX - 1,
        26,
        monY - 1,
        colors.gray
    )

    f.draw_text(
        mon,
        4,
        26,
        " " .. MenuText .. " ",
        colors.white,
        colors.black
    )
end

function toggleReactor()

    local reactorInfo = reactor.getReactorInfo()

    if reactorInfo.status == "running" then

        reactor.stopReactor()

        fluxgate.setSignalLowFlow(0)

    elseif reactorInfo.status == "stopping" then

        reactor.activateReactor()

    else

        reactor.chargeReactor()
    end
end

function ActionMenu()

    currentMenu = "action"
    MenuText = "ATTENTION"

    clearMenuArea()

    button.setButton(
        "action",
        action,
        buttonMain,
        5,
        28,
        monX - 4,
        30,
        0,
        0,
        colors.red
    )

    button.screen()
end

function rebootSystem()
    os.reboot()
end

function buttonControls()

    if currentMenu == "controls" then
        return
    end

    currentMenu = "controls"
    MenuText = "CONTROLS"

    clearMenuArea()

    local sLength =
        6 + (string.len("Toggle Reactor") + 1)

    button.setButton(
        "toggle",
        "Toggle Reactor",
        toggleReactor,
        6,
        28,
        sLength,
        30,
        0,
        0,
        colors.blue
    )

    local sLength2 =
        sLength +
        12 +
        string.len("Reboot") +
        1

    button.setButton(
        "reboot",
        "Reboot",
        rebootSystem,
        sLength + 12,
        28,
        sLength2,
        30,
        0,
        0,
        colors.blue
    )

    local sLength3 =
        4 +
        (string.len("Back") + 1)

    button.setButton(
        "back",
        "Back",
        buttonMain,
        4,
        32,
        sLength3,
        34,
        0,
        0,
        colors.blue
    )

    button.screen()
end

function changeOutputValue(num, val)

    local currentFlow =
        fluxgate.getSignalLowFlow()

    if val == 1 then
        currentFlow = currentFlow + num
    else
        currentFlow = currentFlow - num
    end

    if currentFlow < 0 then
        currentFlow = 0
    end

    fluxgate.setSignalLowFlow(currentFlow)

    outputTarget = currentFlow
    lastAutoOutput = currentFlow

    updateReactorInfo()
end

function outputMenu()

    if currentMenu == "output" then
        return
    end

    currentMenu = "output"
    MenuText = "OUTPUT"

    clearMenuArea()

    local buttonData = {
        {label = ">>>>", value = 1000000, changeType = 1},
        {label = ">>>", value = 100000, changeType = 1},
        {label = ">>", value = 10000, changeType = 1},
        {label = ">", value = 1000, changeType = 1},
        {label = "<", value = 1000, changeType = 0},
        {label = "<<", value = 10000, changeType = 0},
        {label = "<<<", value = 100000, changeType = 0},
        {label = "<<<<", value = 1000000, changeType = 0},
    }

    local spacing = 2
    local buttonY = 28
    local currentX = monX - 7

    for _, data in ipairs(buttonData) do

        local buttonLength =
            string.len(data.label) + 1

        local startX =
            currentX - buttonLength

        local endX =
            startX + buttonLength

        button.setButton(
            data.label,
            data.label,
            changeOutputValue,
            startX,
            buttonY,
            endX,
            buttonY + 2,
            data.value,
            data.changeType,
            colors.blue
        )

        currentX =
            currentX -
            buttonLength -
            spacing
    end

    local backLength =
        4 +
        string.len("Back") +
        1

    button.setButton(
        "back",
        "Back",
        buttonMain,
        4,
        32,
        backLength,
        34,
        0,
        0,
        colors.blue
    )

    button.screen()
end

function buttonMain()

    if currentMenu == "main" then
        return
    end

    currentMenu = "main"
    MenuText = "MAIN MENU"

    clearMenuArea()

    local sLength =
        4 +
        (string.len("Controls") + 1)

    button.setButton(
        "controls",
        "Controls",
        buttonControls,
        4,
        28,
        sLength,
        30,
        0,
        0,
        colors.blue
    )

    local sLength2 =
        sLength +
        13 +
        string.len("Output") +
        1

    button.setButton(
        "output",
        "Output",
        outputMenu,
        sLength + 13,
        28,
        sLength2,
        30,
        0,
        0,
        colors.blue
    )

    button.screen()
end

local lastValues = {}

function reactorInfoScreen()

    mon.clear()

    f.draw_text(
        mon,
        2,
        38,
        "Made by: StormFusions  v" .. version,
        colors.gray,
        colors.black
    )

    f.draw_line(
        mon,
        2,
        22,
        monX - 2,
        colors.gray
    )

    f.draw_line(
        mon,
        2,
        2,
        monX - 2,
        colors.gray
    )

    f.draw_line_y(
        mon,
        2,
        2,
        22,
        colors.gray
    )

    f.draw_line_y(
        mon,
        monX - 1,
        2,
        22,
        colors.gray
    )

    f.draw_text(
        mon,
        4,
        2,
        " INFO ",
        colors.white,
        colors.black
    )

    f.draw_line(
        mon,
        2,
        26,
        monX - 2,
        colors.gray
    )

    f.draw_line(
        mon,
        2,
        monY - 1,
        monX - 2,
        colors.gray
    )

    f.draw_line_y(
        mon,
        2,
        26,
        monY - 1,
        colors.gray
    )

    f.draw_line_y(
        mon,
        monX - 1,
        26,
        monY - 1,
        colors.gray
    )

    f.draw_text(
        mon,
        4,
        26,
        " " .. MenuText .. " ",
        colors.white,
        colors.black
    )

    while true do
        updateReactorInfo()
        sleep(0.1)
    end
end

function updateReactorInfo()

    ri = reactor.getReactorInfo()

    if not ri then
        return
    end

    local status = reactorStatus(ri.status)

    drawUpdatedText(
        4,
        4,
        "Status:",
        status[1],
        status[2]
    )

    drawUpdatedText(
        4,
        5,
        "Generation:",
        f.format_int(ri.generationRate) .. " rf/t",
        colors.lime
    )

    local tempColor =
        getTempColor(ri.temperature)

    drawUpdatedText(
        4,
        7,
        "Temperature:",
        f.format_int(ri.temperature) .. "C",
        tempColor
    )

    drawUpdatedText(
        4,
        9,
        "Output Gate:",
        f.format_int(
            fluxgate.getSignalLowFlow()
        ) .. " rf/t",
        colors.lightBlue
    )

    drawUpdatedText(
        4,
        10,
        "Input Gate:",
        f.format_int(
            inputFluxgate.getSignalLowFlow()
        ) .. " rf/t",
        colors.lightBlue
    )

    local satPercent =
        getPercentage(
            ri.energySaturation,
            ri.maxEnergySaturation
        )

    drawUpdatedText(
        4,
        12,
        "Energy Saturation:",
        string.format(
            "%.2f%%",
            satPercent
        ),
        colors.green
    )

    f.progress_bar(
        mon,
        4,
        13,
        monX - 7,
        satPercent,
        100,
        colors.green,
        colors.lightGray
    )

    local fieldPercent =
        getPercentage(
            ri.fieldStrength,
            ri.maxFieldStrength
        )

    local fieldColor =
        getFieldColor(fieldPercent)

    drawUpdatedText(
        4,
        15,
        "Field Strength:",
        string.format(
            "%.2f%%",
            fieldPercent
        ),
        fieldColor
    )

    f.progress_bar(
        mon,
        4,
        16,
        monX - 7,
        fieldPercent,
        100,
        fieldColor,
        colors.lightGray
    )

    local fuelPercent =
        100 -
        getPercentage(
            ri.fuelConversion,
            ri.maxFuelConversion
        )

    local fuelColor =
        getFuelColor(fuelPercent)

    drawUpdatedText(
        4,
        18,
        "Fuel:",
        string.format(
            "%.2f%%",
            fuelPercent
        ),
        fuelColor
    )

    f.progress_bar(
        mon,
        4,
        19,
        monX - 7,
        fuelPercent,
        100,
        fuelColor,
        colors.lightGray
    )

    drawUpdatedText(
        4,
        21,
        "Target:",
        f.format_int(targetGeneration) .. " rf/t",
        colors.white
    )
end

function drawUpdatedText(x, y, label, value, color)

    local key = label

    if lastValues[key] ~= value then

        f.draw_text_lr(
            mon,
            x,
            y,
            3,
            "            ",
            "                    ",
            colors.white,
            color,
            colors.black
        )

        f.draw_text_lr(
            mon,
            x,
            y,
            3,
            label,
            value,
            colors.white,
            color,
            colors.black
        )

        lastValues[key] = value
    end
end

function getTempColor(temp)

    if temp <= 5000 then
        return colors.green
    end

    if temp <= 6500 then
        return colors.orange
    end

    return colors.red
end

function getFieldColor(percent)

    if percent >= 50 then
        return colors.blue
    end

    if percent > 30 then
        return colors.orange
    end

    return colors.red
end

function getFuelColor(percent)

    if percent >= 70 then
        return colors.green
    end

    if percent > 25 then
        return colors.orange
    end

    return colors.red
end

function getPercentage(value, maxValue)

    if maxValue == 0 then
        return 0
    end

    return math.ceil(
        value / maxValue * 10000
    ) * 0.01
end

mon.clear()

mon.monitor.setTextScale(0.5)

buttonMain()

parallel.waitForAny(
    reactorInfoScreen,
    reactorControl,
    button.clickEvent
)
