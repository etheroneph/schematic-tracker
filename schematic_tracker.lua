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
- code: screenHandler(output)
  filter:
    args:
    - variable: '*'
    signature: onOutputChanged(output)
    slotKey: '1'
  key: '0'
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
        return missingSchematics
    end

    function selectSchematic(schematicId)
        if schematicId ~= selectedSchematic then
            system.clearWaypoint(true)
            selectedUnit = nil
        end

        selectedSchematic = schematicId

        if schematicId == 0 then
            selectedSchematic = nil
            selectedUnit = nil
            return
        end

        local schematicName = system.getItem(selectedSchematic).displayName

        for _, industryUnit in pairs(industryUnits) do
            if industryUnit.isMissingSchematic(selectedSchematic) then
                selectedUnit = industryUnit.id
                system.setWaypoint(convertToPosString(industryUnit.getWorldPosition()), true)
                break
            end
        end

        if selectedUnit == nil then
            system.clearWaypoint(true)
        end

        return selectedUnit
    end

    function drawUI()
        local html = [[
    <style>
    .box{
        background-color: rgb(9, 16, 19);
        width: fit-content;
        padding: 10px;
        border: solid 1px black;
    }
        
    .header{
        font-weight: bold;
        color: white;
        font-size: 25px;
        text-align: center;
        background-image: linear-gradient(to right, rgb(34, 52, 59), rgb(48, 72, 81), rgb(34, 52, 59));
        margin: -10px;
        padding-top: 5px;
        padding-left: 10px;
        padding-right: 10px;
        font-family: Refrigerator;
    }

    .schematic{
        color: rgb(146, 180, 192);
        font-size: 18px;
        padding: 10px;
        font-family: Play;
    }

    .selected{
        background-color: rgb(182, 223, 237);
        color: black;
        margin-left: -10px;
        margin-right: -10px;
    }
        
    .industry{
        font-size: 16px;
        padding-left: 10px;
        margin-left: 10px;
        border-left: solid 2px black;
    }
        
    .selected-industry{
        border-left: solid 2px yellow;
    }

    hr{
        border: 1px solid rgb(34, 52, 59);
    }
    </style>
        
    <div class="box">
    <div class="header">MISSING SCHEMATICS</div><br>
    ]]

        for _, schematicId in pairs(schematicsSorted(industryUnits)) do
            local schematic = system.getItem(schematicId).displayNameWithSize

            local class = "schematic"
            local industryUnitHtml = ""

            if schematicId == selectedSchematic then
                class = class .. " selected"
                
                for _, industryUnit in pairs(industryUnits) do
                    if industryUnit.isMissingSchematic(schematicId) then
                        local iuClass = "industry"
                        if selectedUnit == industryUnit.id then
                            iuClass = iuClass .. " selected-industry"
                        end
                        industryUnitHtml = industryUnitHtml .. "<div class=\"" .. iuClass .. "\">" .. industryUnit.name .. "</div>"
                    end
                end
            end

            html = html .. "<div class=\"" .. class .. "\">" .. schematic ..  industryUnitHtml .. "</div><hr>"
        end

        html = html .. "</div>"
        system.showScreen(true)
        system.setScreen(html)
    end

    function schematicsSorted(industryUnits)
        local schematicIds = {}
        for schematicId, _ in pairs(getMissingSchematics(industryUnits)) do
            table.insert(schematicIds, schematicId)
        end
        table.sort(schematicIds)
        return schematicIds
    end

    for _, slot in pairs(unit) do
        if type(slot) == "table" and slot.getClass ~= nil then
            local class = slot.getClass()
            if class == "DataBankUnit" then
                databank = slot
            elseif class == "CoreUnitStatic" then
                core = slot
            end
        end
    end

    if databank == nil then
        system.print("databank link required")
        unit.exit()
    elseif core == nil then
        system.print("core link required")
        unit.exit()
    end

    schematicListIndex = 0
    industryUnits = getIndustryUnits()
    drawUI()
    unit.setTimer("checkMissing", 5)
  filter:
    args: []
    signature: onStart()
    slotKey: '-1'
  key: '1'
- code: |-
    drawUI()
    collectgarbage("count")
    collectgarbage("collect")
    collectgarbage("collect")
  filter:
    args:
    - value: checkMissing
    signature: onTimer(tag)
    slotKey: '-1'
  key: '2'
- code: |-
    for _, industryUnit in pairs(industryUnits) do
        if industryUnit.id == selectedUnit then
            industryUnit.removeMissingSchematic(selectedSchematic)
        end
    end

    selectSchematic(selectedSchematic)
    drawUI()
  filter:
    args:
    - value: option2
    signature: onActionStart(action)
    slotKey: '-4'
  key: '3'
- code: |-
    schematicIds = schematicsSorted(industryUnits)
    schematicListIndex = schematicListIndex + 1
    if schematicListIndex > #schematicIds then
        schematicListIndex = 0
    end
    selectSchematic(schematicListIndex == 0 and 0 or schematicIds[schematicListIndex])
    drawUI()
  filter:
    args:
    - value: option1
    signature: onActionStart(action)
    slotKey: '-4'
  key: '4'
methods: []
events: []
