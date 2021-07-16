package ax3;

import ax3.ParseTree;
import ax3.ParseTree.*;
import ax3.TypedTree;
import ax3.TypedTreeTools.mk;
import ax3.TypedTreeTools.mkDeclRef;
import ax3.TypedTreeTools.skipParens;
import ax3.TypedTreeTools.tUntypedArray;
import ax3.TypedTreeTools.tUntypedObject;
import ax3.TypedTreeTools.tUntypedDictionary;
import ax3.TypedTreeTools.getConstructor;
import ax3.TypedTreeTools.isFieldStatic;
import ax3.TypedTreeTools.getFunctionTypeFromSignature;
import ax3.TypedTreeTools.typeEq;

typedef Locals = Map<String, TVar>;

typedef TyperContext = {
	function reportError(msg:String, pos:Int):Void;
	function throwError(msg:String, pos:Int):Dynamic;
	function getCurrentClass():Null<TClassOrInterfaceDecl>;
	function resolveDotPath(path:Array<String>):TDecl;
	function resolveType(t:SyntaxType):TType;
	final haxeTypes:HaxeTypeResolver;
}

class ExprTyper {
	final context:Context;
	final typerContext:TyperContext;
	final localsStack:Array<Locals>;
	final tree:TypedTree;
	var locals:Locals;
	var currentReturnType:TType;

	public function new(context, tree, typerContext) {
		this.context = context;
		this.tree = tree;
		this.typerContext = typerContext;
		locals = new Map();
		localsStack = [locals];
	}

	inline function err(msg, pos) typerContext.reportError(msg, pos);
	inline function throwErr(msg, pos):Dynamic return typerContext.throwError(msg, pos);

	function pushLocals() {
		locals = locals.copy();
		localsStack.push(locals);
	}

	function popLocals() {
		localsStack.pop();
		locals = localsStack[localsStack.length - 1];
	}

	function addLocal(name:String, type:TType):TVar {
		return locals[name] = {name: name, type: type};
	}

	public function typeFunctionExpr(sig:TFunctionSignature, block:BracedExprBlock):TExpr {
		pushLocals();
		for (arg in sig.args) {
			if (arg.v != null) throw "double function typing";
			arg.v = addLocal(arg.name, arg.type);
		}
		var oldReturnType = currentReturnType;
		currentReturnType = sig.ret.type;
		var block = typeBlock(block);
		currentReturnType = oldReturnType;
		popLocals();
		return mk(TEBlock(block), TTVoid, TTVoid);
	}

	public function typeBlock(b:BracedExprBlock):TBlock {
		pushLocals();
		var exprs = [];
		for (e in b.exprs) {
			exprs.push({
				expr: typeExpr(e.expr, TTVoid),
				semicolon: e.semicolon
			});
		}
		popLocals();
		return {
			syntax: {openBrace: b.openBrace, closeBrace: b.closeBrace},
			exprs: exprs
		};
	}

	public function typeExpr(e:Expr, expectedType:TType):TExpr {
		return switch (e) {
			case EIdent(i):
				typeIdent(i, e, expectedType);

			case ELiteral(l):
				typeLiteral(l, expectedType);

			case ECall(e, args):
				typeCall(e, args, expectedType);

			case EParens(openParen, e, closeParen):
				var e = typeExpr(e, expectedType);
				mk(TEParens(openParen, e, closeParen), e.type, expectedType);

			case EArrayAccess(e, openBracket, eindex, closeBracket):
				typeArrayAccess(e, openBracket, eindex, closeBracket, expectedType);

			case EArrayDecl(d):
				typeArrayDecl(d, expectedType);

			case EVectorDecl(newKeyword, t, d):
				typeVectorDecl(newKeyword, t, d, expectedType);

			case EReturn(keyword, eReturned):
				if (expectedType != TTVoid) throw "assert";
				mk(TEReturn(keyword, if (eReturned != null) typeExpr(eReturned, currentReturnType) else null), TTVoid, TTVoid);

			case ETypeof(keyword, ex):
				if (ex == null) throw "assert";
				mk(TETypeof(keyword, typeExpr(ex, TTAny)), TTVoid, TTVoid);

			case EThrow(keyword, e):
				if (expectedType != TTVoid) throw "assert";
				mk(TEThrow(keyword, typeExpr(e, TTAny)), TTVoid, TTVoid);

			case EBreak(keyword):
				if (expectedType != TTVoid) throw "assert";
				mk(TEBreak(keyword), TTVoid, TTVoid);

			case EContinue(keyword):
				if (expectedType != TTVoid) throw "assert";
				mk(TEContinue(keyword), TTVoid, TTVoid);

			case EDelete(keyword, e):
				mk(TEDelete(keyword, typeExpr(e, TTAny)), TTBoolean, expectedType);

			case ENew(keyword, e, args): typeNew(keyword, e, args, expectedType);
			case EField(eobj, dot, fieldName): typeField(eobj, dot, fieldName, expectedType);
			case EBlock(b): mk(TEBlock(typeBlock(b)), TTVoid, TTVoid);
			case EObjectDecl(openBrace, fields, closeBrace): typeObjectDecl(openBrace, fields, closeBrace, expectedType);
			case EIf(keyword, openParen, econd, closeParen, ethen, eelse): typeIf(keyword, openParen, econd, closeParen, ethen, eelse, expectedType);
			case ETernary(econd, question, ethen, colon, eelse): typeTernary(econd, question, ethen, colon, eelse, expectedType);
			case EWhile(w): typeWhile(w, expectedType);
			case EDoWhile(w): typeDoWhile(w, expectedType);
			case EFor(f): typeFor(f, expectedType);
			case EForIn(f): typeForIn(f, expectedType);
			case EForEach(f): typeForEach(f, expectedType);
			case EBinop(a, op, b): typeBinop(a, op, b, expectedType);
			case EPreUnop(op, e): typePreUnop(op, e, expectedType);
			case EPostUnop(e, op): typePostUnop(e, op, expectedType);
			case EVars(kind, vars): typeVars(kind, vars, expectedType);
			case EAs(e, keyword, t): typeAs(e, keyword, t, expectedType);
			case EVector(v): typeVector(v, expectedType);
			case ESwitch(keyword, openParen, subj, closeParen, openBrace, cases, closeBrace): typeSwitch(keyword, openParen, subj, closeParen, openBrace, cases, closeBrace, expectedType);
			case ETry(keyword, block, catches, finally_): typeTry(keyword, block, catches, finally_, expectedType);
			case EFunction(keyword, name, fun): typeLocalFunction(keyword, name, fun, expectedType);

			case EXmlAttr(e, dot, at, attrName): typeXmlAttr(e, dot, at, attrName, expectedType);
			case EXmlAttrExpr(e, dot, at, openBracket, eattr, closeBracket): typeXmlAttrExpr(e, dot, at, openBracket, eattr, closeBracket, expectedType);
			case EXmlDescend(e, dotDot, childName): typeXmlDescend(e, dotDot, childName, expectedType);
			case ECondCompValue(v): mk(TECondCompValue(typeCondCompVar(v)), TTAny, expectedType);
			case ECondCompBlock(v, b): typeCondCompBlock(v, b, expectedType);
			case EUseNamespace(ns): mk(TEUseNamespace(ns), TTVoid, expectedType);
		}
	}

	function typeLocalFunction(keyword:Token, name:Null<Token>, fun:Function, expectedType:TType):TExpr {
		var haxeTypes = HaxeTypeAnnotation.extract(keyword.leadTrivia);
		var sig = typeFunctionSignature(fun.signature, haxeTypes);
		return mk(TELocalFunction({
			syntax: {keyword: keyword},
			name: if (name == null) null else {name: name.text, syntax: name},
			fun: {
				sig: sig,
				expr: typeFunctionExpr(sig, fun.block)
			}
		}), getFunctionTypeFromSignature(sig), expectedType);
	}

	// TODO: copypasta from Typer
	function typeFunctionSignature(sig:FunctionSignature, haxeType:Null<HaxeTypeAnnotation>):TFunctionSignature {
		var typeOverrides = typerContext.haxeTypes.resolveSignature(haxeType, sig.openParen.pos);

		var targs =
			if (sig.args != null) {
				separatedToArray(sig.args, function(arg, comma) {
					return switch (arg) {
						case ArgNormal(a):
							var typeOverride = if (typeOverrides == null) null else typeOverrides.args[a.name.text];

							var type:TType = if (typeOverride != null) typeOverride else if (a.type == null) TTAny else typerContext.resolveType(a.type.type);
							var init:Null<TVarInit>;
							if (a.init == null) {
								init = null;
							} else {
								init = {
									equalsToken: a.init.equalsToken,
									expr: typeExpr(a.init.expr, type) // the only difference from Typer.typeFunctionSignature atm
								};
							}
							{syntax: {name: a.name}, name: a.name.text, type: type, kind: TArgNormal(a.type, init), v: null, comma: comma};

						case ArgRest(dots, name, typeHint):
							{syntax: {name: name}, name: name.text, type: tUntypedArray, kind: TArgRest(dots, TRestAs3, typeHint), v: null, comma: comma};
					}
				});
			} else {
				[];
			};

		var returnTypeOverride = if (typeOverrides == null) null else typeOverrides.ret;

		var tret:TTypeHint;
		if (sig.ret != null) {
			tret = {
				type: if (returnTypeOverride != null) returnTypeOverride else typerContext.resolveType(sig.ret.type),
				syntax: sig.ret
			};
		} else {
			tret = {type: if (returnTypeOverride != null) returnTypeOverride else TTAny, syntax: null};
		}

		return {
			syntax: {
				openParen: sig.openParen,
				closeParen: sig.closeParen,
			},
			args: targs,
			ret: tret,
		};
	}

	function typeVars(kind:VarDeclKind, vars:Separated<VarDecl>, expectedType:TType):TExpr {
		var varToken = switch kind { case VVar(t) | VConst(t): t; };
		var overrideType = typerContext.haxeTypes.resolveTypeHint(HaxeTypeAnnotation.extract(varToken.leadTrivia), varToken.pos);

		switch expectedType {
			case TTAny: // for (var i)
			case TTVoid: // block-level vars
			case _: throw "assert"; // should NOT happen
		}

		var vars = separatedToArray(vars, function(v, comma) {
			var type = if (overrideType != null) overrideType else if (v.type == null) TTAny else typerContext.resolveType(v.type.type);
			var init = if (v.init != null) {equalsToken: v.init.equalsToken, expr: typeExpr(v.init.expr, type)} else null;
			var tvar = addLocal(v.name.text, type);
			return {
				syntax: v,
				v: tvar,
				init: init,
				comma: comma,
			};
		});
		return mk(TEVars(kind, vars), TTVoid, expectedType);
	}

	function typeIdent(i:Token, e:Expr, expectedType:TType):TExpr {
		var e = tryTypeIdent(i, expectedType);
		if (e == null) throwErr('Unknown ident: ${i.text}', i.pos);
		return e;
	}

	function tryTypeIdent(i:Token, expectedType:TType):Null<TExpr> {
		inline function getCurrentClass(subj) {
			var currentClass = typerContext.getCurrentClass();
			return if (currentClass != null) currentClass else throw '`$subj` used outside of class';
		}

		inline function getSuperClass() {
			return switch getCurrentClass("super").kind {
				case TClass(info):
					if (info.extend == null) throwErr("`super` used with no super-class", i.pos);
					info.extend.superClass;
				case _: throw "not a class";
			}
		}

		return switch i.text {
			case "this": mk(TELiteral(TLThis(i)), TTInst(getCurrentClass("this")), expectedType);
			case "super": mk(TELiteral(TLSuper(i)), TTInst(getSuperClass()), expectedType);
			case "true" | "false": mk(TELiteral(TLBool(i)), TTBoolean, expectedType);
			case "null": mk(TELiteral(TLNull(i)), TTAny, expectedType);
			case "undefined": mk(TELiteral(TLUndefined(i)), TTAny, expectedType);
			case "arguments": mk(TEBuiltin(i, "arguments"), TTBuiltin, expectedType);
			case "trace": mk(TEBuiltin(i, "trace"), TTFun([], TTVoid, TRestSwc), expectedType);
			case "int": mk(TEBuiltin(i, "int"), TTBuiltin, expectedType);
			case "uint": mk(TEBuiltin(i, "int"), TTBuiltin, expectedType);
			case "Boolean": mk(TEBuiltin(i, "Boolean"), TTBuiltin, expectedType);
			case "Number": mk(TEBuiltin(i, "Number"), TTBuiltin, expectedType);
			case "XML": mk(TEBuiltin(i, "XML"), TTBuiltin, expectedType);
			case "XMLList": mk(TEBuiltin(i, "XMLList"), TTBuiltin, expectedType);
			case "String": mk(TEBuiltin(i, "String"), TTBuiltin, expectedType);
			case "Array": mk(TEBuiltin(i, "Array"), TTBuiltin, expectedType);
			case "Function": mk(TEBuiltin(i, "Function"), TTBuiltin, expectedType);
			case "Class": mk(TEBuiltin(i, "Class"), TTBuiltin, expectedType);
			case "Object": mk(TEBuiltin(i, "Object"), TTBuiltin, expectedType);
			case "RegExp": mk(TEBuiltin(i, "RegExp"), TTBuiltin, expectedType);
			// TODO: actually these must be resolved after everything because they are global idents!!!
			case "parseInt":  mk(TEBuiltin(i, "parseInt"), TTFun([TTString, TTInt], TTInt), expectedType);
			case "parseFloat": mk(TEBuiltin(i, "parseFloat"), TTFun([TTString], TTNumber), expectedType);
			case "NaN": mk(TEBuiltin(i, "NaN"), TTNumber, expectedType);
			case "isNaN": mk(TEBuiltin(i, "isNaN"), TTFun([TTNumber], TTBoolean), expectedType);
			case "escape": mk(TEBuiltin(i, "escape"), TTFun([TTString], TTString), expectedType);
			case "unescape": mk(TEBuiltin(i, "unescape"), TTFun([TTString], TTString), expectedType);
			case ident:
				var v = locals[ident];

				if (v != null) {
					return mk(TELocal(i, v), v.type, expectedType);
				}

				var currentClass = typerContext.getCurrentClass();
				if (currentClass != null) {
					var currentClass:TClassOrInterfaceDecl = currentClass; // TODO: this is here only to please the null-safety checker

					if (ident == "hasOwnProperty") {
						// unqualified `hasOwnProperty` access inside a class
						var fieldObject:TFieldObject = {kind: TOImplicitThis(currentClass), type: TTInst(currentClass)};
						return mk(TEField(fieldObject, ident, i), TTFun([TTString], TTBoolean), expectedType);
					}

					if (ident == currentClass.name) {
						// class constructor is never resolved like that, so this is definitely a declaration reference
						return mkDeclRef({first: i, rest: []}, {name: currentClass.name, kind: TDClassOrInterface(currentClass)}, expectedType);
					}

					function loop(c:TClassOrInterfaceDecl):Null<TExpr> {
						if (ident == c.name) {
							return null;
						}

						var field = c.findField(ident, null);
						if (field != null) {
							// found a field
							var eobj:TFieldObject =
								if (isFieldStatic(field))
								{
									kind: TOImplicitClass(c),
									type: TTStatic(c)
								}
								else
								{
									kind: TOImplicitThis(currentClass),
									type: TTInst(currentClass)
								};
							var type = getFieldType(field);
							return mk(TEField(eobj, ident, i), type, expectedType);
						}
						switch c.kind {
							case TClass(info):
								if (info.extend != null) {
									var e = loop(info.extend.superClass);
									if (e != null) {
										return e;
									}
								}
							case TInterface(info):
								if (info.extend != null) {
									for (i in info.extend.interfaces) {
										var e = loop(i.iface.decl);
										if (e != null) {
											return e;
										}
									}
								}
						}
						return null;
					}
					var eField = loop(currentClass);
					if (eField != null) {
						return eField;
					}
				}

				var decl = try typerContext.resolveDotPath([i.text]) catch (_:Any) null;
				if (decl != null) {
					return mkDeclRef({first: i, rest: []}, decl, expectedType);
				}

				return null;
		}
	}

	function getFieldType(field:TClassField):TType {
		var t = switch field.kind {
			case TFVar(v): v.type;
			case TFFun(f): f.type;
			case TFGetter(a) | TFSetter(a): a.propertyType;
		};
		if (t == TTVoid) throw "assert";
		return t;
	}

	function typeField(eobj:Expr, dot:Token, name:Token, expectedType:TType):TExpr {
		switch exprToDotPath(eobj) {
			case null:
			case prefixDotPath:
				var e = tryTypeIdent(prefixDotPath.first, TTAny);
				if (e == null) @:nullSafety(Off) {
					// probably a fully-qualified type path then

					var acc = [{dot: null, token: prefixDotPath.first}];
					for (r in prefixDotPath.rest) acc.push({dot: r.sep, token: r.element});

					var declName = {dot: dot, token: name};
					var decl = null;
					var rest = [];
					while (acc.length > 0) {
						var packName = [for (t in acc) t.token.text].join(".");
						var pack = tree.getPackageOrNull(packName);
						if (pack != null) {
							var mod = pack.getModule(declName.token.text);
							decl = mod.pack.decl;
							break;
						} else {
							rest.push(declName);
							declName = acc.pop();
						}
					}

					if (decl == null) {
						throwErr("unknown declaration: " + dotPathToString(prefixDotPath), prefixDotPath.first.pos);
					}

					acc.push(declName);
					var dotPath = {
						first: acc[0].token,
						rest: [for (i in 1...acc.length) {sep: acc[i].dot, element: acc[i].token}]
					};

					var expr = mkDeclRef(dotPath, decl, if (rest.length == 0) expectedType else TTAny);

					while (rest.length > 0) {
						var f = rest.pop();
						expr = getTypedField(expr, f.dot, f.token, if (rest.length == 0) expectedType else TTAny);
					}

					return expr;
				}
		}

		// TODO: we don't need to re-type stuff,
		// can iterate over fields, but let's do it later :-)
		var eobj = typeExpr(eobj, TTAny);
		return getTypedField(eobj, dot, name, expectedType);
	}

	inline function mkExplicitFieldAccess(obj:TExpr, dot:Token, fieldToken:Token, type:TType, expectedType:TType):TExpr {
		return mk(TEField({kind: TOExplicit(dot, obj), type: obj.type}, fieldToken.text, fieldToken), type, expectedType);
	}

	function getTypedField(obj:TExpr, dot:Token, fieldToken:Token, expectedType:TType) {
		var fieldName = fieldToken.text;
		var type =
			switch [fieldName, skipParens(obj)] {
				case [_, {type: TTInt | TTUint | TTNumber}]: getNumericInstanceFieldType(fieldToken, obj.type);
				case ["toString", _]: TTFun([TTUint], TTString);
				case ["hasOwnProperty", {type: TTDictionary(keyType, _)}]: TTFun([keyType], TTBoolean);
				case ["hasOwnProperty", _]: TTFun([TTString], TTBoolean);
				case ["prototype", _]: tUntypedObject;

				// these two really should be processed in a filter, but oh well
				case ["NaN", {kind: TEBuiltin(t, "Number")}]:
					return mk(TEBuiltin(new Token(fieldToken.pos, TkIdent, "NaN", t.leadTrivia, fieldToken.trailTrivia), "NaN"), TTNumber, expectedType);

				case [_, {type: TTDictionary(tKey, tValue)}]:
					return mk(TEArrayAccess({
						syntax: {
							openBracket: new Token(dot.pos, TkBracketOpen, "[", dot.leadTrivia, dot.trailTrivia),
							closeBracket: new Token(dot.pos, TkBracketClose, "]", [], fieldToken.trailTrivia)
						},
						eobj: obj,
						eindex: mk(TELiteral(TLString(new Token(fieldToken.pos, TkStringDouble, '"$fieldName"', fieldToken.leadTrivia, []))), TTString, tKey)
					}), tValue, expectedType);

				case [_, {kind: TEBuiltin(_, "Array")}]: getArrayStaticFieldType(fieldToken);
				case [_, {kind: TEBuiltin(_, "Number")}]: getNumericStaticFieldType(fieldToken, TTNumber);
				case [_, {kind: TEBuiltin(_, "int")}]: getNumericStaticFieldType(fieldToken, TTInt);
				case [_, {kind: TEBuiltin(_, "uint")}]: getNumericStaticFieldType(fieldToken, TTUint);
				case [_, {kind: TEBuiltin(_, "String")}]: getStringStaticFieldType(fieldToken);
				case [_, {type: TTAny}]: TTAny; // untyped field access
				case [_, {type: TTObject(valueType)}]: valueType;

				case [_, {type: TTBuiltin | TTVoid | TTBoolean | TTClass}]: err('Attempting to get field on type ${obj.type.getName()}', fieldToken.pos); TTAny;
				case [_, {type: TTString}]: getStringInstanceFieldType(fieldToken);
				case [_, {type: TTArray(t)}]: getArrayInstanceFieldType(fieldToken, t);
				case [_, {type: TTVector(t)}]: getVectorInstanceFieldType(fieldToken, t);
				case [_, {type: TTFunction | TTFun(_)}]: getFunctionInstanceFieldType(fieldToken);
				case [_, {type: TTRegExp}]: getRegExpInstanceFieldType(fieldToken);
				case [_, {type: TTXML}]:
					return typeXMLFieldAccess(obj, dot, fieldToken, expectedType);
				case [_, {type: TTXMLList}]:
					return typeXMLListFieldAccess(obj, dot, fieldToken, expectedType);
				case [_, {type: TTInst(cls)}]: typeInstanceField(cls, fieldName, fieldToken.pos);
				case [_, {type: TTStatic(cls)}]: typeStaticField(cls, fieldName);
		}
		return mkExplicitFieldAccess(obj, dot, fieldToken, type, expectedType);
	}

	function typeStaticField(cls:TClassOrInterfaceDecl, fieldName:String):TType {
		var field = cls.findField(fieldName, true);
		if (field != null) {
			return getFieldType(field);
		}
		if (field != null) trace(field);
		throw 'Unknown static field $fieldName on class ${cls.name}';
	}

	function typeInstanceField(cls:TClassOrInterfaceDecl, fieldName:String, pos):TType {
		function loop(cls:TClassOrInterfaceDecl):Null<TClassField> {
			var field = cls.findField(fieldName, false);
			if (field != null) {
				return field;
			}
			// TODO: copy-paste from typeIdent, gotta refactor this after i'm done
			switch cls.kind {
				case TClass(info):
					if (info.extend != null) {
						var f = loop(info.extend.superClass);
						if (f != null) {
							return f;
						}
					}
				case TInterface(info):
					if (info.extend != null) {
						for (i in info.extend.interfaces) {
							var f = loop(i.iface.decl);
							if (f != null) {
								return f;
							}
						}
					}
			}
			return null;
		}

		var field = loop(cls);
		if (field != null) {
			return getFieldType(field);
		} else if (Lambda.exists(cls.modifiers, function(m) return m.equals(DMDynamic(null)))) {
			return TTAny;
		}

		return throwErr('Unknown instance field $fieldName on class ${cls.name}', pos);
	}

	function typeXMLFieldAccess(xml:TExpr, dot:Token, field:Token, expectedType:TType):TExpr {
		var fieldType = switch field.text {
			case "addNamespace": TTFun([tUntypedObject], TTXML);
			case "appendChild": TTFun([tUntypedObject], TTXML);
			case "attribute": TTFun([TTAny], TTXMLList);
			case "attributes": TTFun([], TTXMLList);
			case "child": TTFun([tUntypedObject], TTXMLList);
			case "childIndex": TTFun([], TTInt);
			case "children": TTFun([], TTXMLList);
			case "namespace": TTFun([], TTAny);
			case "comments": TTFun([], TTXMLList);
			case "contains": TTFun([TTXML], TTBoolean);
			case "name": TTFun([], TTString);
			case "localName": TTFun([], TTString);
			case "copy": TTFun([], TTXML);
			case "descendants": TTFun([tUntypedObject], TTXMLList);
			case "elements": TTFun([tUntypedObject], TTXMLList);
			case "length": TTFun([], TTInt);
			case "toXMLString": TTFun([], TTString);
			case _: null;
		}
		if (fieldType != null) {
			return mkExplicitFieldAccess(xml, dot, field, fieldType, expectedType);
		} else {
			// err('TODO XML instance field: ${field.text} assumed to be a child', field.pos);
			return mk(TEXmlChild({syntax: {dot: dot, name: field}, eobj: xml, name: field.text}), TTXMLList, expectedType);
		}
	}

	function typeXMLListFieldAccess(xml:TExpr, dot:Token, field:Token, expectedType:TType):TExpr {
		var fieldType = switch field.text {
			case "attribute": TTFun([], TTString);
			case "length": TTFun([], TTInt);
			case "toXMLString": TTFun([], TTString);
			case _: null;
		}
		if (fieldType != null) {
			return mkExplicitFieldAccess(xml, dot, field, fieldType, expectedType);
		} else {
			// err('TODO XMLList instance field: ${field.text} assumed to be a child', field.pos);
			return mk(TEXmlChild({syntax: {dot: dot, name: field}, eobj: xml, name: field.text}), TTXMLList, expectedType);
		}
	}

	function getFunctionInstanceFieldType(field:Token):TType {
		return switch field.text {
			case "call" | "apply": TTFunction;
			case "length": TTUint;
			case other: err('Unknown Function instance field: $other', field.pos); TTAny;
		}
	}

	function getRegExpInstanceFieldType(field:Token):TType {
		return switch field.text {
			case "test": TTFun([TTString], TTBoolean);
			case "exec": TTFun([TTString], tUntypedObject);
			case "lastIndex": TTInt;
			case other: err('Unknown RegExp instance field: $other', field.pos); TTAny;
		}
	}

	function getStringStaticFieldType(field:Token):TType {
		return switch field.text {
			case "fromCharCode": TTFun([TTInt], TTString);
			case other: err('Unknown static String field: $other', field.pos); TTAny;
		}
	}

	function getArrayStaticFieldType(field:Token):TType {
		return switch field.text {
			case "NUMERIC": TTUint;
			case "DESCENDING": TTUint;
			case "CASEINSENSITIVE": TTUint;
			case "UNIQUESORT": TTUint;
			case "RETURNINDEXEDARRAY": TTUint;
			case other: err('Unknown Array static field $other', field.pos); TTAny;
		}
	}

	function getArrayInstanceFieldType(field:Token, t:TType):TType {
		return switch field.text {
			case "length": TTInt; // it's `uint` in Flash, but Haxe defines it as `Int`
			case "join": TTFun([TTAny], TTString);
			case "push" | "unshift": TTFun([t], TTUint, TRestSwc);
			case "pop" | "shift": TTFun([], t);
			case "insertAt": TTFun([TTInt, t], TTVoid);
			case "concat": TTFun([TTArray(t)], TTArray(t));
			case "indexOf" | "lastIndexOf": TTFun([t, TTInt], TTInt);
			case "slice": TTFun([TTInt, TTInt], TTArray(t));
			case "splice": TTFun([TTInt, TTUint, TTAny], TTArray(t));
			case "removeAt": TTFun([TTInt], t);
			case "sort": TTFun([TTAny], TTArray(t));
			case "sortOn": TTFun([TTString, tUntypedObject], TTArray(t));
			case "filter": TTFun([TTFun([t], TTBoolean)], TTArray(t)); // in as3 the `fitler` signature is actually 3-argument, but not in Haxe
			case other: err('Unknown Array instance field $other', field.pos); TTAny;
		}
	}

	function getVectorInstanceFieldType(field:Token, t:TType):TType {
		return switch field.text {
			case "length": TTInt; // it's `uint` in Flash, but Haxe defines it as `Int`
			case "push" | "unshift": TTFun([t], TTUint, TRestSwc);
			case "pop" | "shift": TTFun([], t);
			case "insertAt": TTFun([TTInt, t], TTVoid);
			case "indexOf" | "lastIndexOf": TTFun([t, TTInt], TTInt);
			case "splice": TTFun([TTInt, TTUint, t], TTVector(t));
			case "slice": TTFun([TTInt, TTInt], TTVector(t));
			case "join": TTFun([TTString], TTString);
			case "sort": TTFun([TTAny], TTVector(t));
			case "concat": TTFun([TTVector(t)], TTVector(t));
			case "reverse": TTFun([], TTVector(t));
			case "forEach": TTFun([TTFunction, tUntypedObject], TTVoid);
			case "fixed": TTBoolean;
			case "removeAt": TTFun([TTInt], t);
			case "filter": TTFun([TTFun([t, TTUint, TTVector(t)], TTBoolean), TTObject(TTAny)], TTVector(t));
			case other: err('Unknown Vector instance field $other', field.pos); TTAny;
		}
	}

	function getStringInstanceFieldType(field:Token):TType {
		return switch field.text {
			case "length": TTInt;
			case "substr" | "substring" | "slice": TTFun([TTInt, TTInt], TTString);
			case "toLowerCase" | "toUpperCase" | "toLocaleLowerCase" | "toLocaleUpperCase": TTFun([], TTString);
			case "indexOf" | "lastIndexOf": TTFun([TTString, TTInt], TTInt);
			case "split": TTFun([TTAny, TTInt], TTArray(TTString));
			case "charAt": TTFun([TTInt], TTString);
			case "charCodeAt": TTFun([TTInt], TTInt);
			case "concat": TTFun([], TTString, TRestSwc);
			case "search": TTFun([TTAny], TTInt);
			case "replace": TTFun([TTAny, tUntypedObject], TTString);
			case "match": TTFun([TTAny], TTArray(TTString));
			case "localeCompare": TTFun([TTString], TTInt);
			case other: err('Unknown String instance field $other', field.pos); TTAny;
		}
	}

	function getNumericInstanceFieldType(field:Token, type:TType):TType {
		return switch field.text {
			case "toString": TTFun([TTUint], TTString);
			case "toFixed": TTFun([TTUint], TTString);
			case "toPrecision": TTFun([TTUint], TTString);
			case other: err('Unknown field $other on type ${type.getName()}', field.pos); TTAny;
		}
	}

	function getNumericStaticFieldType(field:Token, type:TType):TType {
		return switch field.text {
			case "MIN_VALUE": type;
			case "MAX_VALUE": type;
			case "POSITIVE_INFINITY": type;
			case "NEGATIVE_INFINITY": type;
			case other: err('Unknown field $other on type ${type.getName()}', field.pos); TTAny;
		}
	}

	function typeCall(e:Expr, args:CallArgs, expectedType:TType) {
		var eobj = typeExpr(e, TTAny);

		var callableType = switch eobj {
			case {kind: TELiteral(TLSuper(_)), type: TTInst(cls)}: getConstructorType(cls);
			case _: eobj.type;
		}

		var targs = typeCallArgs(args, callableType, e);

		inline function mkCast(path, t) return {
			var e = switch targs.args {
				case [{expr: e, comma: null}]: e;
				case _: throw "assert"; // should NOT happen
			};
			return mk(TECast({
				syntax: {openParen: args.openParen, closeParen: args.closeParen, path: path},
				type: t,
				expr: e
			}), t, expectedType);
		}

		inline function mkDotPath(ident:Token):DotPath return {first: ident, rest: []};

		var type;
		switch skipParens(eobj) {
			case {kind: TELiteral(TLSuper(_))}: // super(...) call
				type = TTVoid;

			case {type: TTAny}: // bad untyped call :-)
				// err("Untyped call", args.openParen.pos);
				type = TTAny;

			case {type: TTFunction}: // also untyped call, but inevitable
				type = TTAny;

			// a hack for our robotlegs that support type parms instead of Dynamic
			// TODO: make this enableable via config instead of being hard-coded
			case {kind: TEField({type: TTInst({name: "IInjector", parentModule: {parentPack: {name: "org.robotlegs.core"}}})}, "instantiate" | "getInstance", _)} if (context.config.settings != null && context.config.settings.haxeRobotlegs):
				type = switch targs.args[0].expr.type {
					case TTStatic(cls): TTInst(cls);
					case TTClass: TTAny;
					case _: throwErr("unknown type passed to the injector", targs.openParen.pos);
				};

			case {type: TTFun(_, ret)}: // known function type call
				type = ret;

			case {kind: TEBuiltin(syntax, "XML")}:
				type = TTXML;

			case {kind: TEBuiltin(syntax, "int")}:
				return mkCast(mkDotPath(syntax), TTInt);

			case {kind: TEBuiltin(syntax, "uint")}:
				return mkCast(mkDotPath(syntax), TTUint);

			case {kind: TEBuiltin(syntax, "Boolean")}:
				return mkCast(mkDotPath(syntax), TTBoolean);

			case {kind: TEBuiltin(syntax, "String")}:
				return mkCast(mkDotPath(syntax), TTString);

			case {kind: TEBuiltin(syntax, "Number")}:
				return mkCast(mkDotPath(syntax), TTNumber);

			case {kind: TEBuiltin(syntax, "Object")}:
				return mkCast(mkDotPath(syntax), TTObject(TTAny));

			case {kind: TEDeclRef(path, _), type: TTStatic(cls)}: // ClassName(expr) cast
				return mkCast(path, TTInst(cls));

			case {kind: TEXmlChild(child)} if (child.name == "hasSimpleContent"):
				type = TTBoolean;

			case {kind: TEXmlChild(child)} if (child.name == "children"):
				type = TTXMLList;

			case {kind: TEXmlChild(child)} if (child.name == "child"):
				type = TTXMLList;

			case {kind: TEXmlChild(child)} if (child.name == "appendChild"):
				type = TTVoid;

			case {kind: TEXmlChild(child)} if (child.name == "namespace"):
				type = TTAny;

			case v:
				err("unknown callable type: " + eobj.type, exprPos(e));
				type = TTAny;
		}

		return mk(TECall(eobj, targs), type, expectedType);
	}

	function typeLiteral(l:Literal, expectedType:TType):TExpr {
		return switch (l) {
			case LString(t): mk(TELiteral(TLString(t)), TTString, expectedType);
			case LDecInt(t) | LHexInt(t): mk(TELiteral(TLInt(t)), TTInt, expectedType);
			case LFloat(t): mk(TELiteral(TLNumber(t)), TTNumber, expectedType);
			case LRegExp(t): mk(TELiteral(TLRegExp(t)), TTRegExp, expectedType);
		}
	}

	function typeObjectDecl(openBrace:Token, fields:Separated<ObjectField>, closeBrace:Token, expectedType:TType):TExpr {
		var fields = separatedToArray(fields, function(f, comma) {
			var fieldName = switch f.nameKind {
				case FNIdent | FNInteger: f.name.text;
				case FNStringSingle | FNStringDouble: f.name.text.substring(1, f.name.text.length - 1);
			}
			return {
				syntax: {name: f.name, nameKind: f.nameKind, colon: f.colon, comma: comma},
				name: fieldName,
				expr: typeExpr(f.value, TTAny)
			};
		});
		return mk(TEObjectDecl({
			syntax: {openBrace: openBrace, closeBrace: closeBrace},
			fields: fields
		}), tUntypedObject, expectedType);
	}

	function getConstructorType(cls:TClassOrInterfaceDecl):TType {
		var ctor = getConstructor(cls);
		return if (ctor != null) ctor.type else TTFun([], TTVoid, null);
	}

	function typeNew(keyword:Token, e:Expr, args:Null<CallArgs>, expectedType:TType):TExpr {
		var e = typeExpr(e, TTAny);

		var obj, type, ctorType;
		switch e.kind {
			case TEDeclRef(path, {kind: TDClassOrInterface({name: "Dictionary"})}):
				type = switch expectedType { case TTDictionary(_): expectedType; case _: tUntypedDictionary; };
				ctorType = TTFun([TTBoolean], TTVoid);
				obj = TNType({
					type: type,
					syntax: TPath(path)
				});
			case TEDeclRef(path, {kind: TDClassOrInterface(cls)}):
				type = TTInst(cls);
				ctorType = getConstructorType(cls);
				obj = TNType({
					type: type,
					syntax: TPath(path)
				});
			case TEVector(syntax, elemType):
				type = switch expectedType { case TTVector(_): expectedType; case _: TTVector(elemType); };
				ctorType = TTFun([TTUint, TTBoolean], TTVoid);
				obj = TNType({
					type: type,
					syntax: TVector(syntax)
				});
			case TEBuiltin(syntax, "Array"):
				type = switch expectedType { case TTArray(_): expectedType; case _: tUntypedArray; };
				ctorType = TTFunction;
				obj = TNType({
					type: type,
					syntax: TPath({first: syntax, rest: []})
				});
			case TEBuiltin(syntax, "RegExp"):
				type = TTRegExp;
				ctorType = TTFun([TTString, TTString], TTVoid);
				obj = TNType({
					type: type,
					syntax: TPath({first: syntax, rest: []})
				});
			case TEBuiltin(syntax, "XML"):
				type = TTXML;
				ctorType = TTFun([TTString], TTVoid);
				obj = TNType({
					type: type,
					syntax: TPath({first: syntax, rest: []})
				});
			case TEBuiltin(syntax, "Object"):
				type = tUntypedObject;
				ctorType = TTFun([], TTVoid);
				obj = TNType({
					type: type,
					syntax: TPath({first: syntax, rest: []})
				});
			case TEBuiltin(_, _):
				return throwErr("Unprocessed `new builtin`", keyword.pos);
			case _:
				obj = TNExpr(e);
				switch (e.type) {
					case TTStatic(cls):
						type = TTInst(cls);
						ctorType = if (cls.kind.match(TInterface(_))) TTFunction else getConstructorType(cls);
					case _:
						type = tUntypedObject;
						ctorType = TTFunction;
				}
		}

		var args = if (args != null) typeCallArgs(args, ctorType) else null;
		return mk(TENew(keyword, obj, args), type, expectedType);
	}

	function typeCallArgs(args:CallArgs, callableType:TType, ?e: Expr):TCallArgs {
		var getExpectedType = switch (callableType) {
			case TTXMLList if (e != null):
				switch e {
					case EField(_, _, ident) if (ident.kind.equals(TkIdent) && ident.text == "hasSimpleContent"):
						(i,earg) -> TTBoolean;
					case EField(_, _, ident) if (ident.kind.equals(TkIdent) && ident.text == "children"):
						(i,earg) -> TTFun([], TTXMLList);
					case EField(_, _, ident) if (ident.kind.equals(TkIdent) && ident.text == "child"):
						(i,earg) -> TTFun([TTString], TTXMLList);
					case EField(_, _, ident) if (ident.kind.equals(TkIdent) && ident.text == "appendChild"):
						(i,earg) -> TTFun([TTXML], TTVoid);
					case EField(_, _, ident) if (ident.kind.equals(TkIdent) && ident.text == "namespace"):
						(i,earg) -> TTFun([], TTAny);
					case _:
						throwErr("Trying to call an expression of type " + callableType.getName(), args.openParen.pos);
				}
			case TTVoid | TTBoolean | TTNumber | TTInt | TTUint | TTString | TTArray(_) | TTObject(_) | TTXML | TTXMLList | TTRegExp | TTVector(_) | TTInst(_) | TTDictionary(_):
				throwErr("Trying to call an expression of type " + callableType.getName(), args.openParen.pos);
			case TTClass:
				throwErr("assert?? " + callableType.getName(), args.openParen.pos);
			case TTAny | TTFunction:
				(i,earg) -> TTAny;
			case TTBuiltin | TTStatic(_):
				(i,earg) -> TTAny; // TODO: casts should be handled elsewhere
			case TTFun(args, _, rest):
				function(i:Int, earg:Expr):TType {
					if (i >= args.length) {
						if (rest == null) {
							err("Invalid number of arguments", exprPos(earg));
						}
						return TTAny;
					} else {
						return args[i];
					}
				}
		}

		return {
			openParen: args.openParen,
			closeParen: args.closeParen,
			args:
				if (args.args != null) {
					var i = 0;
					separatedToArray(args.args, function(expr, comma) {
						var expectedType = getExpectedType(i, expr);
						i++;
						return {expr: typeExpr(expr, expectedType), comma: comma};
					});
				} else
					[]
		};
	}

	function typeVector(v:VectorSyntax, expectedType:TType):TExpr {
		var type = typerContext.resolveType(v.t.type);
		return mk(TEVector(v, type), TTFun([tUntypedObject], TTVector(type)), expectedType);
	}

	function typeBinop(a:Expr, op:Binop, b:Expr, expectedType:TType):TExpr {
		switch (op) {
			case OpAnd(_) | OpOr(_):
				var a = typeExpr(a, expectedType);
				var b = typeExpr(b, expectedType);
				var type = if (typeEq(a.type, b.type)) a.type else TTAny;
				// these two must be further processed to be Haxe-friendly
				return mk(TEBinop(a, op, b), type, expectedType);

			case OpEquals(_) | OpNotEquals(_) | OpStrictEquals(_) | OpNotStrictEquals(_) |
			     OpGt(_) | OpGte(_) | OpLt(_) | OpLte(_) |
			     OpIn(_) | OpIs(_):
				// relation operators are always boolean
				var a = typeExpr(a, TTAny); // not only numbers, but also strings
				var b = typeExpr(b, TTAny);
				return mk(TEBinop(a, op, b), TTBoolean, expectedType);

			case OpAssign(_) | OpAssignOp(_): // TODO: handle expected types for OpAssignOp
				var a = typeExpr(a, TTAny);

				var bExpectedType = if (a.type == TTString && op.match(OpAssignOp(AOpAdd(_)))) TTAny else a.type; // we can += anything to a string
				var b = typeExpr(b, bExpectedType);

				return mk(TEBinop(a, op, b), a.type, expectedType);

			case OpShl(_) | OpShr(_) | OpUshr(_) | OpBitAnd(_) | OpBitOr(_) | OpBitXor(_):
				var a = typeExpr(a, TTInt);
				var b = typeExpr(b, TTInt);
				return mk(TEBinop(a, op, b), TTInt, expectedType);

			case OpAdd(plus):
				var a = typeExpr(a, TTAny);
				var b = typeExpr(b, TTAny);

				var type = switch [a.type, b.type] {
					case [TTString, _] | [_, TTString]: TTString; // string concat
					case [TTNumber, (TTNumber | TTInt | TTUint)] | [(TTInt | TTUint), TTNumber]: TTNumber; // always number
					case [TTInt, TTUint] | [TTUint, (TTInt | TTUint)]: TTUint; // always uint
					case [TTInt, TTInt]: TTInt; // int addition
					case [TTAny, _] | [_, TTAny]:
						err("Dynamic + operation!", plus.pos);
						TTAny;
					case _:
						throwErr("Unsupported + operation", plus.pos);
				};

				return mk(TEBinop(a, op, b), type, expectedType);

			case OpMul(token) | OpSub(token) | OpMod(token):
				var a = typeExpr(a, TTNumber);
				var b = typeExpr(b, TTNumber);

				var type = switch [a.type, b.type] {
					case [TTNumber, (TTNumber | TTInt | TTUint)] | [(TTInt | TTUint), TTNumber]: TTNumber; // always number
					case [TTInt, TTUint] | [TTUint, (TTInt | TTUint)]: TTUint; // always uint
					case [TTInt, TTInt]: TTInt;
					case [TTAny, _] | [_, TTAny]:
						err("Dynamic arithmetic operation!", token.pos);
						TTAny;
					case _:
						throwErr("Unsupported arithmetic operation", token.pos);
				};

				return mk(TEBinop(a, op, b), type, expectedType);

			case OpDiv(_):
				var a = typeExpr(a, TTNumber);
				var b = typeExpr(b, TTNumber);
				return mk(TEBinop(a, op, b), TTNumber, expectedType);

			case OpComma(_):
				var a = typeExpr(a, TTAny);
				var b = typeExpr(b, TTAny);
				return mk(TEBinop(a, op, b), b.type, expectedType);
		}
	}

	function typeTry(keyword:Token, block:BracedExprBlock, catches:Array<Catch>, finally_:Null<Finally>, expectedType:TType):TExpr {
		if (expectedType != TTVoid) throw "assert";

		if (finally_ != null) throwErr("finally is unsupported", finally_.keyword.pos);
		var body = typeExpr(EBlock(block), TTVoid);
		var tCatches = new Array<TCatch>();
		for (c in catches) {
			pushLocals();
			var v = addLocal(c.name.text, typerContext.resolveType(c.type.type));
			var e = typeExpr(EBlock(c.block), TTVoid);
			popLocals();
			tCatches.push({
				syntax: {
					keyword: c.keyword,
					openParen: c.openParen,
					name: c.name,
					type: c.type,
					closeParen: c.closeParen
				},
				v: v,
				expr: e
			});
		}
		return mk(TETry({
			keyword: keyword,
			expr: body,
			catches: tCatches
		}), TTVoid, TTVoid);
	}

	function typeSwitch(keyword:Token, openParen:Token, subj:Expr, closeParen:Token, openBrace:Token, cases:Array<SwitchCase>, closeBrace:Token, expectedType:TType):TExpr {
		if (expectedType != TTVoid) throw "assert";

		var subj = typeExpr(subj, TTAny);
		var tcases = new Array<TSwitchCase>();
		var def:Null<TSwitchDefault> = null;
		for (c in cases) {
			switch (c) {
				case CCase(keyword, v, colon, body):
					if (def != null) throwErr("`case` after `default` in switch", keyword.pos);
					tcases.push({
						syntax: {
							keyword: keyword,
							colon: colon,
						},
						values: [typeExpr(v, TTAny)],
						body: [for (e in body) {expr: typeExpr(e.expr, TTVoid), semicolon: e.semicolon}]
					});
				case CDefault(keyword, colon, body):
					if (def != null) throw "double `default` in switch";
					def = {
						syntax: {
							keyword: keyword,
							colon: colon,
						},
						body: [for (e in body) {expr: typeExpr(e.expr, TTVoid), semicolon: e.semicolon}]
					};
			}
		}
		return mk(TESwitch({
			syntax: {
				keyword: keyword,
				openParen: openParen,
				closeParen: closeParen,
				openBrace: openBrace,
				closeBrace: closeBrace
			},
			subj: subj,
			cases: tcases,
			def: def
		}), TTVoid, TTVoid);
	}

	function typeAs(e:Expr, keyword:Token, t:SyntaxType, expectedType:TType) {
		var e = typeExpr(e, TTAny);
		var type = typerContext.resolveType(t);
		return mk(TEAs(e, keyword, {syntax: t, type: type}), type, expectedType);
	}

	function migrateForInVarHaxeTypeAnnotation(forKeyword:Token, forIter:ForIter) {
		// this is a bit hacky: transfer the type annotation trivia from `for` keyword
		// to the `var` keyword inside it so it can be picked up by `typeVars`
		switch (forIter.eit) {
			case EVars(VVar(t) | VConst(t), _):
				HaxeTypeAnnotation.extractTrivia(forKeyword.leadTrivia, (tr, comment) -> t.leadTrivia.push(tr));
			case _:
		}
	}

	function typeForIn(f:ForIn, expectedType:TType):TExpr {
		if (expectedType != TTVoid) throw "assert";

		migrateForInVarHaxeTypeAnnotation(f.forKeyword, f.iter);

		pushLocals();
		var eobj = typeExpr(f.iter.eobj, TTAny);
		var eit = typeExpr(f.iter.eit, TTAny);
		var ebody = typeExpr(f.body, TTVoid);
		popLocals();
		return mk(TEForIn({
			syntax: {
				forKeyword: f.forKeyword,
				openParen: f.openParen,
				closeParen: f.closeParen
			},
			iter: {
				eit: eit,
				inKeyword: f.iter.inKeyword,
				eobj: eobj
			},
			body: ebody
		}), TTVoid, TTVoid);
	}

	function typeForEach(f:ForEach, expectedType:TType):TExpr {
		if (expectedType != TTVoid) throw "assert";

		migrateForInVarHaxeTypeAnnotation(f.forKeyword, f.iter);

		pushLocals();
		var eobj = typeExpr(f.iter.eobj, TTAny);
		var eit = typeExpr(f.iter.eit, TTAny);
		var ebody = typeExpr(f.body, TTVoid);
		popLocals();
		return mk(TEForEach({
			syntax: {
				forKeyword: f.forKeyword,
				eachKeyword: f.eachKeyword,
				openParen: f.openParen,
				closeParen: f.closeParen
			},
			iter: {
				eit: eit,
				inKeyword: f.iter.inKeyword,
				eobj: eobj
			},
			body: ebody
		}), TTVoid, TTVoid);
	}

	function typeFor(f:For, expectedType:TType):TExpr {
		if (expectedType != TTVoid) throw "assert";

		pushLocals();
		var einit = if (f.einit != null) typeExpr(f.einit, TTVoid) else null;
		var econd = if (f.econd != null) typeExpr(f.econd, TTBoolean) else null;
		var eincr = if (f.eincr != null) typeExpr(f.eincr, TTVoid) else null;
		var ebody = typeExpr(f.body, TTVoid);
		popLocals();
		return mk(TEFor({
			syntax: {
				keyword: f.keyword,
				openParen: f.openParen,
				initSep: f.initSep,
				condSep: f.condSep,
				closeParen: f.closeParen
			},
			einit: einit,
			econd: econd,
			eincr: eincr,
			body: ebody
		}), TTVoid, TTVoid);
	}

	function typeWhile(w:While, expectedType:TType):TExpr {
		if (expectedType != TTVoid) throw "assert";

		var econd = typeExpr(w.cond, TTBoolean);
		var ebody = typeExpr(w.body, TTVoid);
		return mk(TEWhile({
			syntax: {keyword: w.keyword, openParen: w.openParen, closeParen: w.closeParen},
			cond: econd,
			body: ebody
		}), TTVoid, TTVoid);
	}

	function typeDoWhile(w:DoWhile, expectedType:TType):TExpr {
		if (expectedType != TTVoid) throw "assert";

		var ebody = typeExpr(w.body, TTVoid);
		var econd = typeExpr(w.cond, TTBoolean);
		return mk(TEDoWhile({
			syntax: {doKeyword: w.doKeyword, whileKeyword: w.whileKeyword, openParen: w.openParen, closeParen: w.closeParen},
			body: ebody,
			cond: econd
		}), TTVoid, TTVoid);
	}

	function typeIf(
		keyword:Token,
		openParen:Token,
		econd:Expr,
		closeParen:Token,
		ethen:Expr,
		eelse:Null<{keyword:Token, expr:Expr, semiliconBefore: Bool}>,
		expectedType:TType
	):TExpr {
		if (expectedType != TTVoid) throw "assert";
		var econd = typeExpr(econd, TTBoolean);
		var ethen = typeExpr(ethen, TTVoid);
		var eelse = if (eelse != null) {
			keyword: eelse.keyword,
			expr: typeExpr(eelse.expr, TTVoid),
			semiliconBefore: eelse.semiliconBefore
		} else null;
		return mk(TEIf({
			syntax: {keyword: keyword, openParen: openParen, closeParen: closeParen},
			econd: econd,
			ethen: ethen,
			eelse: eelse
		}), TTVoid, TTVoid);
	}

	function typeTernary(econd:Expr, question:Token, ethen:Expr, colon:Token, eelse:Expr, expectedType:TType):TExpr {
		var econd = typeExpr(econd, TTBoolean);
		var ethen = typeExpr(ethen, expectedType);
		var eelse = typeExpr(eelse, expectedType);
		var resultType =
			switch [ethen.type, eelse.type] {
				case [TTInt | TTUint, TTNumber] | [TTNumber, TTInt | TTUint]: TTNumber;
				case _ if (typeEq(ethen.type, eelse.type)): ethen.type;
				case _: TTAny; // TODO: warn here?
			}
		return mk(TETernary({
			syntax: {question: question, colon: colon},
			econd: econd,
			ethen: ethen,
			eelse: eelse
		}), resultType, expectedType);
	}

	function typeArrayAccess(e:Expr, openBracket:Token, eindex:Expr, closeBracket:Token, expectedType:TType):TExpr {
		var e = typeExpr(e, TTAny);
		var type, expectedKeyType;
		switch (e.type) {
			case TTVector(t):
				type = t;
				expectedKeyType = TTInt;
			case TTArray(t):
				type = t;
				expectedKeyType = TTInt;
			case TTObject(t):
				type = t;
				expectedKeyType = TTString;
			case TTDictionary(k, v):
				type = v;
				expectedKeyType = k;
			case _:
				// err("Untyped array access", openBracket.pos);
				type = TTAny;
				expectedKeyType = TTAny;
		};
		var eindex = typeExpr(eindex, expectedKeyType);
		return mk(TEArrayAccess({
			syntax: {openBracket: openBracket, closeBracket: closeBracket},
			eobj: e,
			eindex: eindex
		}), type, expectedType);
	}

	function typeArrayDeclElements(d:ArrayDecl, elemExpectedType:TType) {
		var allElementsConformToExpectedType = true;
		var elems = if (d.elems == null) [] else separatedToArray(d.elems, function(e, comma) {
			var e = typeExpr(e, elemExpectedType);
			if (elemExpectedType != TTAny && !typeEq(e.type, elemExpectedType)) { // TODO: this should do proper "unification" and allow subtypes when expecting a base type
				allElementsConformToExpectedType = false;
			}
			return {expr: e, comma: comma};
		});
		return {
			allElementsConformToExpectedType: allElementsConformToExpectedType,
			decl: {
				syntax: {openBracket: d.openBracket, closeBracket: d.closeBracket},
				elements: elems
			}
		};
	}

	function typeArrayDecl(d:ArrayDecl, expectedType:TType):TExpr {
		var elemExpectedType = switch expectedType {
			case TTArray(t): t;
			case _: TTAny;
		};
		var elements = typeArrayDeclElements(d, elemExpectedType);
		var arrayType = if (elements.allElementsConformToExpectedType) TTArray(elemExpectedType) else tUntypedArray;
		return mk(TEArrayDecl(elements.decl), arrayType, expectedType);
	}

	function typeVectorDecl(newKeyword:Token, t:TypeParam, d:ArrayDecl, expectedType:TType):TExpr {
		var type = typerContext.resolveType(t.type);
		var elems = typeArrayDeclElements(d, type);
		return mk(TEVectorDecl({
			syntax: {newKeyword: newKeyword, typeParam: t},
			elements: elems.decl,
			type: type
		}), TTVector(type), expectedType);
	}

	function typePreUnop(op:PreUnop, e:Expr, expectedType:TType):TExpr {
		var inType, outType;
		switch (op) {
			case PreNot(_): inType = outType = TTBoolean;
			case PreNeg(_): inType = outType = TTNumber;
			case PreIncr(_): inType = outType = TTNumber;
			case PreDecr(_): inType = outType = TTNumber;
			case PreBitNeg(_): inType = TTNumber; outType = TTInt;
		}
		var e = typeExpr(e, inType);
		if (outType == TTNumber && e.type.match(TTInt | TTUint)) {
			outType = e.type;
		}
		return mk(TEPreUnop(op, e), outType, expectedType);
	}

	function typePostUnop(e:Expr, op:PostUnop, expectedType:TType):TExpr {
		var e = typeExpr(e, TTNumber);
		var type = switch (op) {
			case PostIncr(_): e.type;
			case PostDecr(_): e.type;
		}
		return mk(TEPostUnop(e, op), type, expectedType);
	}

	function typeXmlAttr(e:Expr, dot:Token, at:Token, attrName:Token, expectedType:TType):TExpr {
		var e = typeExpr(e, TTAny);
		return mk(TEXmlAttr({
			syntax: {
				dot: dot,
				at: at,
				name: attrName
			},
			eobj: e,
			name: attrName.text
		}), TTXMLList, expectedType);
	}

	function typeXmlAttrExpr(e:Expr, dot:Token, at:Token, openBracket:Token, eattr:Expr, closeBracket:Token, expectedType:TType):TExpr {
		var e = typeExpr(e, TTAny);
		var eattr = typeExpr(eattr, TTString);
		return mk(TEXmlAttrExpr({
			syntax: {
				dot: dot,
				at: at,
				openBracket: openBracket,
				closeBracket: closeBracket
			},
			eobj: e,
			eattr: eattr,
		}), TTXMLList, expectedType);
	}

	function typeXmlDescend(e:Expr, dotDot:Token, childName:Token, expectedType:TType):TExpr {
		var e = typeExpr(e, TTAny);
		return mk(TEXmlDescend({
			syntax: {dotDot: dotDot, name: childName},
			eobj: e,
			name: childName.text
		}), TTXMLList, expectedType);
	}

	function typeCondCompBlock(v:CondCompVar, block:BracedExprBlock, expectedType:TType):TExpr {
		if (expectedType != TTVoid) throw "assert";

		var expr = typeExpr(EBlock(block), TTVoid);
		return mk(TECondCompBlock(typeCondCompVar(v), expr), TTVoid, TTVoid);
	}

	public static inline function typeCondCompVar(v:CondCompVar):TCondCompVar {
		return {syntax: v, ns: v.ns.text, name: v.name.text};
	}
}
