#if macro
import haxe.macro.Expr;
#end

import haxe.Constraints.Function;

class ASCompat {
	public static inline final MAX_INT = 2147483647;
	public static inline final MIN_INT = -2147483648;

	public static inline final MAX_FLOAT = 1.79e+308;
	public static inline final MIN_FLOAT = -1.79E+308;

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

	public static inline function toInt(d:Dynamic):Int {
		#if flash
		return d;
		#else
		return Std.int(toNumber(d));
		#end
	}

	public static inline function toNumber(d:Dynamic):Float {
		#if flash
		return d;
		#else
		return js.Syntax.code("Number")(d);
		#end
	}

	public static inline function toString(d:Dynamic):String {
		#if flash
		return d;
		#else
		return js.Syntax.code("String")(d);
		#end
	}

	public static inline function toBool(d:Dynamic):Bool {
		#if flash
		return d;
		#else
		return js.Syntax.code("Boolean")(d);
		#end
	}

	public static inline function as<T>(v:Dynamic, c:Class<T>):T {
		return flash.Lib.as(v, c);
	}

	public static inline function toFixed(n:Float):String {
		return (cast n).toFixed();
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

	public static inline function intAsBool(f:Null<Int>):Bool {
		return (f : ASAny);
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
}

class ASArray {
	public static inline final CASEINSENSITIVE = 1;
	public static inline final DESCENDING = 2;
	public static inline final NUMERIC = 16;
	public static inline final RETURNINDEXEDARRAY = 8;
	public static inline final UNIQUESORT = 4;

	public static inline function sortOn<T>(a:Array<T>, fieldName:String, options:Int):Array<T> {
		return (cast a).sortOn(fieldName, options);
	}

	public static macro function pushMultiple<T>(a:ExprOf<Array<T>>, first:ExprOf<T>, rest:Array<ExprOf<T>>):ExprOf<Int>;
}


class ASVector {
	public static inline function sort<T>(a:flash.Vector<T>, options:Int):flash.Vector<T> {
		return (cast a).sort(options);
	}
}

class ASDate {
	public static inline function toDateString(d:Date):String {
		return DateTools.format(Date.fromTime(0), "%a %b %d %Y");
	}

	#if (flash || js) // TODO: implement this for other platforms
	public static inline function setHours(d:Date, hour:Int, ?minute:Int, ?second:Int, ?millisecond:Int):Float {
		return (cast d).setHours(hour, minute, second, millisecond);
	}

	public static inline function getTimezoneOffset(d:Date):Float {
		return (cast d).getTimezoneOffset();
	}
	#end
}
