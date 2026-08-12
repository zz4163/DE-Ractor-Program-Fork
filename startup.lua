local libURL =
    "https://raw.githubusercontent.com/StormFusions/Draconic-ComputerCraft-Program/main/lib/f.lua"

local libURL2 =
    "https://raw.githubusercontent.com/StormFusions/Draconic-ComputerCraft-Program/main/lib/button.lua"

local reactorPrograms = {
    {
        name = "Reactor 1",
        description = "4B RF/t Script",
        url =
            "https://raw.githubusercontent.com/zz4163/DE-Ractor-Program-Fork/refs/heads/main/reactor1.lua",
        file = "reactor1.lua"
    },

    {
        name = "Reactor 2",
        description = "Original Script",
        url =
            "https://raw.githubusercontent.com/zz4163/DE-Ractor-Program-Fork/refs/heads/main/reactor2.lua",
        file = "reactor2.lua"
    }
}

local function updateFile(url, filePath, displayName)
    print("Checking " .. displayName .. "...")

    local response = http.get(url)

    if not response then
        error(
            "Unable to download " ..
            displayName ..
            ".\nCheck your internet connection and URL."
        )
    end

    local remoteFile = response.readAll()
    response.close()

    if not fs.exists(filePath) then
        local file = fs.open(filePath, "w")

        if not file then
            error("Unable to create " .. filePath)
        end

        file.write(remoteFile)
        file.close()

        print(displayName .. " downloaded.")
        return
    end

    local file = fs.open(filePath, "r")

    if not file then
        error("Unable to read " .. filePath)
    end

    local localFile = file.readAll()
    file.close()

    if remoteFile ~= localFile then
        local updateFile = fs.open(filePath, "w")

        if not updateFile then
            error("Unable to update " .. filePath)
        end

        updateFile.write(remoteFile)
        updateFile.close()

        print(displayName .. " updated.")
    else
        print(displayName .. " up to date.")
    end
end

fs.makeDir("lib")

updateFile(
    libURL,
    "lib/f",
    "API F"
)

updateFile(
    libURL2,
    "lib/button",
    "API Button"
)

local function showMenu()
    term.clear()
    term.setCursorPos(1, 1)

    print("================================")
    print("     DRACONIC REACTOR CONTROL")
    print("================================")
    print("")

    for i, reactor in ipairs(reactorPrograms) do
        print(
            tostring(i) ..
            ". " ..
            reactor.name
        )

        print("")
    end

    print("Enter the desired reactor number.")
    print("")

    write("Selection: ")

    local input = read()

    return tonumber(input)
end

local selectedIndex

while true do
    selectedIndex = showMenu()

    if selectedIndex
        and reactorPrograms[selectedIndex] then
        break
    end

    print("")
    print("Invalid selection.")
    print("Please choose one of the available reactors.")
    sleep(2)
end

local selectedReactor =
    reactorPrograms[selectedIndex]

print("")
print(
    "Selected: " ..
    selectedReactor.name
)

print("")

updateFile(
    selectedReactor.url,
    selectedReactor.file,
    selectedReactor.name
)

print("")
print("Finished.")
print(
    "Starting " ..
    selectedReactor.name ..
    "..."
)

sleep(3)

shell.run(
    selectedReactor.file
)
