#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
using haxe.macro.Tools;

class ASCompat {
	static function vectorClass(typecheck:Expr) { // somehow this :Expr typehint is required, otherwise this function receives `null`, will have to reduce this one
		return switch typecheck.expr {
			case EParenthesis({expr: ECheckType({expr: EConst(CIdent("_"))}, elementType)}):
				macro @:pos(Context.currentPos()) (flash.Vector.typeReference() : Class<flash.Vector<$elementType>>);
			case _:
				throw new Error("The `vectorClass` function expects an `(_:ElementType)` expression", typecheck.pos);
		};
	}

	static function setTimeout(closure, delay, arguments:Array<Expr>) {
		var args = [closure,delay].concat(arguments);
		var setTimeoutExpr =
			if (Context.defined("flash"))
				macro untyped __global__["flash.utils.setTimeout"]
			else
				macro js.Browser.window.setTimeout;
		return macro @:pos(Context.currentPos()) $setTimeoutExpr($a{args});
	}

	static function setInterval(closure, delay, arguments:Array<Expr>) {
		var args = [closure,delay].concat(arguments);
		var setIntervalExpr =
			if (Context.defined("flash"))
				macro untyped __global__["flash.utils.setInterval"]
			else
				macro js.Browser.window.setInterval;
		return macro @:pos(Context.currentPos()) $setIntervalExpr($a{args});
	}

	static function processNull(e:Expr):Expr {
		var e = Context.typeExpr(e);
		switch e.t {
			case TAbstract(_.toString() => "Null", [actualType]):
				var actualMethod = switch actualType.toString() {
					case "Int" | "UInt": "processNullInt";
					case "Float": "processNullFloat";
					case "Bool": "processNullBool";
					case _: throw new Error("processNull can only be called with Null<Int/UInt/Bool/Float>", e.pos);
				}
				var e = Context.storeTypedExpr(e);
				return macro @:pos(Context.currentPos()) ASCompat.$actualMethod($e);
			case _:
				throw new Error("processNull can only be called with Null<Int/UInt/Bool/Float>", e.pos);
		}
	}
}

class ASArray {
	static function pushMultiple<T>(a:Expr, first:Expr, rest:Array<Expr>):Expr {
		var exprs = [macro ___arr.push($first)];
		for (expr in rest) {
			exprs.push(macro ___arr.push($expr));
		}
		return macro @:pos(Context.currentPos()) {
			var ___arr = $a;
			$b{exprs};
		};
	}
}
#end
