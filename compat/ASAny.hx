@:callable // TODO it's a bit unsafe because @:callable takes and returns Dynamic, not ASAny
           // I'm not sure how much can we do about it, maybe wrap the TTAny arguments and the return value in ASAny on the converter level?
abstract ASAny(Dynamic) from Dynamic from haxe.Constraints.Function {
	public inline function hasOwnProperty(name:String):Bool {
		return Reflect.hasField(this, name);
	}

	@:to function ___toString():String {
		return this; // TODO
	}

	@:to function ___toBool():Bool {
		return this; // TODO
	}

	@:to function ___toInt():Int {
		return this; // TODO
	}

	@:to function ___toFloat():Float {
		return this; // TODO
	}

	@:to function ___toOther():Dynamic {
		return this;
	}

	@:op(a.b) inline function ___get(name:String):ASAny {
		var value:Dynamic = Reflect.getProperty(this, name);
		if (Reflect.isFunction(value))
			return Reflect.makeVarArgs(args -> Reflect.callMethod(this, value, args));
		else
			return value;
	}

	@:op(a.b) inline function ___set(name:String, value:ASAny):ASAny {
		Reflect.setProperty(this, name, value);
		return value;
	}

	@:op(!a) inline function __not():Bool {
		return !___toBool();
	}

	// TODO we probably don't want to apply `ASAny` conversions for something that is already Bool
	@:op(a || b) static inline function __or(a:ASAny, b:ASAny):ASAny {
		return if (a) a else b;
	}

	// TODO: same comment as above
	@:op(a && b) static inline function __and(a:ASAny, b:ASAny):ASAny {
		return if (a) b else a;
	}

	@:op(a - b) static function ___minus(a:ASAny, b:Float):Float {
		return a.___toFloat() - b;
	}

	@:op(a > b) static function ___gt(a:ASAny, b:Float):Bool return a.___toFloat() > b;
	@:op(a < b) static function ___lt(a:ASAny, b:Float):Bool return a.___toFloat() < b;
	@:op(a >= b) static function ___gte(a:ASAny, b:Float):Bool return a.___toFloat() >= b;
	@:op(a <= b) static function ___lte(a:ASAny, b:Float):Bool return a.___toFloat() <= b;

	@:op([]) inline function ___arrayGet(name:ASAny):ASAny return ___get(name);
	@:op([]) inline function ___arraySet(name:ASAny, value:ASAny):ASAny return ___set(name, value);
}
