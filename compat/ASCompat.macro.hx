#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
using haxe.macro.Tools;

class ASCompat {
	static function extractVectorElemType(typecheck:Expr):ComplexType {
		switch typecheck.expr {
			case EParenthesis({expr: ECheckType({expr: EConst(CIdent("_"))}, elementType)}):
				return elementType;
			case _:
				throw new Error("This argument must be an `(_:ElementType)` expression", typecheck.pos);
		}
	}

	static function makeVectorTypeReference(elementType:ComplexType, pos:Position):Expr {
		if (elementType.match(TPath({pack: [], name: "ASAny"}))) {
			elementType = macro : flash.AnyType;
		}
		return macro @:pos(pos) (flash.Vector.typeReference() : Class<flash.Vector<$elementType>>);
	}

	static function vectorClass(typecheck:Expr) { // somehow this :Expr typehint is required, otherwise this function receives `null`, will have to reduce this one
		var elementType = extractVectorElemType(typecheck);
		if (Context.defined("flash")) {
			return makeVectorTypeReference(elementType, Context.currentPos());
		} else {
			Context.warning("Getting a value of a specific Class<Vector<T>> is only supported on Flash and will be `null` on other targets", Context.currentPos());
			return macro null;
		}
	}

	static function asVector(value:Expr, typecheck:Expr) {
		var elementType = extractVectorElemType(typecheck);
		var ctReturn = macro : Null<flash.Vector<$elementType>>;
		if (Context.defined("flash")) {
			var eVectorClass = makeVectorTypeReference(elementType, typecheck.pos);
			return macro @:pos(Context.currentPos()) (flash.Lib.as($value, $eVectorClass) : $ctReturn);
		} else {
			return macro @:pos(Context.currentPos()) (ASCompat._asVector($value) : $ctReturn);
		}

	}

	static function isVector(value:Expr, typecheck:Expr) {
		if (Context.defined("flash")) {
			var eVectorClass = makeVectorTypeReference(extractVectorElemType(typecheck), typecheck.pos);
			return macro @:pos(Context.currentPos()) Std.is($value, $eVectorClass);
		} else {
			return macro @:pos(Context.currentPos()) ASCompat._isVector($value);
		}
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
		return makeMultipleAppend("push", a, first, rest);
	}

	static function unshiftMultiple<T>(a:Expr, first:Expr, rest:Array<Expr>):Expr {
		return makeMultipleAppend("unshift", a, first, rest);
	}

	static function makeMultipleAppend(methodName:String, object:Expr, firstValue:Expr, rest:Array<Expr>):Expr {
		var pos = Context.currentPos();
		var exprs = [macro @:pos(pos) ___arr.$methodName($firstValue)];
		for (expr in rest) {
			exprs.push(macro @:pos(pos) ___arr.$methodName($expr));
		}
		return macro @:pos(pos) {
			var ___arr = $object;
			$b{exprs};
		};
	}
}
#end
