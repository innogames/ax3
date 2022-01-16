#if macro
import haxe.macro.Expr;
#end

import haxe.Constraints.Function;

class ASCompat {
	public static inline final MAX_INT = 2147483647;
	public static inline final MIN_INT = -2147483648;

	public static inline final MAX_FLOAT = 1.79e+308;
	public static inline final MIN_FLOAT = -1.79E+308;

	public static inline function checkNullIteratee<T>(v:Null<T>, ?pos:haxe.PosInfos):Bool {
		if (v == null) {
			reportNullIteratee(pos);
			return false;
		}
		return true;
	}

	static function reportNullIteratee(pos:haxe.PosInfos) {
		haxe.Log.trace("FIXME: Null value passed as an iteratee for for-in/for-each expression!", pos);
	}

	public static inline function escape(s:String):String {
		#if flash
		return untyped __global__["escape"](s);
		#else
		return js.Lib.global.escape(s);
		#end
	}

	public static inline function unescape(s:String):String {
		#if flash
		return untyped __global__["unescape"](s);
		#else
		return js.Lib.global.unescape(s);
		#end
	}

	#if flash
	public static inline function describeType(value:Any):compat.XML {
		return flash.Lib.describeType(value);
	}

	// classObject is Any and not Class<Dynamic>, because in Flash we also want to pass Bool to it
	// this is also the reason this function is not automatically added to Globals.hx
	public static inline function registerClassAlias(aliasName:String, classObject:Any) {
		untyped __global__["flash.net.registerClassAlias"](aliasName, classObject);
	}
	#end

	// int(d), uint(d)
	public static inline function toInt(d:Dynamic):Int {
		#if flash
		return d;
		#else
		return Std.int(toNumber(d));
		#end
	}

	// Number(d)
	public static inline function toNumber(d:Dynamic):Float {
		#if flash
		return d;
		#else
		return js.Syntax.code("Number")(d);
		#end
	}

	// Boolean(d)
	public static inline function toBool(d:Dynamic):Bool {
		#if flash
		return d;
		#else
		return js.Syntax.code("Boolean")(d);
		#end
	}

	// String(d)
	public static inline function toString(d:Dynamic):String {
		#if flash
		return d;
		#else
		return js.Syntax.code("String")(d);
		#end
	}

	public static inline function as<T>(v:Dynamic, c:Class<T>):T {
		return flash.Lib.as(v, c);
	}

	public static inline function dynamicAs<T>(v:Dynamic, c:Class<T>):T {
		return flash.Lib.as(v, c);
	}

	public static inline function reinterpretAs<T>(v:Dynamic, c:Class<T>):T {
		return flash.Lib.as(v, c);
	}

	public static inline function toExponential(n:Float, ?digits:Int):String {
		return (cast n).toExponential(digits);
	}

	public static inline function toFixed(n:Float, ?digits:Int):String {
		return (cast n).toFixed(digits);
	}

	public static inline function toPrecision(n:Float, precision:Int):String {
		return (cast n).toPrecision(precision);
	}

	public static inline function toRadix(n:Float, radix:Int = 10):String {
		return (cast n).toString(radix);
	}

	// TODO: this is temporary
	public static inline function thisOrDefault<T>(value:T, def:T):T {
		return if ((value : ASAny)) value else def;
	}

	public static inline function stringAsBool(s:Null<String>):Bool {
		return (s : ASAny);
	}

	public static inline function floatAsBool(f:Null<Float>):Bool {
		return (f : ASAny);
	}

	public static inline function intAsBool(i:Null<Int>):Bool {
		return (i : ASAny);
	}

	public static inline function allocArray<T>(length:Int):Array<T> {
		var a = new Array<T>();
		a.resize(length);
		return a;
	}

	public static inline function arraySetLength<T>(a:Array<T>, newLength:Int):Int {
		a.resize(newLength);
		return newLength;
	}

	public static inline function arraySpliceAll<T>(a:Array<T>, startIndex:Int):Array<T> {
		return a.splice(startIndex, a.length);
	}

	public static function arraySplice<T>(a:Array<T>, startIndex:Int, deleteCount:Int, ?values:Array<T>):Array<T> {
		var result = a.splice(startIndex, deleteCount);
		if (values != null) {
			for (i in 0...values.length) {
				a.insert(startIndex + i, values[i]);
			}
		}
		return result;
	}

	public static inline function vectorSpliceAll<T>(a:flash.Vector<T>, startIndex:Int):flash.Vector<T> {
		return a.splice(startIndex, a.length);
	}

	public static function vectorSplice<T>(a:flash.Vector<T>, startIndex:Int, deleteCount:Int, ?values:Array<T>):flash.Vector<T> {
		var result = a.splice(startIndex, deleteCount);
		if (values != null) {
			for (i in 0...values.length) {
				a.insertAt(startIndex + i, values[i]);
			}
		}
		return result;
	}

	public static macro function vectorClass<T>(typecheck:Expr):ExprOf<Class<flash.Vector<T>>>;
	public static macro function asVector<T>(value:Expr, typecheck:Expr):ExprOf<Null<flash.Vector<T>>>;
	public static macro function isVector<T>(value:Expr, typecheck:Expr):ExprOf<Bool>;

	@:noCompletion public static inline function _asVector<T>(value:Any):Null<flash.Vector<T>> return if (_isVector(value)) value else null;
	@:noCompletion public static inline function _isVector(value:Any):Bool
		return Reflect.hasField(value, '__array') && Reflect.hasField(value, 'fixed');

	public static inline function asFunction(v:Any):Null<ASFunction> {
		return if (Reflect.isFunction(v)) v else null;
	}

	public static macro function setTimeout(closure:ExprOf<haxe.Constraints.Function>, delay:ExprOf<Float>, arguments:Array<Expr>):ExprOf<UInt>;

	public static inline function clearTimeout(id:UInt):Void {
		#if flash
		untyped __global__["flash.utils.clearTimeout"](id);
		#else
		js.Browser.window.clearTimeout(id);
		#end
	}

	public static macro function setInterval(closure:ExprOf<haxe.Constraints.Function>, delay:ExprOf<Float>, arguments:Array<Expr>):ExprOf<UInt>;

	public static inline function clearInterval(id:UInt):Void {
		#if flash
		untyped __global__["flash.utils.clearInterval"](id);
		#else
		js.Browser.window.clearInterval(id);
		#end
	}

	public static macro function processNull<T>(e:ExprOf<Null<T>>):ExprOf<T>;

	public static inline function processNullInt(v:Null<Int>):Int {
		#if flash
		return v;
		#else
		return cast v | 0;
		#end
	}

	public static inline function processNullFloat(v:Null<Float>):Float {
		#if flash
		return v;
		#else
		return js.Syntax.code("Number")(v);
		#end
	}

	public static inline function processNullBool(v:Null<Bool>):Bool {
		#if flash
		return v;
		#else
		return !!v;
		#end
	}

	/**
	 * https://github.com/HaxeFoundation/as3hx/blob/829f661777d0458c7902c4235a4c944de4c8cc6d/src/as3hx/Compat.hx#L114
	 */
	public static function parseInt(s:String, ?base:Int):Null<Int> {
        #if js
		if (base == null) base = s.indexOf("0x") == 0 ? 16 : 10;
		var v:Int = js.Syntax.code("parseInt({0}, {1})", s, base);
		return Math.isNaN(v) ? null : v;
		#elseif flash
		if (base == null) base = 0;
		var v:Int = untyped __global__["parseInt"](s, base);
		return Math.isNaN(v) ? null : v;
		#else
		var BASE = "0123456789abcdefghijklmnopqrstuvwxyz";
		if (base != null && (base < 2 || base > BASE.length))
		return throw 'invalid base ${base}, it must be between 2 and ${BASE.length}';
		s = s.trim().toLowerCase();
		var sign = if (s.startsWith("+")) {
			s = s.substring(1);
			1;
		} else if (s.startsWith("-")) {
			s = s.substring(1);
			-1;
		} else {
			1;
		};
		if (s.length == 0) return null;
		if (s.startsWith('0x')) {
		if (base != null && base != 16) return null; // attempting at converting a hex using a different base
			base = 16;
			s = s.substring(2);
		} else if (base == null) {
			base = 10;
		}
		var acc = 0;
		try s.split('').map(function(c) {
			var i = BASE.indexOf(c);
			if(i < 0 || i >= base) throw 'invalid';
			acc = (acc * base) + i;
		}) catch(e:Dynamic) {};
		return acc * sign;
		#end
	}

}

class ASArray {
	public static inline final CASEINSENSITIVE = 1;
	public static inline final DESCENDING = 2;
	public static inline final NUMERIC = 16;
	public static inline final RETURNINDEXEDARRAY = 8;
	public static inline final UNIQUESORT = 4;

	public static inline function sort<T>(a:Array<T>, f:(T, T) -> Int):Array<T> {
		a.sort(f);
		return a;
	}

	public static inline function sortOn<T>(a:Array<T>, fieldName:String, options:Int):Array<T> {
		// TODO: this will only work on Flash, but we need it to _compile_ on JS too for now, so `RectanglePacker` is not breaking the build :-P
		return (cast a).sortOn(fieldName, options);
	}

	#if flash // TODO: implement for other targets
	public static inline function sortWithOptions<T>(a:Array<T>, options:Int):Array<T> {
		return (cast a).sort(options);
	}
	#end

	public static macro function pushMultiple<T>(a:ExprOf<Array<T>>, first:ExprOf<T>, rest:Array<ExprOf<T>>):ExprOf<Int>;
	public static macro function unshiftMultiple<T>(a:ExprOf<Array<T>>, first:ExprOf<T>, rest:Array<ExprOf<T>>):ExprOf<Int>;
}


class ASVector {
	public static inline function sort<T>(a:flash.Vector<T>, f:(T, T) -> Int):flash.Vector<T> {
		a.sort(f);
		return a;
	}

	#if flash // TODO: implement for other targets
	public static inline function sortWithOptions<T>(a:flash.Vector<T>, options:Int):flash.Vector<T> {
		return (cast a).sort(options);
	}
	#end
}

class ASVectorTools {
	#if flash inline #end
	public static function forEach<T>(v:flash.Vector<T>, callback:(item:T, index:Int, vector:flash.Vector<T>)->Void):Void {
		#if flash
		(cast v).forEach(callback);
		#else
		for (i in 0...v.length) {
			callback(v[i], i, v);
		}
		#end
	}

	#if flash inline #end
	public static function filter<T>(v:flash.Vector<T>, callback:(item:T, index:Int, vector:flash.Vector<T>)->Bool):flash.Vector<T> {
		#if flash
		return (cast v).filter(callback);
		#else
		var result = new flash.Vector<T>();
		for (i in 0...v.length) {
			var item = v[i];
			if (callback(item, i, v)) {
				result.push(item);
			}
		}
		return result;
		#end
	}

	#if flash inline #end
	public static function map<T,T2>(v:flash.Vector<T>, callback:(item:T, index:Int, vector:flash.Vector<T>)->T2):flash.Vector<T2> {
		#if flash
		return (cast v).map(callback);
		#else
		var result = new flash.Vector<T2>(v.length);
		for (i in 0...v.length) {
			result[i] = callback(v[i], i, v);
		}
		return result;
		#end
	}

	#if flash inline #end
	public static function every<T>(v:flash.Vector<T>, callback:(item:T, index:Int, vector:flash.Vector<T>)->Bool):Bool {
		#if flash
		return (cast v).every(callback);
		#else
		for (i in 0...v.length) {
			if (!callback(v[i], i, v)) {
				return false;
			}
		}
		return true;
		#end
	}

	#if flash inline #end
	public static function some<T>(v:flash.Vector<T>, callback:(item:T, index:Int, vector:flash.Vector<T>)->Bool):Bool {
		#if flash
		return (cast v).some(callback);
		#else
		for (i in 0...v.length) {
			if (callback(v[i], i, v)) {
				return true;
			}
		}
		return false;
		#end
	}
}

class ASDate {
	public static inline function toDateString(d:Date):String {
		return DateTools.format(Date.fromTime(0), "%a %b %d %Y");
	}

	#if (flash || js) // TODO: implement this for other platforms
	public static inline function setTime(d:Date, millisecond:Float):Float {
		return (cast d).setTime(millisecond);
	}

	public static inline function setDate(d:Date, day:Float):Float {
		return (cast d).setDate(day);
	}

	public static inline function setMonth(d:Date, month:Float, ?day:Float):Float {
		return (cast d).setMonth(month, day);
	}

	public static inline function setHours(d:Date, hour:Int, ?minute:Int, ?second:Int, ?millisecond:Int):Float {
		return (cast d).setHours(hour, minute, second, millisecond);
	}

	public static inline function setMinutes(d:Date, minute:Float, ?second:Float, ?millisecond:Float):Float {
		return (cast d).setMinutes(minute, second, millisecond);
	}

	public static inline function setSeconds(d:Date, second:Float, ?millisecond:Float):Float {
		return (cast d).setSeconds(second, millisecond);
	}

	public static inline function setUTCDate(d:Date, day:Float):Float {
		return (cast d).setUTCDate(day);
	}

	public static inline function setFullYear(d:Date, year:Float, ?month:Float, ?day:Float):Float {
		return (cast d).setFullYear(year, month, day);
	}

	public static inline function setUTCFullYear(d:Date, year:Float, ?month:Float, ?day:Float):Float {
		return (cast d).setUTCFullYear(year, month, day);
	}

	public static inline function setUTCHours(d:Date, hour:Float, ?minute:Float, ?second:Float, ?millisecond:Float):Float {
		return (cast d).setUTCHours(hour, minute, second, millisecond);
	}

	public static inline function getUTCMilliseconds(d:Date):Float {
		return (cast d).getUTCMilliseconds();
	}

	public static inline function setUTCMilliseconds(d:Date, millisecond:Float):Float {
		return (cast d).setUTCMilliseconds(millisecond);
	}

	public static inline function setUTCMinutes(d:Date, minute:Float, ?second:Float, ?millisecond:Float):Float {
		return (cast d).setUTCMinutes(minute, second, millisecond);
	}

	public static inline function setUTCMonth(d:Date, month:Float, ?day:Float):Float {
		return (cast d).setUTCMonth(month, day);
	}

	public static inline function setUTCSeconds(d:Date, second:Float, ?millisecond:Float):Float {
		return (cast d).setUTCSeconds(second, millisecond);
	}
	#end
}
