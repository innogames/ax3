#if flash
typedef ASFunction = flash.utils.Function;
#else
@:callable
abstract ASFunction(Dynamic)
	from haxe.Constraints.Function
	to haxe.Constraints.Function

	// to haxe.Constraints.Function is not enough for unifying with actual function types
	// so we have to do this ¯\_(ツ)_/¯
	to ()->Dynamic
	to (Dynamic)->Dynamic
	to (Dynamic,Dynamic)->Dynamic
	to (Dynamic,Dynamic,Dynamic)->Dynamic
	to (Dynamic,Dynamic,Dynamic,Dynamic)->Dynamic
	to (Dynamic,Dynamic,Dynamic,Dynamic,Dynamic)->Dynamic
	to (Dynamic,Dynamic,Dynamic,Dynamic,Dynamic,Dynamic)->Dynamic
{

	#if js
	public var length(get, never): Int;

	private function get_length(): Int {
		final f = this;
		return js.Syntax.code('f.length');
	}
	#end

}
#end