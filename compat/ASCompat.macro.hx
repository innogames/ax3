#if macro
import haxe.macro.Expr;

class ASArray {
	public static macro function pushMultiple<T>(a:ExprOf<Array<T>>, first:ExprOf<T>, rest:Array<ExprOf<T>>):ExprOf<Int> {
		var exprs = [macro ___arr.push($first)];
		for (expr in rest) {
			exprs.push(macro ___arr.push($expr));
		}
		return @:pos(haxe.macro.Context.currentPos()) {
			var ___arr = $a;
			$b{exprs};
		};
	}
}
#end