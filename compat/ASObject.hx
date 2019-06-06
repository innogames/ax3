@:callable // TODO it's a bit unsafe because @:callable takes and returns Dynamic, not ASAny
           // I'm not sure how much can we do about it, maybe wrap the TTAny arguments and the return value in ASAny on the converter level?
abstract ASObject(flash.utils.Object)
	from flash.utils.Object
	to flash.utils.Object
	#if !js // TODO: not sure why this is needed, but it is
	from haxe.Constraints.Function
	from ASAny
	to ASAny
	#else
	from Array<Dynamic> // from arrays of mixed types
	#end
{

	public inline function new() this = cast {};

	@:noCompletion
	public inline function ___keys() {
		#if flash
		return new NativePropertyIterator<String>(this);
		#else
		return (cast this : haxe.DynamicAccess<ASAny>).keys();
		#end
	}

	@:to public inline function iterator() {
		#if flash
		return new NativeValueIterator<ASAny>(this);
		#else
		return (cast this : haxe.DynamicAccess<ASAny>).iterator();
		#end
	}

	public function hasOwnProperty(name:String):Bool {
		if (Reflect.hasField(this, name)) {
			return true;
		}
		var clazz = Type.getClass(this);
		if (clazz != null) {
			var fields = Type.getInstanceFields(clazz);
			return fields.indexOf(name) > -1 || fields.indexOf("get_" + name) > -1 || fields.indexOf("set_" + name) > -1;
		}
		return false;
	}

	#if flash
	@:to public inline function ___toString():String return cast this;
	@:to inline function ___toBool():Bool return cast this;
	@:to inline function ___toFloat():Float return cast this;
	@:to inline function ___toInt():Int return cast this;
	#elseif js
	@:to public inline function ___toString():String return if (this == null) null else "" + this;
	@:to inline function ___toBool():Bool return js.Syntax.code("Boolean")(this);
	@:to inline function ___toFloat():Float return js.Syntax.code("Number")(this);
	@:to inline function ___toInt():Int return Std.int(___toFloat());
	#else
	@:to function ___toBool():Bool {
		if (this == null) {
			return false;
		}
		if (Std.is(this, Float)) {
			var v:Float = cast this;
			return v != 0 && !Math.isNaN(v);
		}
		return cast this;
	}

	@:to function ___toFloat():Float {
		throw "TODO";
	}

	@:to function ___toInt():Int {
		if (this == null) {
			return 0;
		}
		if (Std.is(this, Int)) {
			return cast this;
		}
		if (Std.is(this, Float)) {
			var v:Float = cast this;
			return if (Math.isNaN(v)) 0 else Std.int(v);
		}
		if (Std.is(this, String)) {
			var i = Std.parseInt(cast this);
			return if (i == null) 0 else i;
		}
		if (Std.is(this, Bool)) {
			return if (cast this) 1 else 0;
		}
		return 0;
	}
	#end

	@:to inline function ___toOther():Dynamic {
		return this;
	}

	#if flash
	@:op(a.b) inline function ___get(name:String):ASAny return Reflect.getProperty(this, name);
	#else
	@:op(a.b) function ___get(name:String):ASAny {
		var value:Dynamic = Reflect.getProperty(this, name);
		if (Reflect.isFunction(value))
			return Reflect.makeVarArgs(args -> Reflect.callMethod(this, value, args));
		else
			return value;
	}
	#end

	@:op(a.b) inline function ___set(name:String, value:ASAny):ASAny {
		Reflect.setProperty(this, name, value);
		return value;
	}

	@:op(!a) inline function __not():Bool {
		return !___toBool();
	}

	@:op(a || b) static inline function __orBool(a:Bool, b:ASObject):ASObject {
		return if (a) a else b;
	}

	@:op(a || b) static inline function __or(a:ASObject, b:ASAny):ASAny {
		return if (a.__toBool()) a else b;
	}

	@:op(a && b) static inline function __andBool(a:Bool, b:ASObject):ASObject {
		return if (a) b else a;
	}

	@:op(a && b) static inline function __and(a:ASObject, b:ASAny):ASAny {
		return if (a.__toBool()) b else a;
	}

	@:op(a - b) static function ___minusInt(a:ASObject, b:Int):Int return a.___toInt() - b;
	@:op(a - b) static function ___minusInt2(a:Int, b:ASObject):Int return a - b.___toInt();
	@:commutative @:op(a + b) static function ___plusInt(a:ASObject, b:Int):Int return a.___toInt() + b;

	@:op(a - b) static function ___minusFloat(a:ASObject, b:Float):Float return a.___toFloat() - b;
	@:op(a - b) static function ___minusFloat2(a:Float, b:ASObject):Float return a - b.___toFloat();
	@:commutative @:op(a + b) static function ___plusFloat(a:ASObject, b:Float):Float return a.___toFloat() + b;

	@:op(a > b) static function ___gt(a:ASObject, b:Float):Bool return a.___toFloat() > b;
	@:op(a < b) static function ___lt(a:ASObject, b:Float):Bool return a.___toFloat() < b;
	@:op(a >= b) static function ___gte(a:ASObject, b:Float):Bool return a.___toFloat() >= b;
	@:op(a <= b) static function ___lte(a:ASObject, b:Float):Bool return a.___toFloat() <= b;

	@:op(a > b) static function ___gt2(a:Float, b:ASObject):Bool return a > b.___toFloat();
	@:op(a < b) static function ___lt2(a:Float, b:ASObject):Bool return a < b.___toFloat();
	@:op(a >= b) static function ___gte2(a:Float, b:ASObject):Bool return a >= b.___toFloat();
	@:op(a <= b) static function ___lte2(a:Float, b:ASObject):Bool return a <= b.___toFloat();

	@:op([]) inline function ___arrayGet(name:ASObject):ASAny return ___get(name);
	@:op([]) inline function ___arraySet(name:ASObject, value:ASAny):ASAny return ___set(name, value);

	@:from extern static inline function ___fromDictionary<K,V>(d:ASDictionary<K,V>):ASObject return cast d;
}
