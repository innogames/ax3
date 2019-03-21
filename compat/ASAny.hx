abstract ASAny(Dynamic) from Dynamic {
	@:to function ___toString():String {
		return this; // TODO
	}

	@:to function ___toBool():Bool {
		return this; // TODO
	}

	@:to function ___toInt():Int {
		return this; // TODO
	}

	@:to function ___toOther():Dynamic {
		return this;
	}

	@:op(a.b) inline function ___get(name:String):ASAny {
		return Reflect.getProperty(this, name);
	}

	@:op(a.b) inline function ___set(name:String, value:ASAny):ASAny {
		Reflect.setProperty(this, name, value);
		return value;
	}

	@:op(!a) inline function __not():Bool {
		return !___toBool();
	}

	@:op(a || b) static inline function __or(a:ASAny, b:ASAny):ASAny {
		return if (a) a else b;
	}

	@:op([]) inline function ___arrayGet(name) return ___get(name);
	@:op([]) inline function ___arraySet(name, value) return ___set(name, value);
}
