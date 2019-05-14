package ax3;
#if macro

import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;
using haxe.macro.Tools;

class ParseTreeDumpMacro {
	static function build() {
		var buildFields = Context.getBuildFields();
		var root = Context.getType("ax3.ParseTree.File");
		var fields = new Map();
		walk(root, root, fields, null);
		for (field in fields)
			buildFields.push(field);
		return buildFields;
	}

	static function walk(type:Type, origType, fields:Map<String,Field>, name:Null<String>):Expr {
		switch (type) {
			case TInst(_.get() => {pack: ["ax3"], name: "Token"}, _):
				return macro printToken;

			case TInst(_.get() => {pack: [], name: "String"}, _):
				return macro function(s, indent) return s;

			case TInst(_.get() => {pack: [], name: "Array"}, [elemT]) if (name != null):
				return walkSeq(elemT, origType, name, macro printArray, fields);

			case TType(_.get() => dt, params):
				switch [dt, params] {
					case [{pack: ["ax3"], name: "Separated"}, [elemT]] if (name != null):
						return walkSeq(elemT, origType, name, macro printSeparated, fields);

					case _:
						return walk(dt.type.applyTypeParameters(dt.params, params), origType, fields, dt.name);
				}

			case TEnum(_.get() => en, _):
				return walkEnum(en, origType, fields);

			case TAbstract(_.toString() => "Null", [t]):
				var method = walk(t, t, fields, name);
				return macro printNullable.bind($method);

			case TAnonymous(_.get() => anon) if (name != null):
				return walkAnon(anon, origType, fields, name);

			case _:
		}
		throw 'TODO: ${type.toString()}';
	}

	static function walkAnon(anon:AnonType, origType:Type, fields:Map<String,Field>, name:String):Expr {
		var methodName = 'print$name';
		if (!fields.exists(name)) {
			fields.set(name, null);

			anon.fields.sort((a, b) -> Context.getPosInfos(a.pos).min - Context.getPosInfos(b.pos).min);

			var fieldExprs = [];
			for (field in anon.fields) {
				var fname = field.name;
				var method = walk(field.type, field.type, fields, name + "_" + fname);
				fieldExprs.push(macro nextIdent + $v{fname + ": "} + $method(node.$fname, nextIdent));
			}

			fields.set(name, {
				pos: Context.currentPos(),
				name: methodName,
				access: [APublic,AStatic],
				kind: FFun({
					args: [
						{name: "node", type: origType.toComplexType()},
						{name: "indent", type: macro : String},
					],
					ret: macro : String,
					expr: macro {
						var nextIdent = indent + "  ";
						var fields = $a{fieldExprs};
						return $v{name + " {"} + (
							if (fields.length > 0)
								"\n" + fields.join("\n") + "\n" + indent + "}"
							else
								"}"
						);
					}
				})
			});
		}
		return macro $i{methodName};
	}

	static function walkSeq(elemT:Type, origType:Type, name:String, walkFn:Expr, fields:Map<String,Field>):Expr {
		var methodName = 'walk$name';
		if (!fields.exists(name)) {
			fields[name] = null;

			var expr = walk(elemT, elemT, fields, name + "_elem");

			fields.set(name, {
				pos: Context.currentPos(),
				name: methodName,
				access: [APublic, AStatic],
				kind: FFun({
					args: [
						{name: "elems", type: origType.toComplexType()},
						{name: "indent", type: macro : String}
					],
					ret: null,
					expr: macro return $walkFn(elems, $expr, indent)
				})
			});

		}
		return macro $i{methodName};
	}

	static function walkEnum(en:EnumType, origType:Type, fields:Map<String,Field>):Expr {
		var methodName = "print" + en.name;
		if (!fields.exists(en.name)) {
			fields.set(en.name, null);

			var cases = [];
			for (ctor in en.constructs) {
				switch (ctor.type) {
					case TFun(args, _):
						var patternArgs = [];
						var locals = [];
						var fieldExprs = [];
						for (arg in args) {
							var name = arg.name;
							patternArgs.push(macro var $name);
							var local = macro $i{name};
							locals.push(local);

							var method = walk(arg.t, arg.t, fields, name + "_" + ctor.name + "_" + arg.name);
							fieldExprs.push(macro nextIdent + $v{arg.name + ": "} + $method($local, nextIdent));
						}

						cases.push({
							values: [macro $i{ctor.name}($a{patternArgs})],
							expr: macro {
								var nextIdent = indent + "  ";
								var fields = $a{fieldExprs};
								$v{ctor.name + "(\n"} + fields.join("\n") + "\n" + indent + ")";
							}
						});

					case TEnum(_):
						cases.push({
							values: [macro $i{ctor.name}],
							expr: macro $v{ctor.name},
						});

					default: throw false;
				}
			}

			fields.set(en.name, {
				pos: en.pos,
				name: methodName,
				access: [APublic, AStatic],
				kind: FFun({
					args: [
						{name: "node", type: origType.toComplexType()},
						{name: "indent", type: macro : String}
					],
					ret: macro : String,
					expr: macro return ${{expr: ESwitch(macro node, cases, null), pos: en.pos}}
				})
			});
		}
		return macro $i{methodName};
	}
}
#end
