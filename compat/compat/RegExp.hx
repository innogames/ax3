package compat;
#if js
import js.lib.RegExp.RegExpMatch;
#end
import haxe.extern.EitherType;
import haxe.Constraints.Function;

private typedef RegExpImpl = #if js js.lib.RegExp #else flash.utils.RegExp #end;

@:forward(lastIndex)
abstract RegExp(RegExpImpl) {
	public inline function new(pattern, options = "") {
		this = new RegExpImpl(pattern, options);
	}

	public inline function exec(s:String): RegExpResult {
		return this.exec(s);
	}

	public inline function test(s:String):Bool {
		return this.test(s);
	}

	public inline function match(s:String):Array<String> {
		#if flash
		return (cast s).match(this);
		#else
		var match = (cast s).match(this);
		return if (match == null) [] else match;
		#end
	}

	public inline function search(s:String):Int {
		return (cast s).search(this);
	}

	// TODO: have separate function for String and Function values of `by`?
	public inline function replace(s:String, by:EitherType<String,Function>):String {
		return (cast s).replace(this, by);
	}

	public inline function split(s:String):Array<String> {
		return (cast s).split(this);
	}
}

#if js
abstract RegExpResult(RegExpMatch) from RegExpMatch to RegExpMatch {

	@:to public function toString(): Null<String> return this != null ? this[0] : null;

}
#else
typedef RegExpResult = Dynamic;
#end