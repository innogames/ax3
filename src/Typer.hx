import ParseTree.CallArgs;
import ParseTree.VarDecl;
import ParseTree.VarDeclKind;
import ParseTree.Catch;
import ParseTree.Finally;
import ParseTree.PostUnop;
import ParseTree.PreUnop;
import ParseTree.Expr;
import ParseTree.BracedExprBlock;
import ParseTree.Separated;
import haxe.ds.Map;
import sys.io.File;
import TypedTree;
import Utils.createDirectory;

class Typer {
	var files:Array<ParseTree.File>;

	var modules:Array<TModule>;
	var moduleMap:Map<String,TModule>;

	public function new() {
		files = [];
	}

	public function addFile(file:ParseTree.File) {
		files.push(file);
	}

	public function process() {
		buildStructure();
		resolveTypes();
	}

	function buildStructure() {
		modules = [];
		moduleMap = new Map();
		for (file in files) {
			var packageDecl = null;

			for (decl in file.declarations) {
				switch (decl) {
					case DPackage(p):
						if (packageDecl == null)
							packageDecl = p;
						else
							throw "duplicate package declaration!";

					case _:
						trace("TODO: " + decl.getName());
				}
			}

			if (packageDecl == null) throw "no package declaration!";

			var mainType = null;

			for (decl in packageDecl.declarations) {
				switch (decl) {
					case DClass(c):
						if (mainType == null)
							mainType = TDClass(processClassDecl(c));
						else
							throw "more than one main type!";
					case _:
						trace("TODO: " + decl.getName());
				}
			}

			if (mainType == null) {
				trace("no main type!"); continue;
				throw "no main type!";
			}

			var pack = getPack(packageDecl);

			var module:TModule = {
				pack: pack,
				packDecl: packageDecl,
				name: file.name,
				syntax: file,
				mainType: mainType
			};


			var path = pack.concat([file.name]).join(".");
			moduleMap[path] = module;
			modules.push(module);
		}
	}

	function resolveTypes() {
		for (module in modules) {
			// trace("Resolving module " + module);
		}
	}

	function processClassDecl(c:ParseTree.ClassDecl):TClass {
		var fields = new Array<TClassField>();
		var fieldMap = new Map();

		inline function addField(field:TClassField) {
			var name = field.name.text;
			if (fieldMap.exists(name))
				throw 'Field $name already exists!';
			fields.push(field);
			fieldMap[name] = field;
		}

		for (m in c.members) {
			switch (m) {
				case MCondComp(v, openBrace, members, closeBrace):
					trace("TODO: conditional compilation");
				case MUseNamespace(n, semicolon):
					trace("TODO: use namespace");
				case MStaticInit(block):
					trace("TODO: static init");
				case MField(f):
					switch (f.kind) {
						case FVar(kind, vars, semicolon):
							var tVars = [];

							var prevDecl:TFVarDecl;

							inline function add(v:ParseTree.VarDecl) {
								var init = null;
								if (v.init != null) {
									init = {
										syntax: v.init,
										expr: typeExpr(v.init.expr),
									};
								}
								tVars.push({
									name: v.name,
									kind: TFVar(prevDecl = {
										syntax: v,
										kind: kind,
										init: init,
										endToken: null
									})
								});
							}

							add(vars.first);
							for (v in vars.rest) {
								prevDecl.endToken = v.sep;
								add(v.element);
							}

							prevDecl.endToken = semicolon;

							for (v in tVars) {
								addField(v);
							}

						case FFun(keyword, name, fun):
							addField({
								name: name,
								kind: TFFun({
									keyword: keyword,
									fun: typeFunction(fun)
								})
							});
						case FProp(keyword, kind, name, fun):
							trace("TODO: property");
					}
			}
		}

		return {
			syntax: c,
			fields: fields,
			fieldMap: fieldMap,
		};
	}

	function separatedToArray<T,S>(s:ParseTree.Separated<T>, f:(T,Token)->S):Array<S> {
		var result = [];
		
		inline function add(v:T, i:Int) {
			result.push(f(v, if (i < s.rest.length) s.rest[i].sep else null));
		}
		
		add(s.first, 0);
		for (i in 0...s.rest.length) {
			add(s.rest[i].element, i + 1);
		}

		return result;
	}

	function typeFunction(fun:ParseTree.Function):TFunction {
		var args = 
			if (fun.signature.args != null)
				separatedToArray(fun.signature.args, function(v, comma) {
					return {
						syntax: switch (v) {
							case ArgNormal(a): a;
							case ArgRest(dots, name):
								trace("TODO: REST");
								{name: name, type: null, init: null};
						},
						comma: comma,
					}
				});
			else
				[];
		return {
			signature: {syntax: fun.signature, args: args},
			expr: typeExpr(EBlock(fun.block))
		};
	}

	function typeLiteral(l:ParseTree.Literal):TExpr {
		return {
			kind: TELiteral(l),
			type: switch (l) {
				case LString(t): TString;
				case LDecInt(t): TInt;
				case LHexInt(t): TInt;
				case LFloat(t): TNumber;
				case LRegExp(t): TUnresolved("RegExp");
			}
		};
	}

	function typeBinop(a:ParseTree.Expr, op:ParseTree.Binop, b:ParseTree.Expr):TExpr {
		var a = typeExpr(a);
		var b = typeExpr(b);
		return {
			kind: TEBinop(a, op, b),
			type: TObject
		};
	}

	function typeBlock(b:ParseTree.BracedExprBlock):TExpr {
		var exprs = [
			for (e in b.exprs)
				{expr: typeExpr(e.expr), semicolon: e.semicolon}
		];
		return {
			kind: TEBlock(b.openBrace, exprs, b.closeBrace),
			type: TVoid,
		};
	}

	function typeIf(keyword:Token, openParen:Token, econd:ParseTree.Expr, closeParen:Token, ethen:ParseTree.Expr, eelse:Null<{keyword:Token, expr:ParseTree.Expr}>):TExpr {
		var econd = typeExpr(econd); // this needs to-bool coercion for Haxe
		var ethen = typeExpr(ethen);
		var eelse = if (eelse == null) null else {
			keyword: eelse.keyword,
			expr: typeExpr(eelse.expr)
		};
		return {
			kind: TEIf(keyword, openParen, econd, closeParen, ethen, eelse),
			type: TVoid
		}
	}

	function typeIdent(i:Token):TExpr {
		return switch i.text {
			case "null": {kind: TNull(i), type: TAny};
			case "this": {kind: TThis(i), type: TAny};
			case "super": {kind: TSuper(i), type: TAny};
			case _: {kind: TNull(i), type: TAny};
		}
	}
	
	function typeCallArgs(args:CallArgs):TCallArgs {
		var argsArray = if (args.args != null) separatedToArray(args.args, (e,comma) -> {expr: typeExpr(e), comma: comma}) else [];
		return {openParen: args.openParen, args: argsArray, closeParen: args.closeParen};
	}

	function typeCall(e:ParseTree.Expr, args:ParseTree.CallArgs):TExpr {
		var e = typeExpr(e);
		return {
			kind: TECall(e, typeCallArgs(args)),
			type: TAny,
		};
	}

	function typeNew(keyword:Token, e:Expr, args:CallArgs):TExpr {
		var e = typeExpr(e);
		return {
			kind: TENew(keyword, e, if (args != null) typeCallArgs(args) else null),
			type: TAny
		};
	}

	function typeArrayAccess(e:ParseTree.Expr, openBracket:Token, eindex:Expr, closeBracket:Token):TExpr {
		var e = typeExpr(e);
		var eindex = typeExpr(eindex);
		return {
			kind: TEArrayAccess(e, openBracket, eindex, closeBracket),
			type: TAny
		}
	}

	function typePreUnop(e:Expr, op:PreUnop):TExpr {
		var e = typeExpr(e);
		return {
			kind: TEPreUnop(op, e),
			type: TAny
		};
	}

	function typePostUnop(e:Expr, op:PostUnop):TExpr {
		var e = typeExpr(e);
		return {
			kind: TEPostUnop(e, op),
			type: TAny
		};
	}

	function typeTry(keyword:Token, block:BracedExprBlock, catches:Array<Catch>, finally_:Null<Finally>):TExpr {
		if (finally_ != null) throw "finally in `try` is not supported yet";
		var expr = typeExpr(EBlock(block));
		var catches = [
			for (c in catches) {
				{
					syntax: c,
					expr: typeExpr(EBlock(c.block))
				}
			}
		];
		return {
			kind: TETry(keyword, expr, catches),
			type: TVoid
		}
	}

	function typeComma(a:Expr, comma:Token, b:Expr):TExpr {
		var a = typeExpr(a);
		var b = typeExpr(b);
		return {
			kind: TEComma(a, comma, b),
			type: b.type
		};
	}

	function typeVars(kind:VarDeclKind, vars:ParseTree.Separated<VarDecl>):TExpr {
		var vars = separatedToArray(vars, function(v, comma) {
			return {
				decl: {
					syntax: v,
					init: if (v.init != null) {syntax: v.init, expr: typeExpr(v.init.expr)} else null
				},
				comma: comma,
			};
		});
		return {
			kind: TEVars(kind, vars),
			type: TVoid
		};
	}

	function typeObjectDecl(openBrace:Token, fields:Separated<ParseTree.ObjectField>, closeBrace:Token):TExpr {
		var fields = separatedToArray(fields, function(f, comma) {
			return {
				field: {
					name: f.name,
					colon: f.colon,
					value: typeExpr(f.value),
				},
				comma: comma
			};
		});
		return {
			kind: TEObjectDecl(openBrace, fields, closeBrace),
			type: TObject,
		}
	}

	function typeField(e:Expr, dot:Token, fieldName:Token):TExpr {
		var e = typeExpr(e);
		return {
			kind: TEField(e, dot, fieldName),
			type: TAny
		};
	}

	function typeArrayDecl(d:ParseTree.ArrayDecl):TExpr {
		var elems = if (d.elems == null) [] else separatedToArray(d.elems, (e,comma) -> {expr: typeExpr(e), comma: comma});
		return {
			kind: TEArrayDecl({openBracket: d.openBracket, elems: elems, closeBracket: d.closeBracket}),
			type: TUnresolved("Array")
		};
	}

	function typeExpr(e:ParseTree.Expr):TExpr {
		var none:TExpr = {
			kind: TELiteral(LString({
				var t = new Token(TkStringSingle, "'TODO'");
				t.leadTrivia = t.trailTrivia = [];
				t;
			})),
			type: null
		};
		return switch (e) {
			case ELiteral(l): typeLiteral(l);
			case EIdent(i): typeIdent(i);
			case ECall(e, args): typeCall(e, args);
			case EArrayAccess(e, openBracket, eindex, closeBracket): typeArrayAccess(e, openBracket, eindex, closeBracket);
			case EParens(openParen, e, closeParen):
				var e = typeExpr(e);
				{kind: TEParens(openParen, e, closeParen), type: e.type};
			case EArrayDecl(d): typeArrayDecl(d);
			case EReturn(keyword, e): {kind: TEReturn(keyword, if (e != null) typeExpr(e) else null), type: TVoid};
			case EThrow(keyword, e): {kind: TEThrow(keyword, typeExpr(e)), type: TVoid};
			case EDelete(keyword, e): {kind: TEDelete(keyword, typeExpr(e)), type: TVoid};
			case EBreak(keyword): {kind: TEContinue(keyword), type: TVoid};
			case EContinue(keyword): {kind: TEContinue(keyword), type: TVoid};
			case ENew(keyword, e, args): typeNew(keyword, e, args);
			case EVectorDecl(newKeyword, t, d): trace("TODO"); none;
			case EField(e, dot, fieldName): typeField(e, dot, fieldName);
			case EXmlAttr(e, dot, at, attrName): trace("TODO"); none;
			case EXmlDescend(e, dotDot, childName): trace("TODO"); none;
			case EBlock(b): typeBlock(b);
			case EObjectDecl(openBrace, fields, closeBrace): typeObjectDecl(openBrace, fields, closeBrace);
			case EIf(keyword, openParen, econd, closeParen, ethen, eelse): typeIf(keyword, openParen, econd, closeParen, ethen, eelse);
			case ETernary(econd, question, ethen, colon, eelse):
				var econd = typeExpr(econd);
				var ethen = typeExpr(ethen);
				var eelse = typeExpr(eelse);
				{
					kind: TETernary(econd, question, ethen, colon, eelse),
					type: ethen.type
				}
			case EWhile(keyword, openParen, cond, closeParen, body):
				{kind: TEWhile(keyword, openParen, typeExpr(cond), closeParen, typeExpr(body)), type: TVoid};
			case EDoWhile(doKeyword, body, whileKeyword, openParen, cond, closeParen):
				{kind: TEDoWhile(doKeyword, typeExpr(body), whileKeyword, openParen, typeExpr(cond), closeParen), type: TVoid};
			case EFor(keyword, openParen, einit, initSep, econd, condSep, eincr, closeParen, body): trace("TODO"); none;
			case EForIn(forKeyword, openParen, iter, closeParen, body): trace("TODO"); none;
			case EForEach(forKeyword, eachKeyword, openParen, iter, closeParen, body): trace("TODO"); none;
			case EBinop(a, op, b): typeBinop(a, op, b);
			case EPreUnop(op, e): typePreUnop(e, op);
			case EPostUnop(e, op): typePostUnop(e, op);
			case EVars(kind, vars): typeVars(kind, vars);
			case EAs(e, keyword, t): trace("TODO"); none;
			case EIs(e, keyword, t): trace("TODO"); none;
			case EComma(a, comma, b): typeComma(a, comma, b);
			case EVector(v): trace("TODO"); none;
			case ESwitch(keyword, openParen, subj, closeParen, openBrace, cases, closeBrace): trace("TODO"); none;
			case ECondCompValue(v): trace("TODO"); none;
			case ECondCompBlock(v, b): trace("TODO"); none;
			case ETry(keyword, block, catches, finally_): typeTry(keyword, block, catches, finally_);
			case EFunction(keyword, name, fun): trace("TODO"); none;
			case EUseNamespace(n): trace("TODO"); none;
		}
	}

	public function write(outDir:String) {
		for (m in modules) {
			var dir = outDir + m.pack.join("/");
			createDirectory(dir);
			var outFile = dir + "/" + m.name + ".hx";
			var gen = new GenHaxe();
			trace('writing ${m.pack.join(".")} ${m.name}');
			gen.writeModule(m);
			File.saveContent(outFile, gen.getContent());
		}
	}

	static function getPack(p:ParseTree.PackageDecl):Array<String> {
		var result = [];
		if (p.name != null) {
			result.push(p.name.first.text);
			for (el in p.name.rest) {
				result.push(el.element.text);
			}
		}
		return result;
	}
}
