package ax3;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
using haxe.macro.Tools;
#end

@:dce
class WithMacro {
	/**
		Return a copy of a structure, replacing given fields.

		This provides an OCaml-like `with` syntax:
		```haxe
		object.with(a = 13, b = "hi")
		// is the same as
		{a: 13, b: "hi", otherField: object.otherField}
		```
	**/
	public static macro function with<T:{}>(object:ExprOf<T>, overrides:Array<Expr>):ExprOf<T> {
		// process given object expression and get its type
		var type = Context.typeof(object);

		// check that it's an anonymous structure and extract fields information
		var fields = switch type.follow() {
			case TAnonymous(_.get() => anon): anon.fields;
			case _: throw new Error("Not an anonymous structure", object.pos);
		}

		var objectDecl:Array<ObjectField> = [];
		var overriden = new Map();

		// check field override argument expressions and add them to the new object declaration,
		// as well as marking them as overriden for easier checking in the second part
		for (expr in overrides) {
			switch expr {
				case macro $i{fieldName} = $value:
					objectDecl.push({field: fieldName, expr: value});
					overriden[fieldName] = true;
				case {expr: EDisplay(macro null, DKMarked), pos: p}: // toplevel completion
					var remainingFieldsCT = TAnonymous([
						for (field in fields) if (!overriden.exists(field.name)) {
							pos: field.pos,
							name: field.name,
							doc: field.doc,
							kind: FVar(field.type.toComplexType())
						}
					]);
					return {pos: p, expr: EDisplay({pos: p, expr: EField(macro (null : $remainingFieldsCT), "")}, DKDot)};
				case _:
					throw new Error("Invalid override expression, should be field=value", expr.pos);
			}
		}

		// add the rest of fields from this type (those that aren't overriden)
		for (field in fields) {
			var fieldName = field.name;
			if (!overriden.exists(fieldName)) {
				// we use `tmp` as the reference for the original object, since we store it into a local var
				objectDecl.push({field: fieldName, expr: macro @:pos(object.pos) tmp.$fieldName});
			}
		}

		// construct object declaration expression
		var expr = {expr: EObjectDecl(objectDecl), pos: Context.currentPos()};

		// get the syntax representation of object's type
		var ct = type.toComplexType();

		// construct the whole resulting expression. it consists of three parts:
		// - the `tmp` var declaration in which we store the original object
		// - the generated new object declaration expression (that references `tmp` for non-overriden fields)
		// - the type-check expression that ensures that our resulting expression is of correct type
		return macro @:pos(expr.pos) ({ var tmp = $object; $expr; } : $ct);
	}
}
