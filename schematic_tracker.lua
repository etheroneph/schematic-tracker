---
slots:
  '0':
    name: slot3
    type:
      events: []
      methods: []
  '1':
    name: slot2
    type:
      events: []
      methods: []
  '2':
    name: slot1
    type:
      events: []
      methods: []
  '3':
    name: slot4
    type:
      events: []
      methods: []
  '4':
    name: slot5
    type:
      events: []
      methods: []
  '5':
    name: slot6
    type:
      events: []
      methods: []
  '6':
    name: slot7
    type:
      events: []
      methods: []
  '7':
    name: slot8
    type:
      events: []
      methods: []
  '8':
    name: slot9
    type:
      events: []
      methods: []
  '9':
    name: slot10
    type:
      events: []
      methods: []
  '-1':
    name: unit
    type:
      events: []
      methods: []
  '-3':
    name: player
    type:
      events: []
      methods: []
  '-2':
    name: construct
    type:
      events: []
      methods: []
  '-4':
    name: system
    type:
      events: []
      methods: []
  '-5':
    name: library
    type:
      events: []
      methods: []
handlers:
- code: screenHandler()
  filter:
    args:
    - variable: '*'
    signature: onOutputChanged(output)
    slotKey: '0'
  key: '0'
- code: screenHandler()
  filter:
    args:
    - variable: '*'
    signature: onOutputChanged(output)
    slotKey: '1'
  key: '1'
- code: screenHandler()
  filter:
    args:
    - variable: '*'
    signature: onOutputChanged(output)
    slotKey: '2'
  key: '2'
- code: |-
    function convertToPosString(vector)
        return string.format("::pos{0,0,%f,%f,%f}", vector.x, vector.y, vector.z)
    end

    -- https://github.com/wolfe-labs/DU-Kernel/blob/main/src/Math.lua#L100
    function convertLocalToWorld(localCoord)
        local posG = vec3(construct.getWorldPosition())
        local forward = vec3(construct.getWorldOrientationForward())
        local right = vec3(construct.getWorldOrientationRight())
        local up = vec3(construct.getWorldOrientationUp())

        -- Extract the axes into individual variables
        local rightX, rightY, rightZ = right:unpack()
        local forwardX, forwardY, forwardZ = forward:unpack()
        local upX, upY, upZ = up:unpack()

        -- Extracts the local position into individual coordinates
        local rfuX, rfuY, rfuZ = localCoord.x, localCoord.y, localCoord.z

        -- Apply the rotations to obtain the relative coordinate in world-space
        local relX = rfuX * rightX + rfuY * forwardX + rfuZ * upX
        local relY = rfuX * rightY + rfuY * forwardY + rfuZ * upY
        local relZ = rfuX * rightZ + rfuY * forwardZ + rfuZ * upZ

        return posG + vec3(relX, relY, relZ)
    end

    function IndustryUnit(id)
        local iu = {}

        iu.id = id
        iu.name = core.getElementNameById(id)
        iu.item = system.getItem(core.getElementItemIdById(id))
        iu.missingSchematics = {}

        iu.addMissingSchematic = function (schematicId)
            iu.missingSchematics[schematicId] = true
        end

        iu.removeMissingSchematic = function (schematicId)
            iu.missingSchematics[schematicId] = false
        end

        iu.isMissingSchematic = function (schematicId)
            if iu.missingSchematics[schematicId] == nil then
                return false
            end

            return iu.missingSchematics[schematicId]
        end

        iu.getMissingSchematics = function ()
            local missingSchematics = {}
            for schematic, missing in pairs(iu.missingSchematics) do
                if missing then
                    table.insert(missingSchematics, schematic)
                end
            end
            return missingSchematics
        end

        iu.checkStatus = function ()
            local iInfo = core.getElementIndustryInfoById(iu.id)

            if #iInfo.currentProducts < 1 then
                return
            end

            local product = system.getItem(iInfo.currentProducts[1].id)

            if #product.schematics < 1 then
                return
            end

            if iInfo.state == 7 then
                iu.addMissingSchematic(product.schematics[1])
            elseif iInfo.state == 2 then
                iu.removeMissingSchematic(product.schematics[1])
            end
        end

        iu.getWorldPosition = function ()
            return convertLocalToWorld(vec3(core.getElementPositionById(iu.id)))
        end

        return iu
    end

    function getIndustryUnits()
        local industryUnits = {}

        for _, id in pairs(core.getElementIdList()) do
            if core.getElementClassById(id):lower():match("industry") then
                table.insert(industryUnits, IndustryUnit(id))
            end
        end

        local industryData = databank.getStringValue("industryData")
        if industryData ~= "" then
            industryData = json.decode(industryData)

            for _, industryUnit in pairs(industryUnits) do
                local missingSchematics = industryData[tostring(industryUnit.id)]
                if missingSchematics ~= nil then
                    for _, schematic in pairs(missingSchematics) do
                        industryUnit.addMissingSchematic(schematic)
                    end
                end
            end
        end

        return industryUnits
    end

    function dumpSchematicJson(industryUnits)
        local industryUnitJson = {}
        for _, industryUnit in pairs(industryUnits) do
            local missingSchematics = industryUnit.getMissingSchematics()
            if #missingSchematics > 0 then
                industryUnitJson[industryUnit.id] = missingSchematics
            end
        end
        databank.setStringValue("industryData", json.encode(industryUnitJson))
    end

    function getMissingSchematics(industryUnits)
        local missingSchematics = {}

        for _, iu in pairs(industryUnits) do
            iu.checkStatus()

            for _, schematic in pairs(iu.getMissingSchematics()) do
                if missingSchematics[schematic] == nil then
                    missingSchematics[schematic] = {}
                end

                missingSchematics[schematic][iu.id] = true
            end
        end

        local missingSchematicIds = {}
        for missingSchematic, _ in pairs(missingSchematics) do
            table.insert(missingSchematicIds, missingSchematic)
        end

        dumpSchematicJson(industryUnits)
        screen.setScriptInput(json.encode(missingSchematicIds))
    end

    function selectSchematic(selectedSchematic)
        local selectedUnit
        local schematicName = system.getItem(selectedSchematic).displayName

        for _, industryUnit in pairs(industryUnits) do
            if industryUnit.isMissingSchematic(selectedSchematic) then
                selectedUnit = industryUnit.id
                system.print("load unit " .. industryUnit.name)
                system.setWaypoint(convertToPosString(industryUnit.getWorldPosition()), true)
                break
            end
        end

        if selectedUnit == nil then
            system.clearWaypoint(true)
            system.print("finished loading schematics for  " .. schematicName .. "!")
        end

        return selectedUnit
    end

    function screenHandler()
        system.print("started schematic loading helper, press alt+1 once the machine at the waypoint has been loaded")
        selectedSchematic = tonumber(output)

        local missingCount = 0
        for _, industryUnit in pairs(industryUnits) do
            if industryUnit.isMissingSchematic(selectedSchematic) then
                missingCount = missingCount + 1
            end
        end

        system.print("schematic: " .. system.getItem(selectedSchematic).displayName)
        system.print("number of industry units: " .. missingCount)

        selectedUnit = selectSchematic(selectedSchematic)
    end

    for _, slot in pairs(unit) do
        if type(slot) == "table" and slot.getClass ~= nil then
            local class = slot.getClass()
            if class == "DataBankUnit" then
                databank = slot
            elseif class == "ScreenUnit" then
                screen = slot
            elseif class == "CoreUnitStatic" then
                core = slot
            end
        end
    end

    if databank == nil then
        system.print("databank link required")
        unit.exit()
    elseif screen == nil then
        system.print("screen link required")
        unit.exit()
    elseif core == nil then
        system.print("core link required")
        unit.exit()
    end

    screen.activate()
    screen.setRenderScript([[
    json = require("dkjson")

    schematics = {
        [3077761447] = "Atmospheric Fuel Schematic Copy",
        [674258992] = "Bonsai Schematic Copy",
        [784932973] = "Construct Support L Schematic Copy",
        [1861676811] = "Construct Support M Schematic Copy",
        [1224468838] = "Construct Support S Schematic Copy",
        [1477134528] = "Construct Support XS Schematic Copy",
        [1202149588] = "Core Unit L Schematic Copy",
        [1417495315] = "Core Unit M Schematic Copy",
        [1213081642] = "Core Unit S Schematic Copy",
        [120427296] = "Core Unit XS Schematic Copy",
        [3992802706] = "Rocket Fuels Schematic Copy",
        [1917988879] = "Space Fuels Schematic Copy",
        [318308564] = "Territory Unit Schematic Copy",
        [2068774589] = "Tier 1 L Element Schematic Copy",
        [2066101218] = "Tier 1 M Element Schematic Copy",
        [2479827059] = "Tier 1 Product Honeycomb Schematic Copy",
        [690638651] = "Tier 1 Product Material Schematic Copy",
        [4148773283] = "Tier 1 S Element Schematic Copy",
        [304578197] = "Tier 1 XL Element Schematic Copy",
        [1910482623] = "Tier 1 XS Element Schematic Copy",
        [512435856] = "Tier 2 Ammo L Schematic Copy",
        [399761377] = "Tier 2 Ammo M Schematic Copy",
        [3336558558] = "Tier 2 Ammo S Schematic Copy",
        [326757369] = "Tier 2 Ammo XS Schematic Copy",
        [616601802] = "Tier 2 L Element Schematic Copy",
        [2726927301] = "Tier 2 M Element Schematic Copy",
        [632722426] = "Tier 2 Product Honeycomb Schematic Copy",
        [4073976374] = "Tier 2 Product Material Schematic Copy",
        [625377458] = "Tier 2 Pure Honeycomb Schematic Copy",
        [3332597852] = "Tier 2 Pure Material Schematic Copy",
        [1752968727] = "Tier 2 S Element Schematic Copy",
        [1952035274] = "Tier 2 Scrap Schematic Copy",
        [3677281424] = "Tier 2 XL Element Schematic Copy",
        [2096799848] = "Tier 2 XS Element Schematic Copy",
        [2913149958] = "Tier 3 Ammo L Schematic Copy",
        [3125069948] = "Tier 3 Ammo M Schematic Copy",
        [1705420479] = "Tier 3 Ammo S Schematic Copy",
        [2413250793] = "Tier 3 Ammo XS Schematic Copy",
        [1427639881] = "Tier 3 L Element Schematic Copy",
        [3713463144] = "Tier 3 M Element Schematic Copy",
        [2343247971] = "Tier 3 Product Honeycomb Schematic Copy",
        [3707339625] = "Tier 3 Product Material Schematic Copy",
        [4221430495] = "Tier 3 Pure Honeycomb Schematic Copy",
        [2003602752] = "Tier 3 Pure Material Schematic Copy",
        [425872842] = "Tier 3 S Element Schematic Copy",
        [2566982373] = "Tier 3 Scrap Schematic Copy",
        [109515712] = "Tier 3 XL Element Schematic Copy",
        [787727253] = "Tier 3 XS Element Schematic Copy",
        [2557110259] = "Tier 4 Ammo L Schematic Copy",
        [3847207511] = "Tier 4 Ammo M Schematic Copy",
        [3636126848] = "Tier 4 Ammo S Schematic Copy",
        [2293088862] = "Tier 4 Ammo XS Schematic Copy",
        [1614573474] = "Tier 4 L Element Schematic Copy",
        [3881438643] = "Tier 4 M Element Schematic Copy",
        [3743434922] = "Tier 4 Product Honeycomb Schematic Copy",
        [2485530515] = "Tier 4 Product Material Schematic Copy",
        [99491659] = "Tier 4 Pure Honeycomb Schematic Copy",
        [2326433413] = "Tier 4 Pure Material Schematic Copy",
        [3890840920] = "Tier 4 S Element Schematic Copy",
        [1045229911] = "Tier 4 Scrap Schematic Copy",
        [1974208697] = "Tier 4 XL Element Schematic Copy",
        [210052275] = "Tier 4 XS Element Schematic Copy",
        [86717297] = "Tier 5 L Element Schematic Copy",
        [3672319913] = "Tier 5 M Element Schematic Copy",
        [1885016266] = "Tier 5 Product Honeycomb Schematic Copy",
        [2752973532] = "Tier 5 Product Material Schematic Copy",
        [3303272691] = "Tier 5 Pure Honeycomb Schematic Copy",
        [1681671893] = "Tier 5 Pure Material Schematic Copy",
        [880043901] = "Tier 5 S Element Schematic Copy",
        [2702634486] = "Tier 5 Scrap Schematic Copy",
        [1320378000] = "Tier 5 XL Element Schematic Copy",
        [1513927457] = "Tier 5 XS Element Schematic Copy",
        [3437488324] = "Warp Beacon Schematic Copy",
        [363077945] = "Warp Cell Schematic Copy",
    }

    layer = createLayer()
    font = loadFont("Play", 45)
    textWidth, textHeight = getTextBounds(font, "A")
    screenWidth, screenHeight = getResolution()
    textPadding = textHeight / 3
    cursorX, cursorY = getCursor()
    setDefaultTextAlign(layer, AlignH_Left, AlignV_Top)

    for index, schematicId in pairs(json.decode(getInput())) do
        local lineStartY = (textHeight+textPadding)*index
        local lineEndY = lineStartY + textHeight + textPadding

        if lineStartY <= cursorY and cursorY <= lineEndY and getCursorPressed() then
            selectedSchematic = schematicId
            setOutput(schematicId)
        end

        if schematicId == selectedSchematic then
            setNextFillColor(layer, 1, 1, 0, 1)
        end

        addText(layer, font, schematics[schematicId], 0, lineStartY)
    end
    ]])

    industryUnits = getIndustryUnits()
    unit.setTimer("checkMissing", 5)
  filter:
    args: []
    signature: onStart()
    slotKey: '-1'
  key: '3'
- code: |
    getMissingSchematics(industryUnits)
  filter:
    args:
    - value: checkMissing
    signature: onTimer(tag)
    slotKey: '-1'
  key: '4'
- code: |-
    for _, industryUnit in pairs(industryUnits) do
        if industryUnit.id == selectedUnit then
            industryUnit.removeMissingSchematic(selectedSchematic)
        end
    end

    selectedUnit = selectSchematic(selectedSchematic)
  filter:
    args:
    - value: option1
    signature: onActionStart(action)
    slotKey: '-4'
  key: '5'
methods: []
events: []
