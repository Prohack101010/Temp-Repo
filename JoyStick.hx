package mobile;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup; // We will use this in a way to make the thumb and base group up
import flixel.input.touch.FlxTouch;
import flixel.math.FlxAngle;
import flixel.math.FlxMath;
import flixel.math.FlxPoint;
import flixel.math.FlxRect;
import flixel.graphics.FlxGraphic;
import flixel.util.FlxDestroyUtil;
import flixel.graphics.frames.FlxAtlasFrames;
import openfl.utils.Assets;

/**
 * A virtual thumbstick - useful for input on mobile devices.
 * This class extends MobileButton to utilize its core touch and status management.
 *
 * @author KralOyuncu2010x (ArkoseLabs)
 */
class JoyStick extends MobileButton
{
	/**
	 * The minimum input threshold required for horizontal movement recognition.
	 * Values below this threshold will be ignored (dead zone).
	 */
	public var deadZone = {x: 0.3, y: 0.3};

	/**
	 * A list of analogs that are currently active (retained for multi-touch management).
	 */
	static var analogs:Array<JoyStick> = [];

	/**
	 * The current pointer that's active on the analog.
	 * Inherited from TypedMobileButton: `currentInput`
	 */
	// var currentTouch:FlxTouch; 
    
	/**
	 * The area which the joystick will react.
	 * Inherited from MobileButton's bounds.
	 */
	var zone:FlxRect = FlxRect.get();

	/**
	 * The radius in which the stick can move.
	 */
	public var radius:Float = 0;

	/**
	 * The current direction angle of the joystick in radians.
	 * Range: -π to π (-3.14 to 3.14)
	 */
	public var inputAngle:Float = 0;

	/**
	 * The current intensity/amount of the joystick input.
	 * Range: 0 to 1, where 0 is no input and 1 is maximum input.
	 */
	public var intensity:Float = 0;

	/**
	 * The speed of easing when the thumb is released.
	 */
	var easeSpeed:Float;

	/**
	 * The current size of JoyStick sprites.
	 * This now controls the scale of the base (this) and the thumb.
	 */
	public var size(default, set):Float = 1;
	function set_size(Value:Float) {
		size = Value;
		scale.set(Value, Value); // Scale the button (base)
		if (label != null)
			label.scale.set(Value, Value);

		if (radius == 0)
			radius = (width * 0.5) * Value;

		// Update the zone based on the base size
		createZone(); 
		return Value;
	}

	/**
	 * Create a virtual thumbstick - useful for input on mobile devices.
	 *
	 * @param   X			The X-coordinate of the point in space.
	 * @param   Y			The Y-coordinate of the point in space.
	 * @param   Radius		The radius where the thumb can move. If 0, half the base's width will be used.
	 * @param   Ease		Used to smoothly back thumb to center. Must be between 0 and (FlxG.updateFrameRate / 60).
	 * @param   Size		The Scale of the point in space.
	 */
	public function new(X:Float = 0, Y:Float = 0, Radius:Float = 0, Ease:Float = 0.25, Size:Float = 1, ?Return:String)
	{
		// MobileButton handles X, Y, and status management.
		super(X, Y, Return); 

		radius = Radius;
		easeSpeed = FlxMath.bound(Ease, 0, 60 / FlxG.updateFramerate);

		analogs.push(this);

		_point = FlxPoint.get();
		
		// The base is 'this' (the MobileButton sprite)
		loadDefaultGraphic();
		createThumb();
		size = Size;
		
		// Ensure the joystick logic doesn't interfere with the button's size
		// We set the hitbox to match the graphic size.
		updateHitbox(); 

		scrollFactor.set();
		moves = false;
	}

	/**
	 * Overrides the default FlxButton graphic to load the joystick base graphic.
	 */
	override function loadDefaultGraphic():Void
	{
		var xmlFile:String = MobileConfig.mobileFolderPath + 'JoyStick/joystick.xml';
		var pngFile:String = MobileConfig.mobileFolderPath + 'JoyStick/joystick.png';
		#if BSM_FILE_SUPPORT
		var xmlAndPngExists:Bool = false;
		if(FileSystem.exists(xmlFile) && FileSystem.exists(pngFile)) xmlAndPngExists = true;

		if (xmlAndPngExists)
			loadGraphic(FlxGraphic.fromFrame(BitmapData.fromFile(pngFile), File.getContent(xmlFile)).getByName('base'));
		else #end
			loadGraphic(FlxGraphic.fromFrame(FlxAtlasFrames.fromSparrow(Assets.getBitmapData(pngFile), Assets.getText(xmlFile)).getByName('base')));

		resetSizeFromFrame();
		// Center the base graphic on the X, Y coordinates
		x += -width * 0.5;
		y += -height * 0.5;
		
		if (radius == 0)
			radius = width * 0.5;
	}

	/**
	 * Creates the thumb of the analog stick.
	 */
	function createThumb():Void
	{
		label = new FlxSprite(x + width * 0.5, y + height * 0.5); // Start at the center of the base

		var xmlFile:String = MobileConfig.mobileFolderPath + 'JoyStick/joystick.xml';
		var pngFile:String = MobileConfig.mobileFolderPath + 'JoyStick/joystick.png';
		#if BSM_FILE_SUPPORT
		var xmlAndPngExists:Bool = false;
		if(FileSystem.exists(xmlFile) && FileSystem.exists(pngFile)) xmlAndPngExists = true;

		if (xmlAndPngExists)
			label.loadGraphic(FlxGraphic.fromFrame(BitmapData.fromFile(pngFile), File.getContent(xmlFile)).getByName('thumb'));
		else #end
			label.loadGraphic(FlxGraphic.fromFrame(FlxAtlasFrames.fromSparrow(Assets.getBitmapData(pngFile), Assets.getText(xmlFile)).getByName('thumb')));

		label.resetSizeFromFrame();
		label.x += -label.width * 0.5;
		label.y += -label.height * 0.5;
		label.scrollFactor.set();
		label.solid = false;
		#if FLX_DEBUG
		label.ignoreDrawDebug = true;
		#end
	}

	/**
	 * Creates the touch zone. It's based on the size of the background.
	 * The thumb will react when the touch is in the zone.
	 */
	public function createZone():Void
	{
		zone.set(x, y, width * scale.x, height * scale.y);
	}

	/**
	 * Clean up memory.
	 */
	override public function destroy():Void
	{
		super.destroy();

		zone = FlxDestroyUtil.put(zone);

		analogs.remove(this);
		label = FlxDestroyUtil.destroy(label);
	}
	
	/**
	 * Draw the thumb after the base (MobileButton) is drawn.
	 */
	override public function draw():Void
	{
		super.draw();

		if (label != null && label.visible)
		{
			label.cameras = cameras;
			label.draw();
		}
	}

	/**
	 * Called by the game loop automatically, handles touch over and click detection,
	 * AND updates the joystick position.
	 */
	override public function update(elapsed:Float):Void
	{
		super.update(elapsed); // Runs MobileButton's touch/status logic first

		var touchPoint:FlxPoint = null;
		
		// If the button is currently pressed (status == MobileButton.PRESSED) and has an active input
		// we calculate the joystick's movement.
		if (status == MobileButton.PRESSED) 
		{
			var currentTouch = cast(currentInput, FlxTouch);
			if (currentTouch != null)
			{
				// Get the world position of the touch that pressed this button
				touchPoint = currentTouch.getWorldPosition(FlxG.camera, FlxPoint.weak());

				var centerX:Float = x + width * 0.5;
				var centerY:Float = y + height * 0.5;
				
				var dx:Float = touchPoint.x - centerX;
				var dy:Float = touchPoint.y - centerY;

				var dist:Float = Math.sqrt(dx * dx + dy * dy);

				if (dist < 1)
					dist = 0;

				inputAngle = Math.atan2(dy, dx);
				intensity = Math.min(radius * scale.x, dist) / (radius * scale.x);
				
				// Optional: Set acceleration for external consumption (like your original code)
				acceleration.x = Math.cos(inputAngle) * intensity;
				acceleration.y = Math.sin(inputAngle) * intensity;
			}
		}
		
		// If not pressed, ease the intensity back to zero (and center the thumb)
		if (status == MobileButton.NORMAL || status == MobileButton.HIGHLIGHT)
		{
			intensity -= intensity * easeSpeed * FlxG.updateFramerate / 60;

			if (Math.abs(intensity) < 0.1)
			{
				intensity = 0;
				inputAngle = 0;
			}
			acceleration.set();
		}

		// Update the thumb position
		var centerX:Float = x + width * 0.5;
		var centerY:Float = y + height * 0.5;
		
		label.x = centerX + Math.cos(inputAngle) * intensity * (radius * scale.x) - (label.width * 0.5);
		label.y = centerY + Math.sin(inputAngle) * intensity * (radius * scale.x) - (label.height * 0.5);
		
		label.update(elapsed); // Keep the thumb up-to-date
	}
	
	// --- Directional Accessors (Moved from old JoyStick) ---
	
	/**
	 * Whether the joystick is pointing up.
	 */
	public var up(get, never):Bool;
	
	function get_up():Bool
	{
		if (!pressed) return false;
		return intensity > deadZone.y && (Math.sin(inputAngle) < -deadZone.y);
	}
	
	/**
	 * Whether the joystick is pointing down.
	 */
	public var down(get, never):Bool;
	
	function get_down():Bool
	{
		if (!pressed) return false;
		return intensity > deadZone.y && Math.sin(inputAngle) > deadZone.y;
	}
	
	/**
	 * Whether the joystick is pointing left.
	 */
	public var left(get, never):Bool;
	
	function get_left():Bool
	{
		if (!pressed) return false;
		return intensity > deadZone.x && Math.cos(inputAngle) < -deadZone.x;
	}
	
	/**
	 * Whether the joystick is pointing right.
	 */
	public var right(get, never):Bool;
	
	function get_right():Bool
	{
		if (!pressed) return false;
		return intensity > deadZone.x && Math.cos(inputAngle) > deadZone.x;
	}

	// joyStickJustPressed, joyStickPressed, joyStickJustReleased remain the same logic
	
	/**
	 * Check if a specific direction was just pressed.
	 * @param Direction The direction to check ('up', 'down', 'left', 'right')
	 * @param Threshold Minimum amount required (0-1). Default is 0.5.
	 * @return Bool
	 */
	public function joyStickJustPressed(Direction:String, Threshold:Float = 0.5):Bool
	{
		if (!justPressed) return false;
		
		switch (Direction.toLowerCase())
		{
			case 'up':
				return up;
			case 'down':
				return down;
			case 'left':
				return left;
			case 'right':
				return right;
			default:
				return false;
		}
	}
	
	/**
	 * Check if a specific direction is currently held.
	 * @param Direction The direction to check ('up', 'down', 'left', 'right')
	 * @param Threshold Minimum amount required (0-1). Default is 0.5.
	 * @return Bool
	 */
	public function joyStickPressed(Direction:String, Threshold:Float = 0.5):Bool
	{
		if (!pressed) return false;

		switch (Direction.toLowerCase())
		{
			case 'up':
				return up;
			case 'down':
				return down;
			case 'left':
				return left;
			case 'right':
				return right;
			default:
				return false;
		}
	}
	
	/**
	 * Check if a specific direction was just released.
	 * @param Direction The direction to check ('up', 'down', 'left', 'right')
	 * @param Threshold Minimum amount required (0-1). Default is 0.5.
	 * @return Bool
	 */
	public function joyStickJustReleased(Direction:String, Threshold:Float = 0.5):Bool
	{
		if (!justReleased) return false;

		switch (Direction.toLowerCase())
		{
			case 'up':
				return up;
			case 'down':
				return down;
			case 'left':
				return left;
			case 'right':
				return right;
			default:
				return false;
		}
	}
}
