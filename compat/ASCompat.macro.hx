#if macro
import haxe.macro.Expr;

class ASArray {
	static function pushMultiple<T>(a:Expr, first:Expr, rest:Array<Expr>):Expr {
		var exprs = [macro ___arr.push($first)];
		for (expr in rest) {
			exprs.push(macro ___arr.push($expr));
		}
		return macro @:pos(haxe.macro.Context.currentPos()) {
			var ___arr = $a;
			$b{exprs};
		};
	}
}
#end
