-- Change the background to grey
display.setDefault( "background", 0.1 )

local x, y = display.contentCenterX, display.contentCenterY -- source of the letters
local rnd = math.random

-- Help text
display.newText( {text = "Start typing...", x = x, y = y/4, fontSize = 32 } )

-- Require and start the physics engine
local physics = require("physics")
physics.start()
physics.setGravity( 0, 64 ) -- set gravity

local ground = display.newRect(x,display.contentHeight, display.contentWidth * 2, 16)
ground.alpha = 0.25
physics.addBody(ground, "static")

-- Text options
local options = { x = x, y = y, fontSize = 128, font = native.systemFontBold }

-- Called when a key event has been received.
local function key( event )
  if event.phase == "up" then
    -- create the key you pressed
    options.text = event.keyName:len() == 1 and event.keyName or "?" -- one letter keys only
    local letter = display.newText( options )
    -- render the text to a display object
    local object = display.capture(letter)
    -- add a premade shader
    object.fill.effect = "filter.colorChannelOffset"
    object.fill.effect.xTexels = 4
    object.fill.effect.yTexels = 4
    object:translate(x,y) -- move from 0,0
    -- remove the letter
    display.remove(letter)
    -- let's give it a quick physics body
    physics.addBody(object, { radius = 32, bounce = 0.5, friction = 0 } )
    object.linearDamping = 1
    object.angularDamping= 1
    -- gie it a push
    object:applyLinearImpulse(rnd()-rnd(),-rnd()-rnd(),rnd(),rnd())
    object.angularVelocity = object.angularVelocity * 0.025 -- cap spin speed
  end
end

-- Add the key event
Runtime:addEventListener( "key", key )