package ax3;

import ax3.ParseTree;
import ax3.ParseTree.*;
import ax3.Structure;
import ax3.TypedTree;

typedef Locals = Map<String, TVar>;

@:nullSafety
class Typer {
	final structure:Structure;

	@:nullSafety(Off) var locals:Locals;
	@:nullSafety(Off) var localsStack:Array<Locals>;

	public function new(structure) {
		this.structure = structure;
	}

	function initLocals() {
		locals = new Map();
		localsStack = [locals];
	}

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

	@:nullSafety(Off) var currentModule:SModule;
	var currentClass:Null<SClassDecl>;

	public function process(files:Array<File>):Array<TModule> {
		var modules = new Array<TModule>();

		for (file in files) {

			var pack = getPackageDecl(file);

			var mainDecl = getPackageMainDecl(pack);

			var privateDecls = getPrivateDecls(file);

			var imports = getImports(file);

			// TODO: just skipping conditional-compiled ones for now
			if (mainDecl == null || mainDecl.match(DNamespace(_))) continue;

			var packName = if (pack.name == null) "" else dotPathToString(pack.name);
			var currentPackage = structure.packages[packName];
			if (currentPackage == null) throw "assert";

			var mod = currentPackage.getModule(file.name);
			if (mod == null) throw "assert";
			currentModule = mod;

			var decl:Null<TDecl> = null;
			switch (mainDecl) {
				case DPackage(p):
				case DImport(i):
				case DClass(c):
					switch currentModule.getMainClass(c.name.text) {
						case null: throw "assert";
						case cls: currentClass = cls;
					}
					decl = TDClass(typeClass(c));
					currentClass = null;
				case DInterface(i):
				case DFunction(f):
				case DVar(v):
				case DNamespace(ns):
				case DUseNamespace(n, semicolon):
				case DCondComp(v, openBrace, decls, closeBrace):
			}

			if (decl != null) // TODO
			modules.push({
				name: file.name,
				pack: {
					name: packName,
					decl: (decl : TDecl), // TODO: null-safety is not perfect
					syntax: pack
				},
				eof: file.eof
			});

		}

		return modules;
	}

	function typeType(t:SType):TType {
		return switch (t) {
			case STVoid: TTVoid;
			case STAny: TTAny;
			case STBoolean: TTBoolean;
			case STNumber: TTNumber;
			case STInt: TTInt;
			case STUint: TTUint;
			case STString: TTString;
			case STArray: TTArray;
			case STFunction: TTFunction;
			case STClass: TTClass;
			case STObject: TTObject;
			case STXML: TTXML;
			case STXMLList: TTXMLList;
			case STRegExp: TTRegExp;
			case STVector(t): TTVector(typeType(t));
			case STPath(path): TTInst(structure.getClass(path));
			case STUnresolved(path):  throw "Unresolved type " + path;
		}
	}

	function resolveType(t:SyntaxType):TType {
		return typeType(structure.buildTypeStructure(t, currentModule));
	}

	inline function mk(e:TExprKind, t:TType):TExpr return {kind: e, type: t};

	function typeClass(c:ClassDecl):TClassDecl {
		trace("cls", c.name.text);

		var members = [];
		for (m in c.members) {
			switch (m) {
				case MCondComp(v, openBrace, members, closeBrace):
				case MUseNamespace(n, semicolon):
				case MField(f):
					members.push(TMField(typeClassField(f)));
				case MStaticInit(block):
			}
		}

		return {
			syntax: c,
			name: c.name.text,
			modifiers: c.modifiers,
			members: members
		}
	}

	function typeClassField(f:ClassField):TClassField {
		var kind = switch (f.kind) {
			case FVar(kind, vars, semicolon):
				iterSeparated(vars, function(v) {
					// TODO: check what is allowed to be resolved
					if (v.init != null) typeExpr(v.init.expr);
				});
				TFVar;
			case FFun(keyword, name, fun):
				trace(" - " + name.text);
				initLocals();
				// TODO: can use structure to get arg types (speedup \o/)
				var f = typeFunction(fun);
				TFFun({
					syntax: {
						keyword: keyword,
						name: name,
					},
					name: name.text,
					fun: f
				});
			case FProp(keyword, kind, name, fun):
				trace(" - " + name.text);
				initLocals();
				// TODO: can use structure to get arg types (speedup \o/)
				typeFunction(fun);
				TFProp;
		}
		return {
			kind: kind
		};
	}

	function typeFunction(fun:Function):TFunction {
		pushLocals();

		var targs = new Array<TFunctionArg>();
		if (fun.signature.args != null) {
			iterSeparated(fun.signature.args, function(arg) {
				switch (arg) {
					case ArgNormal(a):
						var type = if (a.type == null) TTAny else resolveType(a.type.type);
						addLocal(a.name.text, type);
						targs.push({name: a.name.text, type: type, kind: TArgNormal});
					case ArgRest(dots, name):
						addLocal(name.text, TTArray);
						targs.push({name: name.text, type: TTArray, kind: TArgRest});
				}
			});
		}

		var tret:TTypeHint;
		if (fun.signature.ret != null) {
			tret = {
				type: resolveType(fun.signature.ret.type),
				syntax: fun.signature.ret
			};
		} else {
			tret = {type: TTAny, syntax: null};
		}
		var block = typeBlock(fun.block);

		popLocals();

		return {
			sig: {
				syntax: {
					openParen: fun.signature.openParen,
					closeParen: fun.signature.closeParen,
				},
				args: targs,
				ret: tret,
			},
			block: block
		};
	}

	function typeExpr(e:Expr):TExpr {
		return switch (e) {
			case EIdent(i): typeIdent(i, e);
			case ELiteral(l): typeLiteral(l);
			case ECall(e, args): typeCall(e, args);
			case EParens(openParen, e, closeParen): typeExpr(e);
			case EArrayAccess(e, openBracket, eindex, closeBracket): typeArrayAccess(e, openBracket, eindex, closeBracket);
			case EArrayDecl(d): typeArrayDecl(d);
			case EVectorDecl(newKeyword, t, d): typeVectorDecl(t.type, d);
			case EReturn(keyword, e): mk(TEReturn(keyword, if (e != null) typeExpr(e) else null), TTVoid);
			case EThrow(keyword, e): mk(TEThrow(keyword, typeExpr(e)), TTVoid);
			case EDelete(keyword, e): mk(TEDelete(keyword, typeExpr(e)), TTVoid);
			case ENew(keyword, e, args): typeNew(e, args);
			case EField(eobj, dot, fieldName): typeField(eobj, dot, fieldName);
			case EBlock(b): mk(TEBlock(typeBlock(b)), TTVoid);
			case EObjectDecl(openBrace, fields, closeBrace): typeObjectDecl(openBrace, fields, closeBrace);
			case EIf(keyword, openParen, econd, closeParen, ethen, eelse): typeIf(econd, ethen, eelse);
			case ETernary(econd, question, ethen, colon, eelse): typeTernary(econd, ethen, eelse);
			case EWhile(keyword, openParen, cond, closeParen, body): typeWhile(cond, body);
			case EDoWhile(doKeyword, body, whileKeyword, openParen, cond, closeParen): typeDoWhile(body, cond);
			case EFor(keyword, openParen, einit, initSep, econd, condSep, eincr, closeParen, body): typeFor(einit, econd, eincr, body);
			case EForIn(forKeyword, openParen, iter, closeParen, body): typeForIn(iter, body);
			case EForEach(forKeyword, eachKeyword, openParen, iter, closeParen, body): typeForIn(iter, body);
			case EBinop(a, op, b): typeBinop(a, op, b);
			case EPreUnop(op, e): typeExpr(e);
			case EPostUnop(e, op): typeExpr(e);
			case EVars(kind, vars): typeVars(kind, vars);
			case EAs(e, keyword, t): typeAs(e, t);
			case EIs(e, keyword, t): typeIs(e, t);
			case EComma(a, comma, b): typeComma(a, b);
			case EVector(v): typeVector(v);
			case ESwitch(keyword, openParen, subj, closeParen, openBrace, cases, closeBrace): typeSwitch(subj, cases);
			case ETry(keyword, block, catches, finally_): typeTry(block, catches, finally_);
			case EFunction(keyword, name, fun): mk(TEFunction(typeFunction(fun)), TTFunction);

			case EBreak(keyword): mk(TEBreak(keyword), TTVoid);
			case EContinue(keyword): mk(TEContinue(keyword), TTVoid);

			case EXmlAttr(e, dot, at, attrName): typeXmlAttr(e, attrName);
			case EXmlAttrExpr(e, dot, at, openBrace, eattr, closeBrace): typeXmlAttrExpr(e, eattr);
			case EXmlDescend(e, dotDot, childName): typeXmlDescend(e, childName);
			case ECondCompValue(v): throw "ECondCompValue";
			case ECondCompBlock(v, b): typeCondCompBlock(v, b);
			case EUseNamespace(n): mk(TENothing, TTVoid);
		}
	}

	function typeXmlAttr(e:Expr, attrName:Token):TExpr {
		var e = typeExpr(e);
		return mk(TEXmlAttr(e, attrName.text), TTXMLList);
	}

	function typeXmlAttrExpr(e:Expr, eattr:Expr):TExpr {
		var e = typeExpr(e);
		var eattr = typeExpr(eattr);
		return mk(TEXmlAttrExpr(e, eattr), TTXMLList);
	}

	function typeXmlDescend(e:Expr, childName:Token):TExpr {
		var e = typeExpr(e);
		return mk(TEXmlDescend(e, childName.text), TTXMLList);
	}

	function typeCondCompBlock(v:CondCompVar, block:BracedExprBlock):TExpr {
		var expr = typeExpr(EBlock(block));
		return mk(TECondCompBlock(v.ns.text, v.name.text, expr), TTVoid);
	}

	function typeVector(v:VectorSyntax):TExpr {
		var type = resolveType(v.t.type);
		return mk(TEVector(type), TTFunction);
	}

	function typeTry(block:BracedExprBlock, catches:Array<Catch>, finally_:Null<Finally>):TExpr {
		if (finally_ != null) throw "finally is unsupported";
		var body = typeExpr(EBlock(block));
		var tCatches = [];
		for (c in catches) {
			pushLocals();
			var v = addLocal(c.name.text, resolveType(c.type.type));
			var e = typeExpr(EBlock(c.block));
			popLocals();
			tCatches.push({v: v, expr: e});
		}
		return mk(TETry(body, tCatches), TTVoid);
	}

	function typeSwitch(esubj:Expr, cases:Array<SwitchCase>):TExpr {
		var esubj = typeExpr(esubj);
		var tcases = [];
		var def:Null<Array<TExpr>> = null;
		for (c in cases) {
			switch (c) {
				case CCase(keyword, v, colon, body):
					var v = typeExpr(v);
					var body = [for (e in body) typeExpr(e.expr)];
					tcases.push({
						value: v,
						body: body
					});
				case CDefault(keyword, colon, body):
					if (def != null) throw "double `default` in switch";
					def = [for (e in body) typeExpr(e.expr)];
			}
		}
		return mk(TESwitch(esubj, tcases, def), TTVoid);
	}

	function typeAs(e:Expr, t:SyntaxType) {
		var e = typeExpr(e);
		var type = resolveType(t);
		return mk(TEAs(e, type), type);
	}

	function typeIs(e:Expr, etype:Expr):TExpr {
		var e = typeExpr(e);
		var etype = typeExpr(etype);
		return mk(TEIs(e, etype), TTBoolean);
	}

	function typeComma(a:Expr, b:Expr):TExpr {
		var a = typeExpr(a);
		var b = typeExpr(b);
		return mk(TEComma(a, b), b.type);
	}

	function typeBinop(a:Expr, op:Binop, b:Expr):TExpr {
		var a = typeExpr(a);
		var b = typeExpr(b);
		var type = TTInt;
		return mk(TEBinop(a, op, b), type);
	}

	function typeForIn(iter:ForIter, ebody:Expr):TExpr {
		pushLocals();
		var eobj = typeExpr(iter.eobj);
		var eit = typeExpr(iter.eit);
		var ebody = typeExpr(ebody);
		popLocals();
		return mk(TEForIn(eit, eobj, ebody), TTVoid);
	}

	function typeFor(einit:Null<Expr>, econd:Null<Expr>, eincr:Null<Expr>, ebody:Expr):TExpr {
		pushLocals();
		var einit = if (einit != null) typeExpr(einit) else null;
		var econd = if (econd != null) typeExpr(econd) else null;
		var eincr = if (eincr != null) typeExpr(eincr) else null;
		var ebody = typeExpr(ebody);
		popLocals();
		return mk(TEFor(einit, econd, eincr, ebody), TTVoid);
	}

	function typeWhile(econd:Expr, ebody:Expr):TExpr {
		var econd = typeExpr(econd);
		var ebody = typeExpr(ebody);
		return mk(TEWhile(econd, ebody), TTVoid);
	}

	function typeDoWhile(ebody:Expr, econd:Expr):TExpr {
		var ebody = typeExpr(ebody);
		var econd = typeExpr(econd);
		return mk(TEDoWhile(ebody, econd), TTVoid);
	}

	function typeIf(econd:Expr, ethen:Expr, eelse:Null<{keyword:Token, expr:Expr}>):TExpr {
		var econd = typeExpr(econd);
		var ethen = typeExpr(ethen);
		var eelse = if (eelse != null) typeExpr(eelse.expr) else null;
		return mk(TEIf(econd, ethen, eelse), TTVoid);
	}

	function typeTernary(econd:Expr, ethen:Expr, eelse:Expr):TExpr {
		var econd = typeExpr(econd);
		var ethen = typeExpr(ethen);
		var eelse = typeExpr(eelse);
		return mk(TETernary(econd, ethen, eelse), ethen.type);
	}

	function typeCall(e:Expr, args:CallArgs) {
		var eobj = typeExpr(e);
		var targs = {
			openParen: args.openParen,
			closeParen: args.closeParen,
			args:
				if (args.args != null)
					separatedToArray(args.args, (expr, comma) -> {expr: typeExpr(expr), comma: comma})
				else
					[]
		};

		var type = switch eobj.kind {
			case TELiteral(TLSuper(_)): // super(...) call
				TTVoid;
			case _:
				switch (eobj.type) {
					case TTAny | TTFunction: TTAny;
					case TTFun(_, ret): ret;
					case TTStatic(cls): TTInst(cls); // ClassName(expr) cast (TODO: this should be TESafeCast expression)
					case other: trace("unknown callable type: " + other); TTAny; // TODO: super, builtins, etc.
				}
		}

		return mk(TECall(eobj, targs), type);
	}

	function typeNew(e:Expr, args:Null<CallArgs>):TExpr {
		var e = typeExpr(e);
		var args = if (args != null && args.args != null) foldSeparated(args.args, [], (e,acc) -> acc.push(typeExpr(e))) else [];
		var type = switch (e.type) {
			case TTStatic(cls): TTInst(cls);
			case _: TTObject; // TODO: is this correct?
		}
		return mk(TENew(e, args), type);
	}

	function typeBlock(b:BracedExprBlock):TBlock {
		pushLocals();
		var exprs = [];
		for (e in b.exprs) {
			exprs.push({
				expr: typeExpr(e.expr),
				semicolon: e.semicolon
			});
		}
		popLocals();
		return {
			syntax: {openBrace: b.openBrace, closeBrace: b.closeBrace},
			exprs: exprs
		};
	}

	function typeArrayAccess(e:Expr, openBracket:Token, eindex:Expr, closeBracket:Token):TExpr {
		var e = typeExpr(e);
		var eindex = typeExpr(eindex);
		var type = switch (e.type) {
			case TTVector(t): t;
			case _: TTAny;
		};
		return mk(TEArrayAccess({
			syntax: {openBracket: openBracket, closeBracket: closeBracket},
			eobj: e,
			eindex: eindex
		}), type);
	}

	function typeArrayDecl(d:ArrayDecl):TExpr {
		var elems = if (d.elems != null) foldSeparated(d.elems, [], function(e, acc) acc.push(typeExpr(e))) else [];
		return mk(TEArrayDecl(d, elems), TTArray);
	}

	function typeVectorDecl(t:SyntaxType, d:ArrayDecl):TExpr {
		var type = resolveType(t);
		var elems = if (d.elems != null) foldSeparated(d.elems, [], function(e, acc) acc.push(typeExpr(e))) else [];
		return mk(TEVectorDecl(type, elems), TTVector(type));
	}

	function getTypeOfFunctionDecl(f:SFunDecl):TType {
		return TTFun([for (a in f.args) typeType(a.type)], typeType(f.ret));
	}

	function mkDeclRef(path:DotPath, decl:SDecl):TExpr {
		var type = switch (decl.kind) {
			case SVar(v): typeType(v.type);
			case SFun(f): getTypeOfFunctionDecl(f);
			case SClass(c): TTStatic(c);
		};
		return mk(TEDeclRef(path, decl), type);
	}

	function getFieldType(field:SClassField):TType {
		var t = switch (field.kind) {
			case SFVar(v): typeType(v.type);
			case SFFun(f): getTypeOfFunctionDecl(f);
		};
		if (t == TTVoid) throw "assert";
		return t;
	}

	function tryTypeIdent(i:Token):Null<TExpr> {
		inline function getCurrentClass(subj) return if (currentClass != null) currentClass else throw '`$subj` used outside of class';

		return switch i.text {
			case "this": mk(TELiteral(TLThis(i)), TTInst(getCurrentClass("this")));
			case "super": mk(TELiteral(TLSuper(i)), TTInst(structure.getClass(getCurrentClass("super").extensions[0])));
			case "true" | "false": mk(TELiteral(TLBool(i)), TTBoolean);
			case "null": mk(TELiteral(TLNull(i)), TTAny);
			case "undefined": mk(TELiteral(TLUndefined(i)), TTAny);
			case "arguments": mk(TEBuiltin(i, "arguments"), TTBuiltin);
			case "trace": mk(TEBuiltin(i, "trace"), TTFunction);
			case "int": mk(TEBuiltin(i, "int"), TTBuiltin);
			case "uint": mk(TEBuiltin(i, "int"), TTBuiltin);
			case "Boolean": mk(TEBuiltin(i, "Boolean"), TTBuiltin);
			case "Number": mk(TEBuiltin(i, "Number"), TTBuiltin);
			case "XML": mk(TEBuiltin(i, "XML"), TTBuiltin);
			case "XMLList": mk(TEBuiltin(i, "XMLList"), TTBuiltin);
			case "String": mk(TEBuiltin(i, "String"), TTBuiltin);
			case "Array": mk(TEBuiltin(i, "Array"), TTBuiltin);
			case "Function": mk(TEBuiltin(i, "Function"), TTBuiltin);
			case "Class": mk(TEBuiltin(i, "Class"), TTBuiltin);
			case "Object": mk(TEBuiltin(i, "Object"), TTBuiltin);
			case "RegExp": mk(TEBuiltin(i, "RegExp"), TTBuiltin);
			// TODO: actually these must be resolved after everything because they are global idents!!!
			case "parseInt":  mk(TEBuiltin(i, "parseInt"), TTFun([TTString], TTInt));
			case "parseFloat": mk(TEBuiltin(i, "parseFloat"), TTFun([TTString], TTNumber));
			case "NaN": mk(TEBuiltin(i, "NaN"), TTNumber);
			case "isNaN": mk(TEBuiltin(i, "isNaN"), TTFun([TTNumber], TTBoolean));
			case "escape": mk(TEBuiltin(i, "escape"), TTFun([TTString], TTString));
			case "unescape": mk(TEBuiltin(i, "unescape"), TTFun([TTString], TTString));
			case ident:
				var v = locals[ident];
				if (v != null) {
					return mk(TELocal(i, v), v.type);
				}

				if (currentClass != null) {
					var currentClass:SClassDecl = currentClass; // TODO: this is here only to please the null-safety checker
					function loop(c:SClassDecl):Null<TExpr> {
						var field = c.fields.get(ident);
						if (field != null) {
							// found a field
							var eobj = {
								kind: TOImplicitThis(currentClass),
								type: TTInst(currentClass)
							};
							var type = getFieldType(field);
							return mk(TEField(eobj, ident, i), type);
						}
						for (ext in c.extensions) {
							var e = loop(structure.getClass(ext));
							if (e != null) {
								return e;
							}
						}
						return null;
					}
					var eField = loop(currentClass);
					if (eField != null) {
						return eField;
					}

					// TODO: copypasta

					function loop(c:SClassDecl):Null<TExpr> {
						var field = c.statics.get(ident);
						if (field != null) {
							// found a field
							var eobj = {
								kind: TOImplicitClass(currentClass),
								type: TTStatic(currentClass),
							};
							var type = getFieldType(field);
							return mk(TEField(eobj, ident, i), type);
						}
						for (ext in c.extensions) {
							var e = loop(structure.getClass(ext));
							if (e != null) {
								return e;
							}
						}
						return null;
					}
					var eField = loop(currentClass);
					if (eField != null) {
						return eField;
					}
				}

				var dotPath = {first: i, rest: []};

				var decl = currentModule.getDecl(ident);
				if (decl != null) {
					return mkDeclRef(dotPath, decl);
				}

				for (i in currentModule.imports) {
					switch (i) {
						case SISingle(pack, name):
							if (name == ident) {
								// trace('Found imported decl: $pack::$name');
								return mkDeclRef(dotPath, structure.getDecl(pack, name));
							}
						case SIAll(pack):
							switch structure.packages[pack] {
								case null:
								case p:
									var m = p.getModule(ident);
									if (m != null) {
										// trace('Found imported decl: $pack::$ident');
										return mkDeclRef(dotPath, m.mainDecl);
									}
							}
					}
				}

				var modInPack = currentModule.pack.getModule(ident);
				if (modInPack != null) {
					return mkDeclRef(dotPath, modInPack.mainDecl);
				}

				switch structure.packages[""] {
					case null:
					case pack:
						var toplevel = pack.getModule(ident);
						if (toplevel != null) {
							return mkDeclRef(dotPath, toplevel.mainDecl);
						}
				}

				return null;
		}
	}

	function typeIdent(i:Token, e:Expr):TExpr {
		var e = tryTypeIdent(i);
		if (e == null) throw 'Unknown ident: ${i.text}';
		return e;
	}

	function typeLiteral(l:Literal):TExpr {
		return switch (l) {
			case LString(t): mk(TELiteral(TLString(t)), TTString);
			case LDecInt(t) | LHexInt(t): mk(TELiteral(TLInt(t)), TTInt);
			case LFloat(t): mk(TELiteral(TLNumber(t)), TTNumber);
			case LRegExp(t): mk(TELiteral(TLRegExp(t)), TTRegExp);
		}
	}

	function getTypedField(obj:TFieldObject, fieldToken:Token) {
		var fieldName = fieldToken.text;
		var type =
			switch fieldName { // TODO: be smarter about this
				case "toString":
					TTFun([], TTString);
				case "hasOwnProperty":
					TTFun([TTString], TTBoolean);
				case "prototype":
					TTObject;
				case _:
					switch (obj.type) {
						case TTAny | TTObject: TTAny; // untyped field access
						case TTVoid | TTBoolean | TTNumber | TTInt | TTUint | TTClass: trace('Attempting to get field on type ${obj.type.getName()}'); TTAny;
						case TTBuiltin: trace(obj); TTAny;
						case TTString:  TTAny; // TODO
						case TTArray:  TTAny; // TODO
						case TTVector(t):  TTAny; // TODO
						case TTFunction | TTFun(_):  TTAny; // TODO (.call, .apply)
						case TTRegExp:  TTAny; // TODO
						case TTXML | TTXMLList: TTAny; // TODO
						case TTInst(cls): typeInstanceField(cls, fieldName);
						case TTStatic(cls): typeStaticField(cls, fieldName);
					};
		}
		return mk(TEField(obj, fieldName, fieldToken), type);
	}

	function typeField(eobj:Expr, dot:Token, name:Token):TExpr {
		switch exprToDotPath(eobj) {
			case null:
			case prefixDotPath:
				var e = tryTypeIdent(prefixDotPath.first);
				if (e == null) @:nullSafety(Off) {
					// probably a fully-qualified type path then

					var acc = [{dot: null, token: prefixDotPath.first}];
					for (r in prefixDotPath.rest) acc.push({dot: r.sep, token: r.element});

					var declName = {dot: dot, token: name};
					var decl = null;
					var rest = [];
					while (acc.length > 0) {
						var packName = [for (t in acc) t.token.text].join(".");
						var pack = structure.packages[packName];
						if (pack != null) {
							var mod = pack.getModule(declName.token.text);
							decl = mod.mainDecl;
							break;
						} else {
							rest.push(declName);
							declName = acc.pop();
						}
					}

					if (decl == null) {
						throw "unknown declaration";
					}

					acc.push(declName);
					var dotPath = {
						first: acc[0].token,
						rest: [for (i in 1...acc.length) {sep: acc[i].dot, element: acc[i].token}]
					};
					var eDeclRef = mkDeclRef(dotPath, decl);

					return Lambda.fold(rest, function(f, expr) {
						return getTypedField({kind: TOExplicit(f.dot, expr), type: expr.type}, f.token);
					}, eDeclRef);
				}
		}

		// TODO: we don't need to re-type stuff,
		// can iterate over fields, but let's do it later :-)

		var eobj = typeExpr(eobj);
		var obj = {
			type: eobj.type,
			kind: TOExplicit(dot, eobj)
		};
		return getTypedField(obj, name);
	}

	function typeInstanceField(cls:SClassDecl, fieldName:String):TType {
		function loop(cls:SClassDecl):Null<SClassField> {
			var field = cls.fields.get(fieldName);
			if (field != null) {
				return field;
			}
			for (ext in cls.extensions) {
				var field = loop(structure.getClass(ext));
				if (field != null) {
					return field;
				}
			}
			return null;
		}

		var field = loop(cls);
		if (field != null) {
			return getFieldType(field);
		}

		throw 'Unknown instance field $fieldName on class ${cls.name}';
	}

	function typeStaticField(cls:SClassDecl, fieldName:String):TType {
		var field = cls.statics.get(fieldName);
		if (field != null) {
			return getFieldType(field);
		}
		throw 'Unknown static field $fieldName on class ${cls.name}';
	}

	function typeObjectDecl(openBrace:Token, fields:Separated<ObjectField>, closeBrace:Token):TExpr {
		var fields = separatedToArray(fields, function(f, comma) {
			return {
				syntax: {name: f.name, colon: f.colon, comma: comma},
				name: f.name.text,
				expr: typeExpr(f.value)
			};
		});
		return mk(TEObjectDecl({
			syntax: {openBrace: openBrace, closeBrace: closeBrace},
			fields: fields
		}), TTObject);
	}

	function typeVarInit(init:VarInit):TVarInit {
		return {equals: init.equals, expr: typeExpr(init.expr)};
	}

	function typeVars(kind:VarDeclKind, vars:Separated<VarDecl>):TExpr {
		var vars = separatedToArray(vars, function(v, comma) {
			var type = if (v.type == null) TTAny else resolveType(v.type.type);
			var init = if (v.init != null) typeVarInit(v.init) else null;
			var tvar = addLocal(v.name.text, type);
			return {
				syntax: v,
				v: tvar,
				init: init,
				comma: comma,
			};
		});
		return mk(TEVars(kind, vars), TTVoid);
	}
}
