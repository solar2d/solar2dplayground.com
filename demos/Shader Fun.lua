-- Original shader by Michael Wilson.
-- [Code adapted for Playground by Eetu Rantanen]

-- Create a custom shader.
local kernel = {}
kernel.language = "glsl"
kernel.category = "filter"
kernel.name = "multiswap"

-- Expose effect parameters using vertex data.
kernel.uniformData = {
	{
		name = "keys",
		default = {
			1.0, 1.0, 1.0, 1.0,
			1.0, 1.0, 1.0, 1.0,
			1.0, 1.0, 1.0, 1.0,
			1.0, 1.0, 1.0, 1.0
		},
		min = {
			0.0, 0.0, 0.0, 0.0,
			0.0, 0.0, 0.0, 0.0,
			0.0, 0.0, 0.0, 0.0,
			0.0, 0.0, 0.0, 0.0
		},
		max = {
			1.0, 1.0, 1.0, 1.0,
			1.0, 1.0, 1.0, 1.0,
			1.0, 1.0, 1.0, 1.0,
			1.0, 1.0, 1.0, 1.0
		},
		type="mat4",
		index = 0, -- u_UserData0
	},
	{
		name = "colors",
		default = {
			1.0, 1.0, 1.0, 1.0,
			1.0, 1.0, 1.0, 1.0,
			1.0, 1.0, 1.0, 1.0,
			1.0, 1.0, 1.0, 1.0
		},
		min = {
			0.0, 0.0, 0.0, 0.0,
			0.0, 0.0, 0.0, 0.0,
			0.0, 0.0, 0.0, 0.0,
			0.0, 0.0, 0.0, 0.0
		},
		max = {
			1.0, 1.0, 1.0, 1.0,
			1.0, 1.0, 1.0, 1.0,
			1.0, 1.0, 1.0, 1.0,
			1.0, 1.0, 1.0, 1.0
		},
		type="mat4",
		index = 1, -- u_UserData1
	},
}

kernel.fragment = [[
uniform P_COLOR mat4 u_UserData0; // keys
uniform P_COLOR mat4 u_UserData1; // colors
P_COLOR vec4 FragmentKernel( P_UV vec2 texCoord )
{
	P_COLOR vec4 texColor = texture2D( CoronaSampler0, texCoord );
	for(int i = 0; i < 4; i++)
	{
		P_COLOR vec4 keys = u_UserData0[i];
		P_COLOR vec4 colors = u_UserData1[i];
		if ((abs(texColor[0] - keys[0]) < 0.2) && (abs(texColor[1] - keys[1]) < 0.2) && (abs(texColor[2] - keys[2]) < 0.2))
		{
			texColor = colors;
			break;
		}
	}
	return CoronaColorScale(texColor);
}
]]
graphics.defineEffect( kernel )

-- Create a character to apply the shader to.
local character = display.newImage( "img/skeleton.png", 480, 320 )
character:scale(3,3)

local random = math.random
local timerShader

local function toggleShader( event )
	if event.phase == "began" then
		if timerShader then
			-- Remove the effect and stop the timer.
			character.fill.effect = nil
			timer.cancel( timerShader )
			timerShader = nil
		else
			-- Apply the shader and define the colours to swap.
			character.fill.effect = "filter.custom.multiswap"
			character.fill.effect.keys = {
				255/255,  255/255,  255/255, 1,
				53/255,  151/255, 211/255, 1,
				150/255, 91/255, 165/255, 1,
				240/255, 196/255, 23/255, 1
			}
			-- Keep swapping to random colours indefinitely.
			timerShader = timer.performWithDelay( 100, function()
				character.fill.effect.colors = {
					random(), random(),  random(), 1,
					random(), random(),  random(), 1,
					random(), random(),  random(), 1,
					random(), random(),  random(), 1,
				}
			end, 0 )
		end
	end
end

-- Add touch controls for the shader effect and start it.
Runtime:addEventListener( "touch", toggleShader )
toggleShader( {phase="began"} )