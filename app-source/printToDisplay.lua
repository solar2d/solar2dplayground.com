--==============================================================================
-- Important! Important! Important! Important! Important! Important! Important!
--==============================================================================
-- If you want to make changes to this module and you need to use debug prints,
-- then make sure to use "_print()" inside the functions because using "print()"
-- inside the wrong function will result in an infinite loop.
--==============================================================================

-- NB! This is version of printToDisplay is slightly modified for the Playground.
local M = {}

-- Localised functions.
local _print = print
local _type = type
local _unpack = unpack
local _tostring = tostring
local _concat = table.concat

M.autoscroll = true
local canScroll = false
local started = false
local output

-- Visual customisation variables.
local parent
local font = native.systemFont
local buttonSize = 32
local buttonBaseColor = { 0.2 }
local buttonImageColor = { 0.8 }
local textColor = { 0.9 }
local textColorError = { 0.9, 0, 0 }
local textColorWarning = { 0.9, 0.75, 0 }
local bgColor = { 0 }
local fontSize = 20
local alpha = 1
local width = 200
local height = 100
local anchorX = 0
local anchorY = 0
local x = display.screenOriginX
local y = display.screenOriginY
local paddingRow = 4
local paddingLeft = 10
local paddingRight = 10
local paddingTop = 10
local paddingBottom = 10
local scrollThreshold = (height-(paddingTop+paddingBottom))*0.5
local useHighlighting = true

-- Scroll the text in the console.
local maxY, objectStart, eventStart = 0
local function scroll( event )
    if event.phase == "began" then
        display.getCurrentStage():setFocus( event.target )
        event.target.isTouched = true
        objectStart, eventStart = output.y, event.y
    elseif event.phase == "moved" then
        if event.target.isTouched then
            local d = event.y - eventStart
            local toY = objectStart + d
            if toY <= 0 and toY >= -maxY then
                M.autoscroll = false
                output.y = toY
            else
                objectStart = output.y
                eventStart = event.y
                if toY <= 0 then
                    M.autoscroll = true
                end
            end
        end
    else
        display.getCurrentStage():setFocus( nil )
        event.target.isTouched = false
    end
    return true
end

-- Handles the console's two buttons.
local function controls( event )
    if event.phase == "began" then
        if event.target.id == "autoscroll" then
            M.autoscroll = not M.autoscroll
            if M.autoscroll then output.y = -maxY end
        else -- Clear all text.
            M.ui.bg:removeEventListener( "touch", scroll )
            canScroll = false
            M.autoscroll = true
            output.y = 0
            for i = 1, #output.row do
                display.remove( output.row[i] )
                output.row[i] = nil
            end
        end
    end
    return true
end

-- Add a new chunk of text to the output window.
local function printToDisplay( ... )
    local t = {...}
    for i = 1, #t do
        t[i] = _tostring( t[i] )
    end
    local text = _concat( t, "    " )

    local _y
    if #output.row > 0 then
        _y = output.row[#output.row].y + output.row[#output.row].height + paddingRow
    else
        _y = y+paddingTop - height*0.5
    end

    output.row[#output.row+1] = display.newText( {
        parent = output,
        text = text,
        x = output.row[#output.row] and output.row[#output.row].x or paddingLeft-width*0.5,
        y = output.row[#output.row] and output.row[#output.row].y+output.row[#output.row].height+paddingRow or paddingTop-height*0.5,
        width = width - (paddingLeft + paddingRight),
        height = 0,
        font = font,
        fontSize = fontSize
    } )
    M._keep[_tostring(output.row[#output.row])] = true
    output.row[#output.row].anchorX, output.row[#output.row].anchorY = 0, 0

    if useHighlighting then
        if output.row[#output.row].text:sub(1,6) == "ERROR:" then
            output.row[#output.row]:setFillColor( _unpack( textColorError ) )
        elseif output.row[#output.row].text:sub(1,8) == "WARNING:" then
            output.row[#output.row]:setFillColor( _unpack( textColorWarning ) )
        else
            output.row[#output.row]:setFillColor( _unpack( textColor ) )
        end
    else
        output.row[#output.row]:setFillColor( _unpack( textColor ) )
    end

    if not canScroll and output.row[#output.row].y + output.row[#output.row].height >= scrollThreshold then
        M.ui.bg:addEventListener( "touch", scroll )
        canScroll = true
    end

    if canScroll then
        maxY = output.row[#output.row].y + output.row[#output.row].height - scrollThreshold
        if M.autoscroll then
            output.y = -maxY
        end
    end
end

-- Optional function that will customise any or all visual features of the module.
function M.setStyle( s )
    if type( s ) ~= "table" then
        print( "WARNING: bad argument to 'setStyle' (table expected, got " .. type( s ) .. ")." )
    else -- Validate all and update only valid, passed parameters.
        if type( s.buttonSize ) == "number" then buttonSize = s.buttonSize end
        if type( s.parent ) == "table" and s.parent.insert then parent = s.parent end
        if type( s.useHighlighting ) == "boolean" then useHighlighting = s.useHighlighting end
        if type( s.buttonBaseColor ) == "table" then buttonBaseColor = s.buttonBaseColor end
        if type( s.buttonImageColor ) == "table" then buttonImageColor = s.buttonImageColor end
        if type( s.font ) == "string" or type( s.font ) == "userdata" then font = s.font end
        if type( s.fontSize ) == "number" then fontSize = s.fontSize end
        if type( s.width ) == "number" then width = s.width end
        if type( s.height ) == "number" then height = s.height end
        if type( s.anchorX ) == "number" then anchorX = s.anchorX end
        if type( s.anchorY ) == "number" then anchorY = s.anchorY end
        if type( s.x ) == "number" then x = s.x end
        if type( s.y ) == "number" then y = s.y end
        if type( s.paddingRow ) == "number" then paddingRow = s.paddingRow end
        if type( s.paddingLeft ) == "number" then paddingLeft = s.paddingLeft end
        if type( s.paddingRight ) == "number" then paddingRight = s.paddingRight end
        if type( s.paddingTop ) == "number" then paddingTop = s.paddingTop end
        if type( s.textColor ) == "table" then textColor = s.textColor end
        if type( s.bgColor ) == "table" then bgColor = s.bgColor end
        if type( s.alpha ) == "number" then alpha = s.alpha end
        scrollThreshold = (height-(paddingTop+paddingBottom))*0.5
        -- If printToDisplay is already running, then clear it.
        if started then
            M.stop()
            M.start()
        end
    end
end

-- Create the UI and make the default print() calls also "print" on screen.
function M.start()
    if not started then
        started = true
        -- Create container where the background and text are added.
        M.ui = display.newContainer( width, height )
        M._keep[_tostring(M.ui)] = true
        if parent then parent:insert( M.ui ) end
        M.ui.anchorX, M.ui.anchorY = anchorX, anchorY
        M.ui.x, M.ui.y = x, y
        M.ui.alpha = alpha
        -- Create the background.
        M.ui.bg = display.newRect( M.ui, 0, 0, width, height )
        M._keep[_tostring(M.ui.bg)] = true
        M.ui.bg:setFillColor( _unpack( bgColor ) )
        -- All rows of text are added to output group.
        output = display.newGroup()
        M._keep[_tostring(output)] = true
        M.ui:insert( output, true )
        output.row = {}
        -- Create external control buttons
        M.controls = display.newGroup()
        M._keep[_tostring(M.controls)] = true
        if parent then parent:insert( M.controls ) end

        local SEG = buttonSize*0.2 -- Segment.
        local HW = buttonSize*0.4 -- (Approximate) half width.
        local buttonOffsetX = (1-anchorX)*width
        local buttonOffsetY = anchorY*height

        M.controls.scroll = display.newRect( M.controls, x+buttonOffsetX+buttonSize*0.5, y-buttonOffsetY+buttonSize*0.5, buttonSize, buttonSize )
        M.controls.scroll:setFillColor( _unpack( buttonBaseColor ) )
        M.controls.scroll:addEventListener( "touch", controls )
        M.controls.scroll.id = "autoscroll"
        M._keep[_tostring(M.controls.scroll)] = true

        local play = {
            -HW+SEG,-HW+SEG*0.5,
            HW,0,
            -HW+SEG,HW-SEG*0.5
        }

        M.controls.scrollSymbol = display.newPolygon( M.controls, M.controls.scroll.x, M.controls.scroll.y, play )
        M.controls.scrollSymbol:setFillColor( _unpack( buttonImageColor ) )
        M._keep[_tostring(M.controls.scrollSymbol)] = true
        
        M.controls.clear = display.newRect( M.controls, x+buttonOffsetX+buttonSize*0.5, y-buttonOffsetY+buttonSize*1.5 + 10, buttonSize, buttonSize )
        M.controls.clear:setFillColor( _unpack( buttonBaseColor ) )
        M.controls.clear:addEventListener( "touch", controls )
        M.controls.clear.id = "clear"
        M._keep[_tostring(M.controls.clear)] = true

        local cross = {
            -HW,-HW+SEG,
            -HW+SEG,-HW,
            0,-SEG,
            HW-SEG,-HW,
            HW,-HW+SEG,
            SEG,0,
            HW,HW-SEG,
            HW-SEG,HW,
            0,SEG,
            -HW+SEG,HW,
            -HW,HW-SEG,
            -SEG,0
        }

        M.controls.clearSymbol = display.newPolygon( M.controls, M.controls.clear.x, M.controls.clear.y, cross )
        M.controls.clearSymbol:setFillColor( _unpack( buttonImageColor ) )
        M._keep[_tostring(M.controls.clearSymbol)] = true

        -- Finally, "hijack" the global print function and add the printToDisplay functionality.
        function print( ... )
            printToDisplay( ... )
            _print( ... )
        end
    end
end

-- Restore the normal functionality to print() and clean up the UI.
function M.stop()
    if started then
        started = false
        canScroll = false
        -- Remove the display objects and groups 
        -- from the list of persisting assets.
        for i = 1, #output.row do
            M._keep[_tostring(output.row[i])] = nil
        end
        M._keep[_tostring(output)] = nil
        M._keep[_tostring(M.ui)] = nil
        M._keep[_tostring(M.ui.bg)] = nil
        M._keep[_tostring(M.controls)] = nil
        M._keep[_tostring(M.controls.scroll)] = nil
        M._keep[_tostring(M.controls.scrollSymbol)] = nil
        M._keep[_tostring(M.controls.clear)] = nil
        M._keep[_tostring(M.controls.clearSymbol)] = nil
        
        display.remove( output )
        output = nil
        display.remove( M.controls )
        M.controls = nil
        display.remove( M.ui )
        M.ui = nil
        print = _print -- Restore the normal global print function.
    end
end

return M