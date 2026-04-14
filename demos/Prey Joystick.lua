-- Sample code by Jonathan Sharp.

-- Require and start the physics engine.
local physics = require("physics")
physics.start()
physics.setGravity( 0, 0 ) -- Zero gravity.

local cx, cy = display.contentCenterX, display.contentCenterY -- Screen center coordinates.
local predatorSize, preySize, joystickSize, dangerZone, time = 45, 24, 87, 150, 200 -- Object and time variables.
local angleBetween, distanceBetween, moveTo, getRandomTarget -- Forward references to movement functions.
local joystick, prey -- Forward references to objects.

local background = display.newRect(
	display.safeScreenOriginX,
	display.safeScreenOriginY,
	display.safeActualContentWidth,
	display.safeActualContentHeight
)
background.x = cx ; background.y = cy
background:setFillColor( 0, 0.68, 0.99, 0.5 )

-- Help text.
local text = display.newText( {text = "← Use the joystick to survive!", x = display.contentCenterX, y = display.contentCenterY/4, fontSize = 32 } )
local textTrans = transition.to( text, { delay=5000, time=1200, alpha = 0, onComplete=
	function()
		display.remove( text ) ; text = nil
	end} )

local preySpeed = 250
local predatorCount = 10
local predatorStartDistance = 350

-----------------------------------------------------------------------
--- prey ---
-----------------------------------------------------------------------
prey = display.newCircle( cx, cy, preySize*0.5 )
prey.x = cx ; prey.y = cy
prey:setFillColor( 0.2, 0.8, 0.4, 0.8 )
physics.addBody( prey, "dynamic", {radius = preySize*0.5})
prey.linearDamping = 3
prey.type = "prey"

function prey:die(  )
	local deathCircle = display.newCircle( prey.x, prey.y, preySize*0.5 )
	deathCircle.x = self.x ; deathCircle.y = self.y
	deathCircle:setFillColor(1,1,0.2)
	deathCircle.blendMode = "add"
	Runtime:removeEventListener( "enterFrame", prey.move )
	prey.alpha = 0
	timer.performWithDelay( 50, function() prey.isBodyActive = false end )

	local trans1 = transition.to( deathCircle, { time=200, alpha = 0, xScale=3, yScale=3, onComplete=
		function()
			display.remove( deathCircle ) ; deathCircle = nil
			prey.x = math.random( display.safeActualContentWidth )
			prey.y = math.random( display.safeActualContentHeight )
			prey.isBodyActive = true
			prey.alpha = 1
			Runtime:addEventListener( "enterFrame", prey.move )
		end} )
end

function prey.move( )
	if prey.x < 0 or prey.x > display.safeActualContentWidth or prey.y < 0 or prey.y > display.safeActualContentHeight then
		prey:die() -- Kill prey if it leaves the screen.
	elseif joystick.isActive == true then
		local speed = preySpeed
		local xVelocity = math.cos(joystick.angle) * speed
		local yVelocity = math.sin(joystick.angle) * speed
		prey:setLinearVelocity( xVelocity, yVelocity )
	end
end
Runtime:addEventListener( "enterFrame", prey.move )

-----------------------------------------------------------------------
--- joystick ---
-----------------------------------------------------------------------
joystick = display.newCircle( cx, cy, joystickSize*0.5 )
joystick.alpha = 0.1
joystick.x = display.safeScreenOriginX + joystickSize
joystick.y = display.safeScreenOriginY + display.safeActualContentHeight - joystickSize
joystick.isActive = false
joystick.isAvailable = true
-- Update the help text location.
text.x = joystick.x + text.width*0.5 ; text.y = joystick.y

joystick.bulb = display.newCircle( cx, cy, joystickSize*0.5 * 0.5 )
joystick.bulb.alpha = 0.3
joystick.bulb.x = joystick.x ; joystick.bulb.y = joystick.y
joystick.bulb.isFocus = false

local function control( event ) -- Generate food where background is touched.
	joystick.angle = angleBetween(joystick, event)
	local t = event.target -- joystick.bulb

	if event.phase == "began" and joystick.isActive == false then -- If joystick is not active, make it active and make it the focus.
		joystick.isActive = true
		display.getCurrentStage():setFocus( t )
		t.isFocus = true

	elseif t.isFocus == true then -- Once the joystick (joystick.bulb) has screen focus - move the bulb - which registers a new angle.
		if event.phase == "moved" and distanceBetween(joystick, joystick.bulb) < joystickSize * 2 then
			joystick.isActive = true
			joystick.bulb.x = event.x ; joystick.bulb.y = event.y
		else -- Event ended or joystick bulb is to far away from the joystick circle.
			joystick.isActive = false
			joystick.isAvailable = false
			transition.to( joystick.bulb, { time=300, x = joystick.x, y = joystick.y, transition = easing.outBounce, onComplete=
				function()
					joystick.isAvailable = true
				end} )
			display.getCurrentStage():setFocus( nil )
			t.isFocus = false
			joystick.isActive = false
		end
	end
	return true -- Stops the touch from propogating to underlying objects.
end
joystick.bulb:addEventListener( "touch", control )

-----------------------------------------------------------------------
--- predator ---
-----------------------------------------------------------------------
local function makePredator( x,y )
	local predator = display.newCircle( cx, cy, predatorSize*0.5 )
	predator.x = x ; predator.y = y
	predator:setFillColor( 0.8, 0.4, 0.4)
	physics.addBody( predator, "dynamic", {radius = predatorSize * 0.5})
	predator.linearDamping = 1

	function predator.collision( event )
		if event.phase == 'began' then
			if event.other.type == "prey" then event.other:die() end
		end
	end

	function predator.move( ) -- Aggressive when near prey.
		if distanceBetween(predator, prey) < dangerZone then
			moveTo(predator, prey,5)
		else
			moveTo(predator, getRandomTarget())
		end
	end

	local randomTime = math.random( 300 ) -- For variation.
	predator.timer = timer.performWithDelay( time + randomTime, predator.move, -1 )
	predator:addEventListener( "collision", predator.collision )
end

for i=1,predatorCount do -- Generate predators.
	local angle = math.random( math.pi * 2 *100)/100 -- Random placement around unit circle (in radians).
	makePredator(cx + math.cos(angle) * predatorStartDistance, cy + math.sin(angle) * predatorStartDistance)
end

-----------------------------------------------------------------------
--- functions for movement ---
-----------------------------------------------------------------------
function angleBetween( object, target )
	local angle = math.atan2( target.y - object.y, target.x - object.x)
	return angle -- Returns angle in radians.
end

function distanceBetween( object, target)
	local xfactor = object.x - target.x
	local yfactor = object.y - target.y
	local distance = math.sqrt( xfactor * xfactor + yfactor * yfactor )
	return distance
end

-- Physics movement - object moves toward target with an optional force factor (force can be negative).
function moveTo( object, target, force)
	force = force or 1  -- Use -1 to move away from target.
	local angle = angleBetween(object, target)
	local xForce = math.cos(angle) * force * object.mass
	local yforce = math.sin(angle) * force * object.mass

	object:applyLinearImpulse( xForce, yforce, object.x, object.y )
end

-- Generate a random target to move toward using moveTo().
function getRandomTarget(  )
	local randomTarget = {
		x = math.random(display.safeActualContentWidth),
		y = math.random(display.safeActualContentHeight)
	}
	return randomTarget
end
