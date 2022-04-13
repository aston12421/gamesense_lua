--< Libraries >-----------------------------------------------------------
local vector = require "vector"
local ease = require "gamesense/easing"
local http = require "gamesense/http"
local notify = require "libs.notify_new"

--< Functions >-----------------------------------------------------------

local function measure_text(flags, ...)
    local args = { ... }
    local text = table.concat(args, "")
    local x, y = renderer.measure_text(flags, text)
    return { x = x, y = y }
end

local function contains(tbl, val, key)
    for k, v in pairs(tbl) do
        if key then
            if v[key] == val then
                return true
            end
        else
            if v == val then
                return true
            end
        end
    end
    return false
end

local function dump(o)
    if type(o) == 'table' then
       local s = '{ '
       for k,v in pairs(o) do
          if type(k) ~= 'number' then k = '"'..k..'"' end
          s = s .. '['..k..'] = ' .. dump(v) .. ','
       end
       return s .. '} '
    else
       return tostring(o)
    end
 end

local function exists(tbl, val, key, val2, key2, val3, key3)
    for k, v in pairs(tbl) do
        if key then
            if v[key] == val then
                if key2 then
                    if v[key2] == val2 then
                        if key3 then
                            if v[key3] == val3 then
                                return true
                            end
                        else
                            return true
                        end
                    end
                else
                    return true
                end
            end
        else
            if v == val then
                if key2 then
                    if v[key2] == val2 then
                        if key3 then
                            if v[key3] == val3 then
                                return true
                            end
                        else
                            return true
                        end
                    end
                else
                    return true
                end
            end
        end
    end
    return false
end

local function warning(...)
    local args = { ... }
    local text = table.concat(args, " ")
    client.color_log(255, 40, 40, "[WARNING] \0")
    client.color_log(255, 255, 255, text)
end

local function index_of(t, value)
    for i, v in ipairs(t) do
        if v == value then
            return i
        end
    end
end

-- render a rectangle with a border
local function render_rect(x, y, w, h, r, g, b, a, r2, g2, b2, a2, border_width)
    renderer.rectangle(x, y, w, h, r, g, b, a)
    renderer.rectangle(x + border_width, y + border_width, w - border_width * 2, h - border_width * 2, r2, g2, b2, a2)
end

-- render a gradient rectangle with a border
local function render_gradient_rect(x, y, w, h, r, g, b, a, r2, g2, b2, a2, r3, g3, b3, a3, border_width)
    renderer.rectangle(x + border_width, y + border_width, w - border_width * 2, h - border_width * 2, r3, g3, b3, a3)
    renderer.gradient(x, y, w, h, r, g, b, a, r2, g2, b2, a2)
end



--< Globals >-----------------------------------------------------------------

local saved_menu_pos = database.read(":carbon::menu_pos:") or vector(500, 500)

local sui = {
    x = saved_menu_pos.x,
    y = saved_menu_pos.y,
    w = 500,
    h = 350,
    padding = 10,
    color = {
        background = { r = 25, g = 25, b = 30, a = 255 },
        text = { r = 200, g = 200, b = 210, a = 255 },
        accent = { r = 122, g = 122, b = 255, a = 255 },
        foreground = { r = 35, g = 35, b = 40, a = 255 },
        border = { r = 45, g = 45, b = 50, a = 255 },
        dark = { r = 15, g = 15, b = 20, a = 255 }
    },
    active_tab = "Config",
    drag = {
        dragging = false,
        in_drag = false,
        pos = vector(0, 0),
        hovering = false
    },
    clicked = false,
    mouse_up = 0
}

local tab_icons = {
    ["Rage"] = nil,
    ["Antiaim"] = nil,
    ["Visuals"] = nil,
    ["Misc"] = nil,
    ["Config"] = nil
}

local tab_icon_urls = {
    ["Rage"] = "https://i.imgur.com/NjODelf.png",
    ["Antiaim"] = "https://imgur.com/tgynkaX.png",
    ["Visuals"] = "https://imgur.com/apjelJP.png",
    ["Misc"] = "https://imgur.com/XaQ5kUD.png",
    ["Config"] = "https://imgur.com/oKvjKEr.png"
}

for tab, url in pairs(tab_icon_urls) do
    if url == nil then goto skip end
    http.get(url, function(s, r)
        if s and r.status == 200 then
            tab_icons[tab] = renderer.load_png(r.body, 100, 100)
        end  
    end)
    ::skip::
end

sui.__index = sui
sui.__tabs = {}
sui.__containers = {}
sui.__elements = {}

--< MetaMethods >-----------------------------------------------------------

function sui:new_checkbox(tab, container, name, value, tooltip)
    if not contains(sui.__tabs, tab, "name") then
        table.insert(sui.__tabs, {
            name = tab,
            x = 0,
            y = 0,
            w = 0,
            h = 0,
            col = { r = 15, g = 15, b = 20, a = 255 },
            hovering = false,
            visible = true
        })
    end

    if not exists(sui.__containers, container, "name", tab, "tab") then
        if self:max_containers(tab) < 2 then
            table.insert(sui.__containers, {
                name = container,
                tab = tab,
                x = 0,
                y = 0,
                w = 0,
                h = 0,
                visible = true
            })
        else
            warning("Too many containers in tab " .. tab .. "!")
        end
    end

    if exists(sui.__elements, name, "name", container, "container", tab, "tab") then
        warning("Element " .. name .. " already exists!")
        return
    end

    local element = {
        type = "checkbox",
        tab = tab,
        container = container,
        name = name,
        value = value,
        tooltip = {
            text = tooltip,
            visible = false,
            opacity = 0,
            hover_time = 0
        },
        hovering = false,
        hovering_text = false,
        clicked = false,
        name_x = 0,
        name_y = 0,
        x = 0,
        y = 0,
        w = 10,
        h = 10,
        extended_h = 10,
        visible = true
    }

    setmetatable(element, self)
    table.insert(sui.__elements, element)
    return element
end

function sui:new_slider(tab, container, name, value, min, max, tooltip)
    if not contains(sui.__tabs, tab, "name") then
        table.insert(sui.__tabs, {
            name = tab,
            x = 0,
            y = 0,
            w = 0,
            h = 0,
            col = { r = 15, g = 15, b = 20, a = 255 },
            hovering = false,
            visible = true
        })
    end

    if not exists(sui.__containers, container, "name", tab, "tab") then
        if self:max_containers(tab) < 2 then
            table.insert(sui.__containers, {
                name = container,
                tab = tab,
                x = 0,
                y = 0,
                w = 0,
                h = 0,
                visible = true
            })
        else
            warning("Too many containers in tab " .. tab .. "!")
            return
        end
    end

    if exists(sui.__elements, name, "name", container, "container", tab, "tab") then
        warning("Element " .. name .. " already exists!")
        return
    end

    local element = {
        type = "slider",
        tab = tab,
        container = container,
        name = name,
        value = value,
        eased_value = 0,
        tooltip = {
            text = tooltip,
            visible = false,
            opacity = 0,
            hover_time = 0
        },
        hovering = false,
        hovering_text = false,
        clicked = false,
        name_x = 0,
        name_y = 0,
        x = 0,
        y = 0,
        w = 10,
        h = 10,
        extended_h = 25,
        min = min,
        max = max,
        visible = true
    }

    setmetatable(element, self)
    table.insert(sui.__elements, element)
    return element
end

function sui:new_button(tab, container, name, tooltip, func)
    if not contains(sui.__tabs, tab, "name") then
        table.insert(sui.__tabs, {
            name = tab,
            x = 0,
            y = 0,
            w = 0,
            h = 0,
            col = { r = 15, g = 15, b = 20, a = 255 },
            hovering = false,
            visible = true
        })
    end

    if not exists(sui.__containers, container, "name", tab, "tab") then
        if self:max_containers(tab) < 2 then
            table.insert(sui.__containers, {
                name = container,
                tab = tab,
                x = 0,
                y = 0,
                w = 0,
                h = 0,
                visible = true
            })
        else
            warning("Too many containers in tab " .. tab .. "!")
        end
    end

    if exists(sui.__elements, name, "name", container, "container", tab, "tab") then
        warning("Element " .. name .. " already exists!")
        return
    end

    local element = {
        type = "button",
        tab = tab,
        container = container,
        name = name,
        tooltip = {
            text = tooltip,
            visible = false,
            opacity = 0,
            hover_time = 0
        },
        hovering = false,
        hovering_text = false,
        clicked = false,
        name_x = 0,
        name_y = 0,
        x = 0,
        y = 0,
        w = 10,
        h = 22,
        extended_h = 22,
        visible = true,
        func = func
    }

    setmetatable(element, self)
    table.insert(sui.__elements, element)
    return element
end

function sui:new_combo(tab, container, name, value, tooltip, ...)
    if not contains(sui.__tabs, tab, "name") then
        table.insert(sui.__tabs, {
            name = tab,
            x = 0,
            y = 0,
            w = 0,
            h = 0,
            col = { r = 15, g = 15, b = 20, a = 255 },
            hovering = false,
            visible = true
        })
    end

    if not exists(sui.__containers, container, "name", tab, "tab") then
        if self:max_containers(tab) < 2 then
            table.insert(sui.__containers, {
                name = container,
                tab = tab,
                x = 0,
                y = 0,
                w = 0,
                h = 0,
                visible = true
            })
        else
            warning("Too many containers in tab " .. tab .. "!")
            return
        end
    end

    if exists(sui.__elements, name, "name", container, "container", tab, "tab") then
        warning("Element " .. name .. " already exists!")
        return
    end

    local list = {}

    for i, v in ipairs({ ... }) do
        table.insert(list, {
            x = 0,
            y = 0,
            w = 100,
            h = 20,
            hovering = false,
            value = v
        })
    end

    local element = {
        type = "combo",
        tab = tab,
        container = container,
        name = name,
        value = value,
        open = false,
        list = list,
        eased_value = 0,
        tooltip = {
            text = tooltip,
            visible = false,
            opacity = 0,
            hover_time = 0
        },
        hovering = false,
        hovering_text = false,
        clicked = false,
        name_x = 0,
        name_y = 0,
        x = 0,
        y = 0,
        w = 10,
        h = 20,
        extended_h = 30,
        visible = true
    }

    setmetatable(element, self)
    table.insert(sui.__elements, element)
    return element
end

function sui:new_multicombo(tab, container, name, value, tooltip, ...)
    if not contains(sui.__tabs, tab, "name") then
        table.insert(sui.__tabs, {
            name = tab,
            x = 0,
            y = 0,
            w = 0,
            h = 0,
            col = { r = 15, g = 15, b = 20, a = 255 },
            hovering = false,
            visible = true
        })
    end

    if not exists(sui.__containers, container, "name", tab, "tab") then
        if self:max_containers(tab) < 2 then
            table.insert(sui.__containers, {
                name = container,
                tab = tab,
                x = 0,
                y = 0,
                w = 0,
                h = 0,
                visible = true
            })
        else
            warning("Too many containers in tab " .. tab .. "!")
            return
        end
    end

    if exists(sui.__elements, name, "name", container, "container", tab, "tab") then
        warning("Element " .. name .. " already exists!")
        return
    end

    local list = {}

    for i, v in ipairs({ ... }) do
        table.insert(list, {
            x = 0,
            y = 0,
            w = 100,
            h = 20,
            hovering = false,
            value = v
        })
    end

    local element = {
        type = "multicombo",
        tab = tab,
        container = container,
        name = name,
        value = value,
        open = false,
        list = list,
        eased_value = 0,
        tooltip = {
            text = tooltip,
            visible = false,
            opacity = 0,
            hover_time = 0
        },
        hovering = false,
        hovering_text = false,
        clicked = false,
        name_x = 0,
        name_y = 0,
        x = 0,
        y = 0,
        w = 10,
        h = 20,
        extended_h = 30,
        visible = true
    }

    setmetatable(element, self)
    table.insert(sui.__elements, element)
    return element
end

function sui:max_containers(tab)
    local max = 0
    for i, container in pairs(sui.__containers) do
        if container.tab == tab then
            max = max + 1
        end
    end
    return max
end


function sui:get()
    for i, tab in pairs(sui.__tabs) do
        for i, container in pairs(sui.__containers) do
            for i, element in pairs(sui.__elements) do
                if element.name == self.name and element.container == container.name and element.tab == tab.name then
                    return element.value
                end
            end
        end
    end
    return false
end

function sui:set(value)
    for i, tab in pairs(sui.__tabs) do
        for i, container in pairs(sui.__containers) do
            for i, element in pairs(sui.__elements) do
                if element.name == self.name and self.container == container.name and self.tab == tab.name then
                    element.value = value
                    return true
                end
            end
        end
    end
    return false
end


-- get all elements inside of an specified container and tab
function sui:get_all(tab, container)
    local elements = {}
    for i, element in pairs(sui.__elements) do
        if element.tab == tab and element.container == container then
            table.insert(elements, element)
        end
    end
    return elements
end

function sui:set_visible(visible)
    for i, element in pairs(sui.__elements) do
        if element.name == self.name and element.container == self.container then
            element.visible = visible
        end
    end

    local elems = self:get_all(self.tab, self.container)

    local visible_elems = 0

    for i, element in pairs(elems) do
        if element.visible then
            visible_elems = visible_elems + 1
        end
    end

    for i, tab in pairs(sui.__tabs) do
        if tab.name == self.tab then
            tab.visible = visible_elems > 0
        end
    end

    for i, container in pairs(sui.__containers) do
        if container.name == self.container then
            container.visible = visible_elems > 0
        end
    end
end

function sui:click_handler()
    local mouse_down = client.key_state(0x1)
    if mouse_down then
        if self.mouse_up < 1 then
            self.clicked = true
        end
    else
        self.clicked = false
        self.mouse_up = 0
    end

    if self.clicked then
        self.mouse_up = self.mouse_up + 1
    end

    if self.mouse_up > 1 then
        self.clicked = false
    end
end

function sui:drag_handler()
    local mouse_down = client.key_state(0x1)
    local mouse = vector(ui.mouse_position())

    if sui:element_clicked() then
        return
    end

    if self.drag.hovering then
        self.drag.dragging = mouse_down
    end

    if self.drag.dragging then
        if not self.drag.in_drag then
            self.drag.pos.x = mouse.x - self.x
            self.drag.pos.y = mouse.y - self.y
            self.drag.in_drag = true
        end
    end

    if self.drag.dragging then
        self.x = mouse.x - self.drag.pos.x
        self.y = mouse.y - self.drag.pos.y
    else
        self.drag.in_drag = false
    end
end

-- loop through elements and if clicked then return true else return false
function sui:element_clicked()
    for i, element in pairs(sui.__elements) do
        if element.clicked then
            return true
        end
    end
    return false
end

function sui:load_config(slot)
    local config = database.read(":carbon::config::".. slot..":")
    if config == nil then
        print("Config not found!")
        return
    end

    for i, element in pairs(sui.__elements) do
        for i, config_element in pairs(config) do
            if element.name == config_element.name and element.container == config_element.container and element.tab == config_element.tab then
                element.value = config_element.value
            end
        end
    end

    notify.new(5, {self.color.accent.r, self.color.accent.g, self.color.accent.b}, "CARBON", "Loaded ", slot)
end

function sui:save_config(slot)
    local config = {}

    for i, element in ipairs(sui.__elements) do
        if element.type == "button" then goto skip end
        table.insert(config, {
            name = element.name,
            value = element.value,
            container = element.container,
            tab = element.tab
        })
        
        ::skip::
    end

    database.write(":carbon::config::"..slot..":", config)
    notify.new(5, {self.color.accent.r, self.color.accent.g, self.color.accent.b}, "CARBON", "Saved current settings to", slot)
end



function sui:handler()
    local menu_open = ui.is_menu_open()
    local mouse = vector(ui.mouse_position())
    local screen = vector(client.screen_size())
    local mouse_down = client.key_state(0x1)

    if not menu_open then
        return
    end

    local menu_hovered = mouse.x >= self.x - self.padding and mouse.x <= self.x + self.w + (self.padding) and mouse.y >= self.y - (self.padding*2) and mouse.y <= self.y + self.h + (self.padding*2)
    self.drag.hovering = mouse.y >= self.y - self.padding and mouse.y <= self.y + self.padding and mouse.x >= self.x + self.w/7 + self.padding and mouse.x <= self.x + self.w + self.padding

    self:click_handler()
    self:drag_handler()

    for i, tab in ipairs(sui.__tabs) do
        tab.hovering = mouse.x >= tab.x and mouse.x <= tab.x + tab.w and mouse.y >= tab.y and mouse.y <= tab.y + tab.h

        if tab.hovering then
            if self.clicked then
                self.active_tab = tab.name
            end
        end

        for i, element in ipairs(sui.__elements) do
            if element.tab ~= self.active_tab or not element.visible then
                goto skip
            end

            --< Toolip Handler >------------------------------------------------------
            element.tooltip.visible = element.hovering_text and element.tooltip.hover_time >= 150

            if element.hovering_text then
                element.tooltip.hover_time = math.min(element.tooltip.hover_time + 1, 150)
            else
                element.tooltip.hover_time = 0
            end

            element.hovering = mouse.x >= element.x and mouse.x <= element.x + element.w and mouse.y >= element.y and mouse.y <= element.y + element.h

            --< Checkbox Element >-----------------------------------------------------
            if element.type == "checkbox" then
                element.hovering = mouse.x >= element.x and mouse.x <= element.x + element.w + measure_text("", element.name).x + self.padding and mouse.y >= element.y and mouse.y <= element.y + element.h
                element.hovering_text = mouse.x >= element.name_x and mouse.x <= element.name_x + measure_text("", element.name).x and mouse.y >= element.name_y and mouse.y <= element.name_y + measure_text("", element.name).y

                if not mouse_down then
                    element.clicked = false
                end
        
                if element.hovering or element.hovering_text then
                    if self.clicked then
                        element.value = not element.value
                        element.clicked = true
                    end
                end
            end

            --< Slider Element >------------------------------------------------------
            if element.type == "slider" then
                element.hovering_text = mouse.x >= element.name_x and mouse.x <= element.name_x + measure_text("", element.name).x and mouse.y >= element.name_y and mouse.y <= element.name_y + measure_text("", element.name).y
            
                if mouse_down then
                    if element.hovering and not element.clicked then
                        if not sui:element_clicked() then
                            element.clicked = true
                        end
                    end
                
                    if element.clicked then
                        local slider_percent = math.min(1, math.max(0, (mouse.x - element.x) / element.w))
                        element.value = math.floor(slider_percent * (element.max - element.min) + element.min)
                    end
                else
                    element.clicked = false
                end
            end

            --< Combo Element >-------------------------------------------------------
            if element.type == "combo" then
                element.hovering_text = mouse.x >= element.name_x and mouse.x <= element.name_x + measure_text("", element.name).x and mouse.y >= element.name_y and mouse.y <= element.name_y + measure_text("", element.name).y

                for i, item in ipairs(element.list) do
                    item.hovering = mouse.x > item.x and mouse.x < item.x + item.w and mouse.y > item.y and mouse.y < item.y + item.h
        
                    if not mouse_down then
                        element.clicked = false
                    end
            
                    if item.hovering then
                        if element.open then
                            if self.clicked then
                                element.value = item.value
                            end
                        end
                    end
                end
        
                if self.clicked then
                    if element.hovering then
                        element.open = not element.open
                        element.clicked = true
                    else
                        element.open = false
                    end
                end
            end

            --< Multi Combo Element >-------------------------------------------------------
            if element.type == "multicombo" then
                element.hovering_text = mouse.x >= element.name_x and mouse.x <= element.name_x + measure_text("", element.name).x and mouse.y >= element.name_y and mouse.y <= element.name_y + measure_text("", element.name).y

                for i, item in ipairs(element.list) do
                    item.hovering = mouse.x > item.x and mouse.x < item.x + item.w and mouse.y > item.y and mouse.y < item.y + item.h
        
                    if not mouse_down then
                        element.clicked = false
                    end

                    if item.hovering then
                        if element.open then
                            if self.clicked then
                                if contains(element.value, item.value) then
                                    table.remove(element.value, index_of(element.value, item.value))
                                else
                                    table.insert(element.value, item.value)
                                end
                            end
                        end
                    end
                end

        
                if self.clicked then
                    if element.hovering then
                        element.open = not element.open
                        element.clicked = true
                    end
                end
            end


            --< Button Element >------------------------------------------------------
            if element.type == "button" then
                element.hovering_text = mouse.x >= element.name_x and mouse.x <= element.name_x + measure_text("", element.name).x and mouse.y >= element.name_y and mouse.y <= element.name_y + measure_text("", element.name).y

                if not mouse_down then
                    element.clicked = false
                end

                if element.hovering then
                    if self.clicked and not element.clicked then
                        element.func()
                        element.clicked = true
                    end
                end
            end

            ::skip::
        end
    end
end

function sui:renderer()
    local menu_open = ui.is_menu_open()
    local mouse = vector(ui.mouse_position())
    local screen = vector(client.screen_size())
    local mouse_down = client.key_state(0x1)

    if not menu_open then
        return
    end

    -- render menu base
    
    renderer.rectangle(self.x - (self.padding/2) - 1, self.y - (self.padding/2) - 1, self.w + self.padding + 2, self.h + self.padding + 2, self.color.border.r, self.color.border.g, self.color.border.b, self.color.border.a)

    renderer.rectangle(self.x - (self.padding/2), self.y - (self.padding/2), self.w + self.padding, self.h + self.padding, self.color.foreground.r, self.color.foreground.g, self.color.foreground.b, self.color.foreground.a)
    
    renderer.rectangle(self.x - 1, self.y - 1, self.w + 2, self.h + 2, self.color.foreground.r + 10, self.color.border.r, self.color.border.g, self.color.border.b, self.color.border.a)

    renderer.rectangle(self.x, self.y, self.w, self.h, self.color.background.r, self.color.background.g, self.color.background.b, self.color.background.a)
    
    renderer.rectangle(self.x, self.y, self.w/7, self.h, self.color.dark.r, self.color.dark.g, self.color.dark.b, self.color.dark.a)

    -- render all tabs
    for i, tab in ipairs(sui.__tabs) do
        tab.x = self.x
        tab.y = self.y + ((i-1) * (tab.h))
        tab.w = self.w/7
        tab.h = self.h/5

        local c = tab.name == self.active_tab and self.color.text or tab.hovering and { r = 130, g = 130, b = 140, a = 255 } or { r = 100, g = 100, b = 110, a = 255 }

        if tab.name == self.active_tab then
            renderer.rectangle(tab.x, tab.y, tab.w, tab.h, self.color.background.r, self.color.background.g, self.color.background.b, self.color.background.a)
        end
        
        -- render tab text
        if tab_icons[tab.name] == nil then
            renderer.text(tab.x + (tab.w/2), tab.y + (tab.h/2), self.color.text.r, self.color.text.g, self.color.text.b, self.color.text.a, "c", 0, tab.name)
        else
            renderer.texture(tab_icons[tab.name], tab.x + (tab.w/4), tab.y + (tab.h/4), tab.w/2, tab.h/2, c.r, c.g, c.b, c.a, "f")
        end

        local c_gap = 0

        -- render all containers
        for i, container in ipairs(sui.__containers) do
            if self.active_tab ~= container.tab or not container.visible then
                goto skip
            end

            container.x = self.x + tab.w + self.padding + c_gap
            container.y = self.y + self.padding
            container.w = (self.w/2) - (tab.w/2) - (self.padding*1.5)
            container.h = self.h - (self.padding*2)

            -- render container background
            renderer.rectangle(container.x, container.y, container.w, container.h, self.color.foreground.r, self.color.foreground.g, self.color.foreground.b, self.color.foreground.a)
            
            -- render container text
            renderer.rectangle(container.x + self.padding, container.y + self.padding, container.w - (self.padding*2), 2, self.color.border.r, self.color.border.g, self.color.border.b, self.color.border.a)
            renderer.rectangle(container.x + (self.padding*2.5), container.y + (self.padding/2), measure_text("b", container.name).x + self.padding, 10, self.color.background.r + 10, self.color.background.g + 10, self.color.background.b + 10, self.color.background.a)
            renderer.text(container.x + (self.padding*3), container.y + (self.padding/2), self.color.text.r, self.color.text.g, self.color.text.b, self.color.text.a, "b", 0, container.name)
            
            c_gap = c_gap + container.w + self.padding
            
            local e_gap = 0

            -- render all elements
            for i, element in ipairs(sui.__elements) do
                if self.active_tab ~= element.tab or not element.visible then
                    if element.type == "slider" then
                       element.eased_value = 0
                    end
                    goto skip
                end

                if container.name ~= element.container then
                    goto skip
                end

                -- render checkbox element
                if element.type == "checkbox" then
                    element.x = container.x + self.padding
                    element.y = container.y + self.padding*3 + e_gap
                    element.name_x = container.x + (self.padding*3)
                    element.name_y = element.y - 2
                
                    -- render element background
                    renderer.rectangle(element.x, element.y, element.w, element.h, self.color.background.r, self.color.background.g, self.color.background.b, self.color.background.a)
                
                    local col = element.value and self.color.accent or self.color.dark
                    renderer.rectangle(element.x + 2, element.y + 2, element.w - 4, element.h - 4, col.r, col.g, col.b, col.a)
                    -- render element text
                    renderer.text(element.name_x, element.name_y, self.color.text.r, self.color.text.g, self.color.text.b, self.color.text.a, "", 0, element.name)
                end

                -- render slider element
                if element.type == "slider" then
                    element.x = container.x + (self.padding*3)
                    element.y = container.y + self.padding*4.5 + e_gap
                    element.w = container.w - (self.padding*6)
                    element.name_x = container.x + (self.padding*3)
                    element.name_y = container.y + self.padding*3 + e_gap

                    local slider_w = (element.value - element.min) / (element.max - element.min) * (element.w - 4)
                    element.eased_value = ease.quad_in(element.clicked and 0.3 or 0.2, element.eased_value, slider_w - element.eased_value, 1)

                    -- render element background
                    renderer.rectangle(element.x, element.y, element.w, element.h, self.color.background.r, self.color.background.g, self.color.background.b, self.color.background.a)
                    -- render element value bar
                    renderer.rectangle(element.x + 2, element.y + 3, element.w - 4, element.h - 6, self.color.dark.r, self.color.dark.g, self.color.dark.b, self.color.dark.a)
                    renderer.rectangle(element.x + 2, element.y + 3, element.eased_value, element.h - 6, self.color.accent.r, self.color.accent.g, self.color.accent.b, self.color.accent.a)
                    -- render element value in text form
                    renderer.text(element.x + 2 + element.eased_value, element.y + 3, self.color.text.r, self.color.text.g, self.color.text.b, self.color.text.a, "", 0, element.value)
                    -- render element text
                    renderer.text(element.name_x, element.name_y, self.color.text.r, self.color.text.g, self.color.text.b, self.color.text.a, "", 0, element.name)
                end

                if element.type == "button" then
                    element.x = container.x + (self.padding*3)
                    element.y = container.y + self.padding*3 + e_gap
                    element.w = container.w - (self.padding*6)
                    element.name_x = container.x + (self.padding*3) + (element.w/2) - (measure_text("", element.name).x/2)
                    element.name_y = container.y + self.padding*3 + e_gap + (element.h/2) - (measure_text("", element.name).y/2)

                    -- render element background
                    renderer.rectangle(element.x, element.y, element.w, element.h, self.color.border.r + 10, self.color.border.g + 10, self.color.border.b + 10, self.color.border.a)

                    if element.hovering then
                        if element.clicked then
                            renderer.gradient(element.x + 1, element.y + 1, element.w - 2, element.h - 2, self.color.border.r, self.color.border.g, self.color.border.b, self.color.border.a, self.color.foreground.r, self.color.foreground.g, self.color.foreground.b, self.color.foreground.a, false)
                        else
                            renderer.rectangle(element.x + 1, element.y + 1, element.w - 2, element.h - 2, self.color.border.r, self.color.border.g, self.color.border.b, self.color.border.a)
                        end
                    else
                        renderer.gradient(element.x + 1, element.y + 1, element.w - 2, element.h - 2, self.color.border.r, self.color.border.g, self.color.border.b, self.color.border.a, self.color.foreground.r, self.color.foreground.g, self.color.foreground.b, self.color.foreground.a - 40, false)
                    end
                    
                    -- render element text
                    renderer.text(element.name_x, element.name_y, self.color.text.r, self.color.text.g, self.color.text.b, self.color.text.a, "", 0, element.name)
                end

                if element.type == "combo" then
                    element.x = container.x + (self.padding*3)
                    element.y = container.y + self.padding*4.5 + e_gap
                    element.w = container.w - (self.padding*6)
                    element.name_x = container.x + (self.padding*3)
                    element.name_y = container.y + self.padding*3 + e_gap

                    renderer.rectangle(element.x, element.y, element.w, element.h, self.color.border.r + 10, self.color.border.g + 10, self.color.border.b + 10, self.color.border.a)
                    
                    if element.hovering then
                        renderer.rectangle(element.x + 1, element.y + 1, element.w - 2, element.h - 2, self.color.border.r, self.color.border.g, self.color.border.b, self.color.border.a)
                    else
                        renderer.gradient(element.x + 1, element.y + 1, element.w - 2, element.h - 2, self.color.border.r, self.color.border.g, self.color.border.b, self.color.border.a, self.color.foreground.r, self.color.foreground.g, self.color.foreground.b, self.color.foreground.a - 40, false)
                    end

                    if element.open then
                        renderer.triangle(element.x + element.w - 12, element.y + element.h/2 + 1.5, element.x + element.w - 6, element.y + element.h/2 + 1.5, element.x + element.w - 9, element.y + element.h/2 - 1.5, self.color.text.r, self.color.text.g, self.color.text.b, self.color.text.a)

                        renderer.rectangle(element.x, element.y + element.h, element.w, #element.list * element.h, self.color.border.r + 10, self.color.border.g + 10, self.color.border.b + 10, self.color.border.a)
                        renderer.rectangle(element.x + 1, element.y + element.h + 1, element.w - 2, #element.list * element.h - 2, self.color.border.r, self.color.border.g, self.color.border.b, self.color.border.a)

                        for i, v in pairs(element.list) do
                            v.y = element.y + ((i) * element.h)
                            v.x = element.x
                            v.w = element.w
                            local c = v.value == element.value and self.color.accent or (v.hovering and { r = 255, g = 255, b = 255, a = 255 } or self.color.text)
                            if v.hovering then
                                renderer.rectangle(v.x + 1, v.y + 1, element.w - 2, element.h - 2, self.color.border.r - 12, self.color.border.g - 12, self.color.border.b - 12, self.color.border.a)
                            end
                            renderer.text(v.x + (self.padding/2), v.y + element.h/2 - measure_text("", v.value).y/2, c.r, c.g, c.b, c.a, "", 0, v.value)
                        end
                        element.extended_h = (#element.list * element.h) + element.h + (self.padding*1.5)
                    else
                        renderer.triangle(element.x + element.w - 12, element.y + element.h/2 - 1.5, element.x + element.w - 6, element.y + element.h/2 - 1.5, element.x + element.w - 9, element.y + element.h/2 + 1.5, self.color.text.r, self.color.text.g, self.color.text.b, self.color.text.a)
                        element.extended_h = 35
                    end

                    renderer.text(element.x + (self.padding/2), element.y + element.h/2 - measure_text("", element.value).y/2, self.color.text.r, self.color.text.g, self.color.text.b, self.color.text.a, "", 0, element.value)
                    renderer.text(element.name_x, element.name_y, self.color.text.r, self.color.text.g, self.color.text.b, self.color.text.a, "", 0, element.name) -- name
                end

                if element.type == "multicombo" then
                    element.x = container.x + (self.padding*3)
                    element.y = container.y + self.padding*4.5 + e_gap
                    element.w = container.w - (self.padding*6)
                    element.name_x = container.x + (self.padding*3)
                    element.name_y = container.y + self.padding*3 + e_gap

                    renderer.rectangle(element.x, element.y, element.w, element.h, self.color.border.r + 10, self.color.border.g + 10, self.color.border.b + 10, self.color.border.a)
                    
                    if element.hovering then
                        renderer.rectangle(element.x + 1, element.y + 1, element.w - 2, element.h - 2, self.color.border.r, self.color.border.g, self.color.border.b, self.color.border.a)
                    else
                        renderer.gradient(element.x + 1, element.y + 1, element.w - 2, element.h - 2, self.color.border.r, self.color.border.g, self.color.border.b, self.color.border.a, self.color.foreground.r, self.color.foreground.g, self.color.foreground.b, self.color.foreground.a - 40, false)
                    end

                    if element.open then
                        renderer.triangle(element.x + element.w - 12, element.y + element.h/2 + 1.5, element.x + element.w - 6, element.y + element.h/2 + 1.5, element.x + element.w - 9, element.y + element.h/2 - 1.5, self.color.text.r, self.color.text.g, self.color.text.b, self.color.text.a)

                        renderer.rectangle(element.x, element.y + element.h, element.w, #element.list * element.h, self.color.border.r + 10, self.color.border.g + 10, self.color.border.b + 10, self.color.border.a)
                        renderer.rectangle(element.x + 1, element.y + element.h + 1, element.w - 2, #element.list * element.h - 2, self.color.border.r, self.color.border.g, self.color.border.b, self.color.border.a)

                        for i, v in pairs(element.list) do
                            v.y = element.y + ((i) * element.h)
                            v.x = element.x
                            v.w = element.w
                            local c = contains(element.value, v.value) and self.color.accent or (v.hovering and { r = 255, g = 255, b = 255, a = 255 } or self.color.text)
                            if v.hovering then
                                renderer.rectangle(v.x + 1, v.y + 1, element.w - 2, element.h - 2, self.color.border.r - 12, self.color.border.g - 12, self.color.border.b - 12, self.color.border.a)
                            end
                            renderer.text(v.x + (self.padding/2), v.y + element.h/2 - measure_text("", v.value).y/2, c.r, c.g, c.b, c.a, "", 0, v.value)
                        end
                        element.extended_h = (#element.list * element.h) + element.h + (self.padding*1.5)
                    else
                        renderer.triangle(element.x + element.w - 12, element.y + element.h/2 - 1.5, element.x + element.w - 6, element.y + element.h/2 - 1.5, element.x + element.w - 9, element.y + element.h/2 + 1.5, self.color.text.r, self.color.text.g, self.color.text.b, self.color.text.a)
                        element.extended_h = 35
                    end

                    local value = #element.value == 0 and "none" or table.concat(element.value, ", ")

                    renderer.text(element.x + (self.padding/2), element.y + element.h/2 - measure_text("", value).y/2, self.color.text.r, self.color.text.g, self.color.text.b, self.color.text.a, "", element.w - (self.padding*2), value)
                    renderer.text(element.name_x, element.name_y, self.color.text.r, self.color.text.g, self.color.text.b, self.color.text.a, "", 0, element.name) -- name
                end

                -- render tooltip
                if element.tooltip.visible then
                    element.tooltip.opacity = ease.quad_in(0.3, element.tooltip.opacity, 255 - element.tooltip.opacity, 1)
                    renderer.rectangle(element.name_x - (measure_text("", element.tooltip.text).x/2) + (measure_text("", element.name).x/2) - 2, element.name_y - 15, measure_text("", element.tooltip.text).x + 4, 15, 0, 0, 0, math.min(100, element.tooltip.opacity))
                    renderer.text(element.name_x - (measure_text("", element.tooltip.text).x/2) + (measure_text("", element.name).x/2), element.name_y - 15, self.color.text.r, self.color.text.g, self.color.text.b, element.tooltip.opacity, "", 0, element.tooltip.text)
                else
                    element.tooltip.opacity = ease.quad_in(0.3, element.tooltip.opacity, 0 - element.tooltip.opacity, 1)
                end

                e_gap = e_gap + (element.extended_h + self.padding)
                ::skip::
            end
            ::skip::
        end
    end
end


--aa
local antiaim_checkbox = sui:new_checkbox("Antiaim", "Anti-Aim", "Enable Anti-Aim", false, "enable antiaim")
local antiaim_preset_combo = sui:new_combo("Antiaim", "Anti-Aim", "Preset Select", "Off", "anti aim presets", "Off", "Default", "Tank", "Anti-Aim Builder")

local antiaim_extras_jitter_dormant_checkbox = sui:new_checkbox("Antiaim", "Anti-Aim", "Jitter When Entities Dormant", false, "jitters body yaw when all entities dormant")
local antiaim_extras_jitter_under_hp_checkbox = sui:new_checkbox("Antiaim", "Anti-Aim", "Jitter When Health <", false, "jitters body yaw when health < slider")
local antiaim_extras_health_slider = sui:new_slider("Antiaim", "Anti-Aim", "When Health Is <", 92, 1, 100, "health amount")

--rage
local rage_doubletap_checkbox = sui:new_checkbox("Rage", "Double-Tap", "Enable Double-Tap", false, "enable doubletap")
local rage_doubletap_type_combo = sui:new_combo("Rage", "Double-Tap", "Customize Select", "Off", "customize double-tap", "Off", "Speed Based", "Adaptive")
local rage_doubletap_speed_slider = sui:new_slider("Rage", "Double-Tap", "Double-Tap Speed", 16, 15, 18, "speed modifier")

local rage_modifications_checkbox = sui:new_checkbox("Rage", "Modifications", "Enable Modifications", false, "enable ragebot modification")
local rage_modifications__force_health_checkbox = sui:new_checkbox("Rage", "Modifications", "Enable Force Baim/SP If HP <", false, "forces safepoint and baim when target health is < slider")
local rage_modifications_health_slider = sui:new_slider("Rage", "Modifications", "When Target Health Is <", 92, 1, 100, "health amount")

--vis
local visuals_indicators_combo = sui:new_combo("Visuals", "On-Screen", "Indicator Types", "Off", "indicator types", "Off", "Crosshair")

local visuals_custom_scope_checkbox = sui:new_checkbox("Visuals", "On-Screen", "Enable Custom Scope", false, "enable custom scope")
local visuals_custom_scope_padding = sui:new_slider("Visuals", "On-Screen", "Padding", 10, 0, 300, "padding of line")
local visuals_custom_scope_length = sui:new_slider("Visuals", "On-Screen", "Length", 60, 0, 300, "length of line")


local visuals_notifications_console_checkbox = sui:new_checkbox("Visuals", "Notifications", "Enable Console Hitlogs", false, "enable console hitlogs")
--misc
local antiaim_other_nopitch_checkbox = sui:new_checkbox("Antiaim", "Other", "Enable Zero Pitch On Land", false, "pitch animation set to 0 on land")
local antiaim_other_nopitchtimer_slider = sui:new_slider("Antiaim", "Other", "No Pitch Timer", 1, 0, 3, "no pitch timer")

local antiaim_other_leg_fucker_checkbox = sui:new_checkbox("Antiaim", "Other", "Enable Leg Animation Breaker", false, "breaks leg movement")
local antiaim_other_leg_fuckertimer_slider = sui:new_slider("Antiaim", "Other", "Leg Animation Timer", 3, 0, 10, "leg animation timer")
local antiaim_other_static_legs_checkbox = sui:new_checkbox("Antiaim", "Other", "Enable Static Legs Whilst Airborne", false, "sets legs to static whilst airborne")

local antiaim_movement_slowwalk_checkbox = sui:new_checkbox("Antiaim", "Other", "Enable Custom Slow Walk Speed", false, "enable custom slow walk speed")
local antiaim_movement_slowwalk_slider = sui:new_slider("Antiaim", "Other", "Custom Slow Walk Speed", 30, 10, 80, "custom slow walk speed")

sui:new_checkbox("Misc", "Miscellaneous", "Place Holder", false, "Place holder")

local config_combo = sui:new_combo("Config", "Config", "Configs", "Slot 1", "config select", "Slot 1", "Slot 2", "Slot 3", "Slot 4", "Slot 5")

sui:new_button("Config", "Config", "Load", "Load selected config", function() sui:load_config(config_combo:get()) end)
sui:new_button("Config", "Config", "Save", "Save config", function() sui:save_config(config_combo:get()) end)


client.set_event_callback("setup_command", function(cmd)
    local mouse_down = client.key_state(0x1)
    if ui.is_menu_open() then
        if mouse_down then
            cmd.in_attack = 0
            cmd.in_attack2 = 0
        end
    end
end)


client.set_event_callback("paint_ui", function()
    sui:handler()
    sui:renderer()
    notify:handler()

    --print(unpack(multicombo:get()))
    
end)

client.set_event_callback("shutdown", function()
    database.write(":carbon::menu_pos:", { x = sui.x, y = sui.y })
    --[[    if auto_save:get() then
        sui:save_config(config_combo:get())
    end]]
end)
