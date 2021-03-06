package flixel.util;

import flixel.interfaces.IFlxDestroyable;
import flixel.interfaces.IFlxPooled;
import flixel.util.FlxPool;

/**
 * An object that contains a list of callbacks to be executed when dispatch is triggered.
 * 
 * @author Sam Batista (https://github.com/gamedevsam)
 */
class FlxSignal implements IFlxPooled
{
	private static var _pool = new FlxPool<FlxSignal>(FlxSignal);
	private static var _handlersPool = new FlxPool<SignalHandler>(SignalHandler);
	private static var _signals:Array<FlxSignal> = [];
	
	/**
	 * A signal that gets dispatched when a state change occurs. Signal.userData is null!
	 */
	public static var stateSwitch(default, null) = get(true).add(onStateSwitch);
	/**
	 * A signal that gets dispatched when a state change occurs. Signal.userData is a FlxPoint (_scaleMode.gameSize)!
	 */
	public static var gameResize(default, null) = get(true);
	
	/**
	 * Creates a new signal or recycles a used one if available.
	 * 
	 * @param	Persist If signal should remain active between state switches.
	 */
	public static inline function get(Persist:Bool = false):FlxSignal
	{
		var signal = _pool.get();
		signal.persist = Persist;
		signal._inPool = false;
		_signals.push(signal);
		return signal;
	}
	
	public static function onStateSwitch(_):Void
	{
		var i = _signals.length;
		while (i-- > 0)
		{
			if (!_signals[i].persist)
				_signals[i].put();
		}
	}
	
	/**
	 * If Signal is active and should broadcast events.
	 * IMPORTANT: Setting this property during a dispatch will only affect the next dispatch, if you want to stop the propagation of a signal use `halt()` instead.</p>
	 */
	public var active:Bool = true;
	/**
	 * If signal should remain active between state switches.
	 */
	public var persist:Bool = false;
	/**
	 * Object that contains data passed into the dispatch function (can be null).
	 */
	public var userData:Dynamic = null;
	
	private var _inPool:Bool = false;
	private var _handlers:Array<SignalHandler>;
	
	/**
	 * Restores this signal to the pool (destroys it in the process).
	 */
	public function put():Void
	{
		if (!_inPool)
		{
			_pool.putUnsafe(this);
			_inPool = true;
		}
	}
	
	/**
	 * Adds a function callback to be triggered when dispatch is called.
	 * 
	 * @return	This FlxSignal instance (nice for chaining stuff together, if you're into that).
	 */
	public function add(Callback:FlxSignal->Void, DispatchOnce:Bool = false):FlxSignal
	{
		var handler:SignalHandler = _handlersPool.get().init(Callback, DispatchOnce);
		if (_handlers == null)
			_handlers = new Array<SignalHandler>();
		_handlers.push(handler);
		return this;
	}
	
	/**
	 * Determines whether the provided callback is registered with this signal.
	 * 
	 * @param	Callback	function callback to check
	 * @return	Bool	true if callback was found, otherwise false 
	 */
	public function has(Callback:FlxSignal->Void):Bool
	{
		if (_handlers != null)
		{
			for (i in 0..._handlers.length)
			{
				if (_handlers[i]._callback == Callback)
					return true;
			}
		}
		return false;
	}
	
	/**
	 * Removes a function callback.
	 */
	public function remove(Callback:FlxSignal->Void)
	{
		if (_handlers != null)
		{
			for (i in 0..._handlers.length)
			{
				if (_handlers[i]._callback == Callback)
				{
					FlxArrayUtil.swapAndPop(_handlers, i);
					return;
				}
			}
		}
	}
	
	/**
	 * Remove all callbacks from the Signal.
	 */
	public function removeAll()
	{
		FlxArrayUtil.clearArray(_handlers);
	}
	
	/**
	 * Dispatches this Signal to all bound callbacks.
	 * 
	 * @param	Data	Data temporaily stored in userData which can be accessed in callback functions.
	 */
	public function dispatch(?Data:Dynamic)
	{
		if (active && _handlers != null)
		{
			if (Data != null)
				userData = Data;
			
			var i = _handlers.length;
			
			// must count down when using swapAndPop
			while (i-- > 0)
			{
				var handler = _handlers[i];
				
				handler._callback(this);
				
				if (handler._isOnce)
					FlxArrayUtil.swapAndPop(_handlers, i);
			}
		}
	}
	
	public function destroy()
	{
		removeAll();
		_handlers = null;
		userData = null;
		FlxArrayUtil.fastSplice(_signals, this);
	}
}

private class SignalHandler implements IFlxDestroyable
{
	public var _isOnce:Bool;
	public var _callback:FlxSignal->Void;
	
	public function init(callback:FlxSignal->Void, isOnce:Bool)
	{
		_callback = callback;
		_isOnce = isOnce;
		return this;
	}
	
	public function destroy()
	{
		_callback = null;
	}
}
