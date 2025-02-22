local UserInputService = game:GetService("UserInputService") -- Services
local HttpService = game:GetService("HttpService")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local insert = table.insert -- Cache
local remove = table.remove
local find = table.find
local nVector2 = Vector2.new
local nRGB = Color3.fromRGB
local nDrawing = Drawing.new

local screenSize = nVector2(Workspace.CurrentCamera.ViewportSize.X, Workspace.CurrentCamera.ViewportSize.Y) -- Screen
local screenCenter = nVector2(Workspace.CurrentCamera.ViewportSize.X/2, Workspace.CurrentCamera.ViewportSize.Y/2)

local frameworkHook
local framework = {
    connections = {},
    flags = {},
    esp = {},
    labels = {},
    theme = {
        font = Drawing.Fonts.Plex,
        fontSize = 13
    },
    menu = {
        open = true,
        offset = 0,
        bindingKey = false,
        currentItem = nil,
        keybinds = {},
        list = {},
        drawings = {},
        hiddenDrawings = {},
    }
}

setmetatable(framework, {
    __call = function(self, key, args)
        if key == "draw" then
            local i = nDrawing(args.class)
            for prop, val in next, args.properties do
                i[prop] = val
            end
            if not args.hidden then
                insert(self.menu.drawings, i)
            else
                insert(self.menu.hiddenDrawings, i)
            end 
            return i
        elseif key == "deepCopy" then
            local function deepCopy(tbl)
                local copy = {}
                for k, v in pairs(tbl) do
                    if type(v) == "table" then
                        v = deepCopy(v)
                    end
                    copy[k] = v
                end
                return copy
            end
            return deepCopy(args.tbl)
        elseif key == "doesDrawingExist" then
            if args.drawing then
                if rawget(args.drawing, '__OBJECT_EXISTS') then
                    return true
                else
                    return false
                end
            else
                return err("No Drawing Specified [1]")
            end
        elseif key == "udim" then -- (type, xScale, xOffset, yScale, yOffset, relativeFrom)
            if args.type == "size" then
                local x
                local y
                if args.relativeFrom then
                    x = args.xScale*args.relativeFrom.Size.X+args.xOffset
                    y = args.yScale*args.relativeFrom.Size.Y+args.yOffset
                else
                    x = args.xScale*screenSize.X+args.xOffset
                    y = args.yScale*screenSize.Y+args.yOffset
                end
                return nVector2(x,y)
            elseif args.type == "position" then
                local x
                local y

                if args.relativeFrom then
                    if find(args.relativeFrom, "Font") then
                        x = args.relativeFrom.Position.X + args.xScale * args.relativeFrom.Size.X + args.xOffset
                        y = args.relativeFrom.Position.y + args.yScale * args.relativeFrom.Size.y + args.yOffset
                    else
                        x = args.relativeFrom.Position.x + args.xOffset
                        y = args.relativeFrom.Position.y + args.yOffset
                    end
                else
                    x = args.xScale * screenSize.X + args.xOffset
                    y = args.yScale * screenSize.Y + args.yOffset
                end
                return nVector2(x,y)
            else
                return "Non Valid Argument [1]"
            end
        elseif key == "createConnection" then -- (name, connection, callback)
            if not self.connections[args.name] then
                self.connections[args.name] = args.connection:Connect(args.callback)
                return self.connections[args.name]
            end
        elseif key == "destroyConnection" then -- (name)
            if self.connections[args.name] then
                self.connections[args.name]:Disconnect()
                self.connections[args.name] = nil
            end
        elseif key == "saveConfig" then
            local copy = self("deepCopy", {tbl = self.flags})
	        writefile("Config.YUKIHOOK", HttpService:JSONEncode(copy))
        elseif key == "loadConfig" then
            local decodedData = HttpService:JSONDecode(readfile("Config.YUKIHOOK"))
            for i,v in next, decodedData do
                self.flags[i] = v
            end
            for i,v in next, self.menu.list do
                v:refresh()
            end
        elseif key == "unload" then
            for i,v in next, framework.connections do
                v:Disconnect()
                framework.connections[i] = nil
            end

            for i,v in next, framework.esp do
                if type(v) == 'table' and v.Destroy then
                    v.Destroy()
                    framework.esp[i] = nil
                end
            end

            for i,v in next, framework.menu.drawings do
                if type(v) == 'table' and rawget(v, '__OBJECT_EXISTS') then
                    v:Remove()
                    framework.menu.drawings[i] = nil
                end
            end

            for i,v in next, framework.menu.hiddenDrawings do
                if type(v) == 'table' and rawget(v, '__OBJECT_EXISTS') then
                    v:Remove()
                    framework.menu.hiddenDrawings[i] = nil
                end
            end
        end
    end
})

function framework:createWindow(args)
    local window = {name = args.name or "TORGBOT"}

    window.textShadow = self("draw", {class = "Text", properties = {
        Text = window.name,
        Font = self.theme.font,
        Size = self.theme.fontSize,
        Position = framework("udim", {type = "position", xScale = 0, xOffset = 6, yScale = 0, yOffset = 320}),
        Visible = self.menu.open,
        Transparency = 1,
        Color = nRGB(0,0,0)
    }})

    window.text = self("draw", {class = "Text", properties = {
        Text = window.name,
        Font = self.theme.font,
        Size = self.theme.fontSize,
        Position = framework("udim", {type = "position", xScale = 0, xOffset = -1, yScale = 0, yOffset = -1, relativeFrom = window.textShadow}),
        Visible = self.menu.open,
        Transparency = 1,
        Color = nRGB(255,255,255)
    }})
    
    self.menu.offset += 15

    function window:selectItem(args)
        if framework.menu.currentItem then
            if framework.menu.currentItem.type == "label" then
                framework.menu.currentItem:setText(framework.menu.currentItem.text)
                framework.menu.currentItem:hover(false)
            elseif framework.menu.currentItem.type == "toggle" then
                framework.menu.currentItem:setText(framework.menu.currentItem.text.. " <"..tostring(framework.menu.currentItem.value)..">")
                framework.menu.currentItem:hover(false)
            elseif framework.menu.currentItem.type == "int" then
                framework.menu.currentItem:setText(framework.menu.currentItem.text.. " <"..tostring(framework.menu.currentItem.value)..">")
                framework.menu.currentItem:hover(false)
            elseif framework.menu.currentItem.type == "keybind" then
                framework.menu.currentItem:setText(framework.menu.currentItem.text.. " <"..tostring(framework.menu.currentItem.key)..">")
                framework.menu.currentItem:hover(false)
            elseif framework.menu.currentItem.type == "list" then
                framework.menu.currentItem:setText(framework.menu.currentItem.text.. " <"..tostring(framework.menu.currentItem.value)..">")
                framework.menu.currentItem:hover(false)
            end
        end
        framework.menu.currentItem = args.item
        if framework.menu.currentItem.type == "label" then
            framework.menu.currentItem:setText(framework.menu.currentItem.text.." <")
            framework.menu.currentItem:hover(true)
        elseif framework.menu.currentItem.type == "toggle" then
            framework.menu.currentItem:setText(framework.menu.currentItem.text.. " <"..tostring(framework.menu.currentItem.value).."> <")
            framework.menu.currentItem:hover(true)
        elseif framework.menu.currentItem.type == "int" then
            framework.menu.currentItem:setText(framework.menu.currentItem.text.. " <"..tostring(framework.menu.currentItem.value).."> <")
            framework.menu.currentItem:hover(true)
        elseif framework.menu.currentItem.type == "keybind" then
            framework.menu.currentItem:setText(framework.menu.currentItem.text.. " <"..tostring(framework.menu.currentItem.key).."> <")
            framework.menu.currentItem:hover(true)
        elseif framework.menu.currentItem.type == "list" then
            framework.menu.currentItem:setText(framework.menu.currentItem.text.. " <"..tostring(framework.menu.currentItem.value).."> <")
            framework.menu.currentItem:hover(true)
        end

    end

    function window:createLabel(args)
        local item = {text = args.text or "", drawings = {}, type = args.type or "label"}

        item.drawings.textShadow = framework("draw", {class = "Text", properties = {
            Text = item.text,
            Font = framework.theme.font,
            Size = framework.theme.fontSize,
            Position = framework("udim", {type = "position", xScale = 0, xOffset = 0, yScale = 0, yOffset = framework.menu.offset, relativeFrom = window.textShadow}),
            Visible = framework.menu.open,
            Transparency = 1,
            Color = nRGB(0,0,0)
        }})
    
        item.drawings.text = framework("draw", {class = "Text", properties = {
            Text = item.text,
            Font = framework.theme.font,
            Size = framework.theme.fontSize,
            Position = framework("udim", {type = "position", xScale = 0, xOffset = -1, yScale = 0, yOffset = -1, relativeFrom = item.drawings.textShadow}),
            Visible = framework.menu.open,
            Transparency = 1,
            Color = nRGB(255,255,255)
        }})

        function item:setText(text)
            item.drawings.textShadow.Text = text
            item.drawings.text.Text = text
        end

        function item:hover(bool)
            if bool then
                item.drawings.text.Color = nRGB(2,144,252)
            else
                item.drawings.text.Color = nRGB(255,255,255)    
            end
        end

        framework.menu.offset += 15 

        if #framework.menu.list == 0 then
            window:selectItem({item = item})
        end
        
        insert(framework.menu.list, item)
        return item
    end

    function window:createInt(args)
        local item = {text = args.text or "", drawings = {}, type = args.type or "int", flag = args.flag or "",  precision = args.offset or 1, value = args.default or 0, callback = args.callback or function() end}

        item.drawings.textShadow = framework("draw", {class = "Text", properties = {
            Text = item.text.. " <"..tostring(item.value)..">",
            Font = framework.theme.font,
            Size = framework.theme.fontSize,
            Position = framework("udim", {type = "position", xScale = 0, xOffset = 0, yScale = 0, yOffset = framework.menu.offset, relativeFrom = window.textShadow}),
            Visible = framework.menu.open,
            Transparency = 1,
            Color = nRGB(0,0,0)
        }})
    
        item.drawings.text = framework("draw", {class = "Text", properties = {
            Text = item.text.. " <"..item.value..">",
            Font = framework.theme.font,
            Size = framework.theme.fontSize,
            Position = framework("udim", {type = "position", xScale = 0, xOffset = -1, yScale = 0, yOffset = -1, relativeFrom = item.drawings.textShadow}),
            Visible = framework.menu.open,
            Transparency = 1,
            Color = nRGB(255,255,255)
        }})

        function item:offset(args)
            item.value += args.offset
            item.drawings.textShadow.Text = item.text.. " <"..item.value.."> <"
            item.drawings.text.Text = item.text.. " <"..item.value.."> <"
            framework.flags[item.flag] = item.value
            item.callback(item.value)
        end
        framework.flags[item.flag] = item.value
        item.callback(item.value)

        function item:setText(text)
            item.drawings.textShadow.Text = text
            item.drawings.text.Text = text
        end

        function item:hover(bool)
            if bool then
                item.drawings.text.Color = nRGB(2,144,252)
            else
                item.drawings.text.Color = nRGB(255,255,255)    
            end
        end

        function item:refresh()
            item.value = framework.flags[item.flag]
            item.drawings.textShadow.Text = item.text.. " <"..tostring(item.value)..">"
            item.drawings.text.Text = item.text.. " <"..tostring(item.value)..">"
            item.callback(item.value)
            if framework.menu.currentItem == item then
                item.drawings.textShadow.Text = item.text.. " <"..tostring(item.value).."> <"
                item.drawings.text.Text = item.text.. " <"..tostring(item.value).."> <"
                item:hover(true)
            end
        end
        
        framework.menu.offset += 15

        if #framework.menu.list == 0 then
            window:selectItem({item = item})
        end
        
        insert(framework.menu.list, item)
        return item
    end

    function window:createToggle(args)
        local item = {text = args.text or "", drawings = {}, type = args.type or "toggle", flag = args.flag or "", value = args.default or false, callback = args.callback or function() end}

        item.drawings.textShadow = framework("draw", {class = "Text", properties = {
            Text = item.text.. " <"..tostring(item.value)..">",
            Font = framework.theme.font,
            Size = framework.theme.fontSize,
            Position = framework("udim", {type = "position", xScale = 0, xOffset = 0, yScale = 0, yOffset = framework.menu.offset, relativeFrom = window.textShadow}),
            Visible = framework.menu.open,
            Transparency = 1,
            Color = nRGB(0,0,0)
        }})
    
        item.drawings.text = framework("draw", {class = "Text", properties = {
            Text = item.text.. " <"..tostring(item.value)..">",
            Font = framework.theme.font,
            Size = framework.theme.fontSize,
            Position = framework("udim", {type = "position", xScale = 0, xOffset = -1, yScale = 0, yOffset = -1, relativeFrom = item.drawings.textShadow}),
            Visible = framework.menu.open,
            Transparency = 1,
            Color = nRGB(255,255,255)
        }})

        function item:toggle()
            item.value = not item.value
            item.drawings.textShadow.Text = item.text.. " <"..tostring(item.value).."> <"
            item.drawings.text.Text = item.text.. " <"..(tostring(item.value)).."> <"
            framework.flags[item.flag] = item.value
            item.callback(item.value)
        end
        framework.flags[item.flag] = item.value
        item.callback(item.value)

        function item:setText(text)
            item.drawings.textShadow.Text = text
            item.drawings.text.Text = text
        end

        function item:hover(bool)
            if bool then
                item.drawings.text.Color = nRGB(2,144,252)
            else
                item.drawings.text.Color = nRGB(255,255,255)    
            end
        end

        function item:refresh()
            item.value = framework.flags[item.flag]
            item.drawings.textShadow.Text = item.text.. " <"..tostring(item.value)..">"
            item.drawings.text.Text = item.text.. " <"..tostring(item.value)..">"
            item.callback(item.value)
            if framework.menu.currentItem == item then
                item.drawings.textShadow.Text = item.text.. " <"..tostring(item.value).."> <"
                item.drawings.text.Text = item.text.. " <"..tostring(item.value).."> <"
                item:hover(true)
            end
        end

        framework.menu.offset += 15

        if #framework.menu.list == 0 then
            window:selectItem({item = item})
        end
        
        insert(framework.menu.list, item)
        return item
    end

    function window:createList(args)
        local item = {text = args.text or "", drawings = {}, type = args.type or "list", value = args.default or "none", flag = args.flag or "", list = args.list or {}, callback = args.callback or function() end}

        item.drawings.textShadow = framework("draw", {class = "Text", properties = {
            Text = item.text.. " <"..item.value..">",
            Font = framework.theme.font,
            Size = framework.theme.fontSize,
            Position = framework("udim", {type = "position", xScale = 0, xOffset = 0, yScale = 0, yOffset = framework.menu.offset, relativeFrom = window.textShadow}),
            Visible = framework.menu.open,
            Transparency = 1,
            Color = nRGB(0,0,0)
        }})
    
        item.drawings.text = framework("draw", {class = "Text", properties = {
            Text = item.text.. " <"..item.value..">",
            Font = framework.theme.font,
            Size = framework.theme.fontSize,
            Position = framework("udim", {type = "position", xScale = 0, xOffset = -1, yScale = 0, yOffset = -1, relativeFrom = item.drawings.textShadow}),
            Visible = framework.menu.open,
            Transparency = 1,
            Color = nRGB(255,255,255)
        }})

        function item:selectOption(option)
            item.value = option
            item.drawings.textShadow.Text = item.text.. " <"..item.value.."> <"
            item.drawings.text.Text = item.text.. " <"..item.value.."> <"
            framework.flags[item.flag] = item.value
            item.callback(item.value)
        end
        framework.flags[item.flag] = item.value
        item.callback(item.value)

        function item:setText(text)
            item.drawings.textShadow.Text = text
            item.drawings.text.Text = text
        end

        function item:hover(bool)
            if bool then
                item.drawings.text.Color = nRGB(2,144,252)
            else
                item.drawings.text.Color = nRGB(255,255,255)    
            end
        end

        function item:refresh()
            item.value = framework.flags[item.flag]
            item.drawings.textShadow.Text = item.text.. " <"..tostring(item.value)..">"
            item.drawings.text.Text = item.text.. " <"..tostring(item.value)..">"
            item.callback(item.value)
            if framework.menu.currentItem == item then
                item.drawings.textShadow.Text = item.text.. " <"..tostring(item.value).."> <"
                item.drawings.text.Text = item.text.. " <"..tostring(item.value).."> <"
                item:hover(true)
            end
        end

        framework.menu.offset += 15

        if #framework.menu.list == 0 then
            window:selectItem({item = item})
        end
        
        insert(framework.menu.list, item)
        return item
    end

    function window:createKeybind(args)
        local item = 
        {
        text = args.text or "",
        key = args.defaultKey or "unbound",
        track = args.trackType or "Toggle",
        state = false,
        drawings = {},
        type = args.type or "keybind",
        callback = args.callback or function() end,
        flag = args.flag or ""
        }

        item.drawings.textShadow = framework("draw", {class = "Text", properties = {
            Text = item.text.. " <"..tostring(item.key)..">",
            Font = framework.theme.font,
            Size = framework.theme.fontSize,
            Position = framework("udim", {type = "position", xScale = 0, xOffset = 0, yScale = 0, yOffset = framework.menu.offset, relativeFrom = window.textShadow}),
            Visible = framework.menu.open,
            Transparency = 1,
            Color = nRGB(0,0,0)
        }})
    
        item.drawings.text = framework("draw", {class = "Text", properties = {
            Text = item.text.. " <"..tostring(item.key)..">",
            Font = framework.theme.font,
            Size = framework.theme.fontSize,
            Position = framework("udim", {type = "position", xScale = 0, xOffset = -1, yScale = 0, yOffset = -1, relativeFrom = item.drawings.textShadow}),
            Visible = framework.menu.open,
            Transparency = 1,
            Color = nRGB(255,255,255)
        }})

        function item:setKey(Input)
            if Input then
                item.key = Input.KeyCode.Name ~= "Unknown" and Input.KeyCode.Name or Input.UserInputType.Name
                item.drawings.textShadow.Text = item.text.. " <"..tostring(item.key).."> <"
                item.drawings.text.Text = item.text.. " <"..tostring(item.key).."> <"
                framework.flags[item.flag][1] = item.key
            else
                item.key = "unbound"
                item.state = false
                item.drawings.textShadow.Text = item.text.. " <unbound> <"
                item.drawings.text.Text = item.text.. " <unbound> <"
                framework.flags[item.flag][1] = item.key
            end
        end

        function item:setText(text)
            item.drawings.textShadow.Text = text
            item.drawings.text.Text = text
        end

        function item:hover(bool)
            if bool then
                item.drawings.text.Color = nRGB(2,144,252)
            else
                item.drawings.text.Color = nRGB(255,255,255)    
            end
        end

        function item:refresh()
            item.key = framework.flags[item.flag][1]
            item.state = framework.flags[item.flag][2]
            item.drawings.textShadow.Text = item.text.. " <"..tostring(item.key)..">"
            item.drawings.text.Text = item.text.. " <"..tostring(item.key)..">"
            item:hover(false)
            if framework.menu.currentItem == item then
                item.drawings.textShadow.Text = item.text.. " <"..tostring(item.key).."> <"
                item.drawings.text.Text = item.text.. " <"..tostring(item.key).."> <"
                item:hover(true)
            end
        end

        framework.menu.offset += 15

        if #framework.menu.list == 0 then
            window:selectItem({item = item})
        end

        framework.flags[item.flag] = {item.key, item.state}

        insert(framework.menu.keybinds, item)
        insert(framework.menu.list, item)
        return item
    end

    self("createConnection", {connection = UserInputService.InputBegan, name = "MenuInputBegan", callback = function(Input)
        if self.menu.bindingKey then
            self.menu.bindingKey = false
            if Input.KeyCode.Name ~= "Unknown" and Input.KeyCode.Name:upper() or Input.UserInputType.Name:upper() then
                if Input.KeyCode.Name == "Delete" then
                    self.menu.currentItem:setKey()
                else
                    self.menu.currentItem:setKey(Input)
                end
            end
        else
            if Input.KeyCode == Enum.KeyCode.Home then
                for i,v in next, self.menu.drawings do
                    if type(v) == 'table' and rawget(v, '__OBJECT_EXISTS') then
                        v.Visible = not v.Visible
                    end
                end
                self.menu.open = not self.menu.open
            elseif Input.KeyCode == Enum.KeyCode.End then
                self("unload")
            elseif Input.KeyCode == Enum.KeyCode.PageUp then
                self("saveConfig")
            elseif Input.KeyCode == Enum.KeyCode.PageDown then
                self("loadConfig")
            else
                if self.menu.open then
                    if Input.KeyCode == Enum.KeyCode.KeypadEight then
                        local indexCurrent = find(framework.menu.list, framework.menu.currentItem)
                        if indexCurrent then
                            if framework.menu.list[indexCurrent-1] ~= nil then
                                window:selectItem({item = framework.menu.list[indexCurrent-1]})
                            else
                                window:selectItem({item = framework.menu.list[#framework.menu.list]})
                            end
                        end
                    end
                    if Input.KeyCode == Enum.KeyCode.KeypadTwo then
                        local indexCurrent = find(framework.menu.list, framework.menu.currentItem)
                        if indexCurrent then
                            if framework.menu.list[indexCurrent+1] ~= nil then
                                window:selectItem({item = framework.menu.list[indexCurrent+1]})
                            else
                                window:selectItem({item = framework.menu.list[1]})
                            end
                        end
                    end
                    if Input.KeyCode == Enum.KeyCode.KeypadSix then
                        if self.menu.currentItem.type ~= "label" then
                            if self.menu.currentItem.type == "int" then
                                self.menu.currentItem:offset({offset = self.menu.currentItem.precision})
                            end
                            if self.menu.currentItem.type == "toggle" then
                                self.menu.currentItem:toggle()
                            end
                            if self.menu.currentItem.type == "list" then
                                local indexCurrent = find(self.menu.currentItem.list, self.menu.currentItem.value)
                                if indexCurrent then
                                    if self.menu.currentItem.list[indexCurrent+1] ~= nil then
                                        self.menu.currentItem:selectOption(self.menu.currentItem.list[indexCurrent+1])
                                    end
                                end
                            end
                            if self.menu.currentItem.type == "keybind" then
                                self.menu.currentItem:setText(self.menu.currentItem.text.." <...> <")
                               self.menu.bindingKey = true
                            end
                        end
                    end 
                    if Input.KeyCode == Enum.KeyCode.KeypadFour then
                        if self.menu.currentItem.type ~= "label" then
                            if self.menu.currentItem.type == "int" then
                                self.menu.currentItem:offset({offset = -self.menu.currentItem.precision})
                            end
                            if self.menu.currentItem.type == "toggle" then
                                self.menu.currentItem:toggle()
                            end
                            if self.menu.currentItem.type == "list" then
                                local indexCurrent = find(self.menu.currentItem.list, self.menu.currentItem.value)
                                if indexCurrent then
                                    if self.menu.currentItem.list[indexCurrent-1] ~= nil then
                                        self.menu.currentItem:selectOption(self.menu.currentItem.list[indexCurrent-1])
                                    end
                                end
                            end
                            if self.menu.currentItem.type == "keybind" then
                                self.menu.currentItem:setText(self.menu.currentItem.text.." <...> <")
                               self.menu.bindingKey = true
                            end
                        end
                    end
                end
                for i,v in next, self.menu.keybinds do
                    if v.key ~= "unbound" then 
                        if string.find(v.key, "Mouse") then
                            if Input.UserInputType == Enum.UserInputType[v.key] then
                                if v.track == "Hold" then
                                    v.state = true
                                    self.flags[v.flag][2] = true
                                    v.callback(v)
                                elseif v.track == "Toggle" then
                                    v.state = not v.state
                                    v.callback(v)
                                end
                            end
                        else
                            if Input.KeyCode == Enum.KeyCode[v.key] then
                                if v.track == "Hold" then
                                    v.state = true
                                    self.flags[v.flag][2] = true
                                    v.callback(v)
                                elseif v.track == "Toggle" then
                                    v.state = not v.state
                                    v.callback(v)
                                end
                            end
                        end
                    end
                end
            end
        end
    end})

    self("createConnection", {connection = UserInputService.InputEnded, name = "MenuInputEnded", callback = function(Input)
        for i,v in next, self.menu.keybinds do
            if v.key ~= "unbound" then
                if string.find(v.key, "Mouse") then
                    if Input.UserInputType == Enum.UserInputType[v.key] then
                        if v.track == "Hold" then
                            v.state = false
                            self.flags[v.flag][2] = false
                            v.callback(v)
                        end
                    end
                else
                    if Input.KeyCode == Enum.KeyCode[v.key] then
                        if v.track == "Hold" then
                            v.state = false
                            self.flags[v.flag][2] = false
                            v.callback(v)
                        end
                    end
                end
            end
        end
    end})

    return window
end
return framework
