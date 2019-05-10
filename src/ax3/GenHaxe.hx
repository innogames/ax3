package ax3;

import ax3.ParseTree;
import ax3.TypedTree;
import ax3.Token.Trivia;
using StringTools;

@:nullSafety
class GenHaxe extends PrinterBase {
	@:nullSafety(Off) var currentModule:TModule;

	public function writeModule(m:TModule) {
		currentModule = m;
		printPackage(m.pack);
		for (d in m.privateDecls) {
			printDecl(d);
		}
		printTrivia(m.eof.leadTrivia);
		@:nullSafety(Off) currentModule = null;
	}

	function printPackage(p:TPackageDecl) {
		if (p.syntax.name != null) {
			printTextWithTrivia("package", p.syntax.keyword);
			printDotPath(p.syntax.name);
			buf.add(";");
		} else {
			printTokenTrivia(p.syntax.keyword);
		}

		printTokenTrivia(p.syntax.openBrace);

		for (i in p.imports) {
			printImport(i);
		}

		for (n in p.namespaceUses) {
			printUseNamespace(n.n);
			printTokenTrivia(n.semicolon);
		}

		printDecl(p.decl);
		printTokenTrivia(p.syntax.closeBrace);
	}

	function printImport(i:TImport) {
		if (i.syntax.condCompBegin != null) printCondCompBegin(i.syntax.condCompBegin);
		if (!i.kind.match(TIDecl({kind: TDNamespace(_)}))) { // TODO: still print trivia from namespace imports?
			printTextWithTrivia("import", i.syntax.keyword);

			{
				// lowercase package first letter for Haxe
				// TODO: don't use syntax at all, and get rid of the hacks
				var p = i.syntax.path;
				if (p.rest.length == 0) {
					printTextWithTrivia(p.first.text, p.first);
				} else {
					inline function lowerFirst(t:Token) {
						if (t.text == "Globals") { // hacky hack
							printTextWithTrivia(t.text, t);
						} else {
							printTextWithTrivia(t.text.charAt(0).toLowerCase() + t.text.substring(1), t);
						}
					}
					lowerFirst(p.first);
					for (i in 0...p.rest.length) {
						var part = p.rest[i];
						printDot(part.sep);
						if (i == p.rest.length - 1) {
							printTextWithTrivia(part.element.text, part.element);
						} else {
							lowerFirst(part.element);
						}
					}
				}
			}

			switch i.kind {
				case TIDecl(_):
				case TIAliased(d, as, name):
					printTextWithTrivia("as", as);
					printTextWithTrivia(name.text, name);
				case TIAll(_, dot, asterisk):
					printDot(dot);
					printTextWithTrivia("*", asterisk);
			}
			printSemicolon(i.syntax.semicolon);
		}
		if (i.syntax.condCompEnd != null) printCompCondEnd(i.syntax.condCompEnd);
	}

	function printDecl(d:TDecl) {
		switch (d.kind) {
			case TDClassOrInterface(c = {kind: TClass(info)}): printClassDecl(c, info);
			case TDClassOrInterface(i = {kind: TInterface(info)}): printInterfaceDecl(i, info);
			case TDVar(v): printModuleVarDecl(v);
			case TDFunction(f): printFunctionDecl(f);
			case TDNamespace(n): printNamespace(n);
		}
	}

	function printNamespace(ns:NamespaceDecl) {
		printDeclModifiers(ns.modifiers);
		printTextWithTrivia("namespace", ns.keyword);
		printTextWithTrivia(ns.name.text, ns.name);
		printSemicolon(ns.semicolon);
	}

	function printFunctionDecl(f:TFunctionDecl) {
		printMetadata(f.metadata);
		printDeclModifiers(f.modifiers);
		printTextWithTrivia("function", f.syntax.keyword);
		printTextWithTrivia(f.name, f.syntax.name);
		printSignature(f.fun.sig);
		printExpr(f.fun.expr);
	}

	function printModuleVarDecl(v:TModuleVarDecl) {
		printMetadata(v.metadata);
		printDeclModifiers(v.modifiers);
		printVarField(v);
	}

	function printInterfaceDecl(i:TClassOrInterfaceDecl, info:TInterfaceDeclInfo) {
		printMetadata(i.metadata);
		printDeclModifiers(i.modifiers);
		printTextWithTrivia("interface", i.syntax.keyword);
		printTextWithTrivia(i.name, i.syntax.name);
		if (info.extend != null) {
			printTextWithTrivia("extends", info.extend.keyword);
			for (i in info.extend.interfaces) {
				printDotPath(i.iface.syntax);
				if (i.comma != null) printComma(i.comma);
			}
		}
		printOpenBrace(i.syntax.openBrace);

		for (m in i.members) {
			switch (m) {
				case TMField(field):
					switch field.kind {
						case TFFun(f):
							printMetadata(field.metadata);
							printTextWithTrivia("function", f.syntax.keyword);
							printTextWithTrivia(f.name, f.syntax.name);
							printSignature(f.fun.sig);
							printSemicolon(f.semicolon.sure());

						case TFGetter(_) | TFSetter(_):
							printHaxeProperty(field);

						case TFVar(_):
							throw "assert";
					}
				case TMCondCompBegin(b): printCondCompBegin(b);
				case TMCondCompEnd(b): printCompCondEnd(b);
				case TMStaticInit(_) | TMUseNamespace(_):
					throw "assert";
			}
		}

		printCloseBrace(i.syntax.closeBrace);
	}

	function printClassDecl(c:TClassOrInterfaceDecl, info:TClassDeclInfo) {
		printMetadata(c.metadata);
		printDeclModifiers(c.modifiers);
		printTextWithTrivia("class", c.syntax.keyword);
		printTextWithTrivia(c.name, c.syntax.name);
		if (info.extend != null) {
			printTextWithTrivia("extends", info.extend.syntax.keyword);
			printDotPath(info.extend.syntax.path);
		}
		if (info.implement != null) {
			printTextWithTrivia("implements", info.implement.keyword);
			printDotPath(info.implement.interfaces[0].iface.syntax);
			for (i in 1...info.implement.interfaces.length) {
				var prevComma = info.implement.interfaces[i - 1].comma;
				if (prevComma != null) printTextWithTrivia("", prevComma); // don't lose comments around comma, if there are any

				var i = info.implement.interfaces[i];
				buf.add(" implements ");
				printDotPath(i.iface.syntax);
			}
		}
		printOpenBrace(c.syntax.openBrace);

		for (m in c.members) {
			switch (m) {
				case TMCondCompBegin(b): printCondCompBegin(b);
				case TMCondCompEnd(b): printCompCondEnd(b);
				case TMField(f): printClassField(c.name, f);
				case TMUseNamespace(n, semicolon): printUseNamespace(n); printTextWithTrivia("", semicolon);
				case TMStaticInit(i): trace("TODO: INIT EXPR FOR " + c.name);//printExpr(i.expr);
			}
		}

		printCloseBrace(c.syntax.closeBrace);
	}

	function printCondCompBegin(e:TCondCompBegin) {
		printTokenTrivia(e.v.syntax.ns);
		printTokenTrivia(e.v.syntax.sep);
		printTextWithTrivia("#if " + e.v.ns + "_" + e.v.name, e.v.syntax.name);
		printTokenTrivia(e.openBrace);
	}

	function printCompCondEnd(e:TCondCompEnd) {
		printTextWithTrivia("#end ", e.closeBrace);
	}

	function printDeclModifiers(modifiers:Array<DeclModifier>) {
		for (m in modifiers) {
			switch (m) {
				case DMPublic(t): printTokenTrivia(t);
				case DMInternal(t): printTextWithTrivia("/*internal*/", t);
				case DMFinal(t): printTextWithTrivia("final", t);
				case DMDynamic(t): printTextWithTrivia("/*dynamic*/", t);
			}
		}
	}

	function printHaxeProperty(f:TClassField) {
		switch f.kind {
			case TFGetter(a) | TFSetter(a) if (a.haxeProperty != null):
				var p = a.haxeProperty;
				printTrivia(p.syntax.leadTrivia);
				// if (p.isFlashProperty) TODO: re-enable the check for the final move to the converted code
					buf.add("@:flash.property ");
				if (p.isPublic) buf.add("public ");
				if (p.isStatic) buf.add("static ");
				buf.add("var ");
				buf.add(p.name);
				buf.add(if (p.get) "(get," else "(never,");
				buf.add(if (p.set) "set):" else "never):");
				printTType(p.type);
				buf.add(";\n");
			case _:
		}
	}

	function printClassField(className:String, f:TClassField) {
		printHaxeProperty(f);

		printMetadata(f.metadata);

		if (f.namespace != null) printTextWithTrivia("/*"+f.namespace.text+"*/", f.namespace);

		var isPublic = false;
		for (m in f.modifiers) {
			switch (m) {
				case FMPublic(t):
					isPublic = true;
					printTextWithTrivia("public", t);
				case FMPrivate(t) | FMProtected(t):
					t.trimTrailingWhitespace();
					printTokenTrivia(t);
				// case FMPrivate(t): printTextWithTrivia("private", t);
				// case FMProtected(t): printTextWithTrivia("/*protected*/private", t);
				case FMInternal(t): printTextWithTrivia("@:allow(" + currentModule.parentPack.name + ")", t);
				case FMOverride(t): printTextWithTrivia("override", t);
				case FMStatic(t): printTextWithTrivia("static", t);
				case FMFinal(t): printTextWithTrivia("final", t);
			}
		}

		if (!isPublic && f.namespace != null) buf.add("public "); // TODO: generate @:access on `use namespace` instead

		switch (f.kind) {
			case TFVar(v):
				printVarField(v);
			case TFFun(f):
				printTextWithTrivia("function", f.syntax.keyword);
				var isCtor = f.name == className;
				printTextWithTrivia(if (isCtor) "new" else f.name, f.syntax.name);
				printSignature(f.fun.sig, !isCtor);

				var trailTrivia = TypedTreeTools.removeTrailingTrivia(f.fun.expr);
				printExpr(f.fun.expr);
				if (needsSemicolon(f.fun.expr)) buf.add(";");
				printTrivia(trailTrivia);

			case TFGetter(f):
				printTextWithTrivia("function", f.syntax.functionKeyword);
				printTokenTrivia(f.syntax.accessorKeyword);
				printTextWithTrivia("get_" + f.name, f.syntax.name);
				printSignature(f.fun.sig);
				printExpr(f.fun.expr);
			case TFSetter(f):
				printTextWithTrivia("function", f.syntax.functionKeyword);
				printTokenTrivia(f.syntax.accessorKeyword);
				printTextWithTrivia("set_" + f.name, f.syntax.name);
				printSignature(f.fun.sig);
				printExpr(f.fun.expr);
		}
	}

	function printVarField(vf:TVarField) {
		switch vf.vars {
			case [v]:
				if (vf.isInline) buf.add("inline ");
				printVarKind(vf.kind);
				printTextWithTrivia(v.name, v.syntax.name);
				printTypeHint({type: v.type, syntax: v.syntax.type});
				if (v.init != null) printVarInit(v.init);
				if (v.comma != null) throw "assert";
				printSemicolon(vf.semicolon);
			case _:
				// TODO: it should be rewritten into multiple fields
				throw "multiple var declaration with a single keyword is not supported";
		}
	}

	function printMetadata(metas:Array<TMetadata>) {
		for (m in metas) {
			switch m {
				case MetaFlash(m):
					printTokenTrivia(m.openBracket);
					buf.add("@:meta(");
					printTextWithTrivia(m.name.text, m.name);
					if (m.args == null) {
						buf.add("()");
					} else {
						var p = new Printer();
						p.printCallArgs(m.args);
						buf.add(p.toString());
					}
					buf.add(")");
					printTokenTrivia(m.closeBracket);
				case MetaHaxe(s):
					buf.add(s);
					buf.add(" ");
			}
		}
	}

	function printSignature(sig:TFunctionSignature, printReturnType = true) {
		printOpenParen(sig.syntax.openParen);
		for (arg in sig.args) {
			switch (arg.kind) {
				case TArgNormal(hint, init):
					printTextWithTrivia(arg.name, arg.syntax.name);
					printTypeHint({type: arg.type, syntax: hint});
					if (init != null) printVarInit(init);

				case TArgRest(dots, _):
					// TODO: throw, as this should be rewritten
					printTextWithTrivia("...", dots);
					printTextWithTrivia(arg.name, arg.syntax.name);
			}
			if (arg.comma != null) printComma(arg.comma);
		}
		printCloseParen(sig.syntax.closeParen);
		if (printReturnType) {
			printTypeHint(sig.ret);
		}
	}

	function printTType(t:TType) {
		switch t {
			case TTVoid: buf.add("Void");
			case TTAny: buf.add("ASAny");
			case TTBoolean: buf.add("Bool");
			case TTNumber: buf.add("Float");
			case TTInt: buf.add("Int");
			case TTUint: buf.add("UInt");
			case TTString: buf.add("String");
			case TTArray(t): buf.add("Array<"); printTType(t); buf.add(">");
			case TTFunction: buf.add("ASFunction");
			case TTClass: buf.add("Class<Dynamic>");
			case TTObject(TTAny): buf.add("ASObject");
			case TTObject(t): buf.add("haxe.DynamicAccess<"); printTType(t); buf.add(">");
			case TTXML: buf.add("flash.xml.XML");
			case TTXMLList: buf.add("flash.xml.XMLList");
			case TTRegExp: buf.add("flash.utils.RegExp");
			case TTVector(t): buf.add("flash.Vector<"); printTType(t); buf.add(">");
			case TTDictionary(k, v): buf.add("ASDictionary<"); printTType(k); buf.add(","); printTType(v); buf.add(">");
			case TTBuiltin: buf.add("TODO");
			case TTFun(args, ret, rest):
				if (args.length == 0) {
					buf.add("Void->");
				} else {
					for (arg in args) {
						printTType(arg);
						buf.add("->");
					}
				}
				printTType(ret);

			case TTInst(cls):
				buf.add(getClassLocalPath(cls));
			case TTStatic(cls):
				buf.add("Class<" + getClassLocalPath(cls) + ">");
		}
	}

	inline function getClassLocalPath(cls:TClassOrInterfaceDecl):String {
		return if (currentModule.isImported(cls)) cls.name else makeFQN(cls);
	}

	static function makeFQN(cls:TClassOrInterfaceDecl) {
		var packName = cls.parentModule.parentPack.name;
		return if (packName == "") cls.name else packName + "." + cls.name;
	}

	function printTypeHint(hint:TTypeHint) {
		if (hint.syntax != null) {
			printColon(hint.syntax.colon);
			printTrivia(ParseTree.getSyntaxTypeLeadingTrivia(hint.syntax.type));
		} else {
			buf.add(":");
		}
		printTType(hint.type);
		if (hint.syntax != null) {
			printTrivia(ParseTree.getSyntaxTypeTrailingTrivia(hint.syntax.type));
		}
	}

	function printExpr(e:TExpr) {
		var needsCast =
			switch [e.type, e.expectedType] {
				case [TTFunction, TTFun(_)]: true; // Function from AS3 code unified with proper function type

				case [TTFun([argType], _, _), TTFun([TTAny], _)] if (argType != TTAny): true; // add/remove event listener

				case [TTArray(TTAny), TTArray(TTAny)]: false; // untyped arrays
				case [TTArray(elemType), TTArray(TTAny)]: true; // typed array to untyped array
				case [TTArray(TTAny), TTArray(elemType)]: !e.kind.match(TEArrayDecl(_)); // untyped array to typed array (array decls are fine tho)

				case [TTDictionary(TTAny, TTAny), TTDictionary(TTAny, TTAny)]: false; // untyped dicts
				case [TTDictionary(k, v), TTDictionary(TTAny, TTAny)]: true; // typed dicts into untyped dict
				case [TTDictionary(TTAny, TTAny), TTDictionary(k, v)]: true; // untyped dicts into typed dict

				case _: false;
			};

		var trailTrivia:Null<Array<Trivia>> = null;
		if (needsCast) {
			printTrivia(TypedTreeTools.removeLeadingTrivia(e));
			trailTrivia = TypedTreeTools.removeTrailingTrivia(e);
			buf.add("(cast ");
		}

		switch (e.kind) {
			case TEParens(openParen, e, closeParen): printOpenParen(openParen); printExpr(e); printCloseParen(closeParen);
			case TECast(c): printCast(c);
			case TELocalFunction(f): printLocalFunction(f);
			case TELiteral(l): printLiteral(l);
			case TELocal(syntax, v): printTextWithTrivia(syntax.text, syntax);
			case TEField(object, fieldName, fieldToken): printFieldAccess(object, fieldName, fieldToken);
			case TEBuiltin(syntax, name): printBuiltin(syntax, name);
			case TEDeclRef(dotPath, c): printDotPath(dotPath);
			case TECall(eobj, args): printExpr(eobj); printCallArgs(args);
			case TEArrayDecl(d): printArrayDecl(d);
			case TEVectorDecl(v): printVectorDecl(v);
			case TEReturn(keyword, e): printTextWithTrivia("return", keyword); if (e != null) printExpr(e);
			case TEThrow(keyword, e): printTextWithTrivia("throw", keyword); printExpr(e);
			case TEDelete(keyword, e): throw "assert";
			case TEBreak(keyword): printTextWithTrivia("break", keyword);
			case TEContinue(keyword): printTextWithTrivia("continue", keyword);
			case TEVars(kind, vars): printVars(kind, vars);
			case TEObjectDecl(o): printObjectDecl(o);
			case TEArrayAccess(a): printArrayAccess(a);
			case TEBlock(block): printBlock(block);
			case TETry(t): printTry(t);
			case TEVector(syntax, type):
				printTextWithTrivia("flash.Vector", syntax.name);
				printTrivia(syntax.dot.leadTrivia);
				printTrivia(syntax.dot.trailTrivia);
				printTextWithTrivia("<", syntax.t.lt);
				printTrivia(ParseTree.getSyntaxTypeLeadingTrivia(syntax.t.type));
				printTType(type);
				printTrivia(ParseTree.getSyntaxTypeTrailingTrivia(syntax.t.type));
				printTextWithTrivia(">", syntax.t.gt);

			case TETernary(t): printTernary(t);
			case TEIf(i): printIf(i);
			case TEWhile(w): printWhile(w);
			case TEDoWhile(w): printDoWhile(w);
			case TEHaxeFor(f): printFor(f);
			case TEFor(_) | TEForIn(_) | TEForEach(_): throw "unprocessed `for` expression";
			case TEBinop(a, OpComma(t), b): printCommaOperator(a, t, b);
			case TEBinop(a, op, b): printBinop(a, op, b);
			case TEPreUnop(op, e): printPreUnop(op, e);
			case TEPostUnop(e, op): printPostUnop(e, op);
			case TESwitch(s): printSwitch(s);
			case TENew(keyword, eclass, args): printNew(keyword, eclass, args);
			case TECondCompValue(v): printCondCompVar(v);
			case TECondCompBlock(v, expr): printCondCompBlock(v, expr);
			case TEAs(_): throw "unprocessed `as` expression";
			case TEXmlChild(_) | TEXmlAttr(_) | TEXmlAttrExpr(_) | TEXmlDescend(_): throw 'unprocessed E4X';
			case TEUseNamespace(ns): printUseNamespace(ns);
			case TEHaxeIntIter(start, end):
				printExpr(start);
				buf.add("...");
				printExpr(end);
			case TEHaxeRetype(einner):
				printTrivia(TypedTreeTools.removeLeadingTrivia(einner));
				buf.add("(");
				var trail = TypedTreeTools.removeTrailingTrivia(einner);
				printExpr(einner);
				buf.add(" : ");
				printTType(e.type);
				buf.add(")");
				printTrivia(trail);
		}

		if (needsCast) {
			buf.add(")");
			if (trailTrivia != null) printTrivia(trailTrivia);
		}
	}

	function printBuiltin(token:Token, name:String) {
		// TODO: this is hacky (builtins in general are hacky...)
		name = switch name {
			case
				"Std.is" | "Std.instance" | "Std.int" | "Std.string" | "String"
				| "flash.Vector.convert"| "flash.Vector.ofArray"
				| "Reflect.deleteField" | "Type.createInstance"
				| "haxe.Json" | "Reflect.compare"
				| "StringTools.replace" | "StringTools.hex" | "Reflect.callMethod":
					name;
			case "Number": "Float";
			case "int": "Int";
			case "uint": "UInt";
			case "Boolean": "Bool";
			case "Object": "ASObject";
			case "XML": "flash.xml.XML";
			case "XMLList": "flash.xml.XMLList";
			case "Vector": "flash.Vector";
			case "Array": "Array";
			case "RegExp": "flash.utils.RegExp";
			case "parseInt": "Std.parseInt";
			case "parseFloat": "Std.parseFloat";
			case "NaN": "Math.NaN";
			case "isNaN": "Math.isNaN";
			case "escape": "escape";
			case "arguments": "/*TODO*/arguments";
			case "trace": "trace";
			case "untyped __global__": "untyped __global__";
			case _ if (name.startsWith("ASCompat.")): name;
			case _:
				throw "unknown builtin: " + name;
		}
		printTextWithTrivia(name, token);
	}

	function printCast(c:TCast) {
		printTrivia(ParseTree.getDotPathLeadingTrivia(c.syntax.path));
		buf.add("cast");
		printOpenParen(c.syntax.openParen);
		printExpr(c.expr);
		buf.add(", ");
		printTType(c.type);
		printTrivia(ParseTree.getDotPathTrailingTrivia(c.syntax.path));
		printCloseParen(c.syntax.closeParen);
	}

	function printLocalFunction(f:TLocalFunction) {
		printTextWithTrivia("function", f.syntax.keyword);
		if (f.name != null) printTextWithTrivia(f.name.name, f.name.syntax);
		printSignature(f.fun.sig);
		printExpr(f.fun.expr);
	}

	function printSwitch(s:TSwitch) {
		printTextWithTrivia("switch", s.syntax.keyword);
		printOpenParen(s.syntax.openParen);
		printExpr(s.subj);
		printCloseParen(s.syntax.closeParen);
		printOpenBrace(s.syntax.openBrace);
		for (c in s.cases) {
			printTextWithTrivia("case", c.syntax.keyword);
			var first = true;
			for (e in c.values) {
				if (first) {
					first = false;
				} else {
					printTrivia(TypedTreeTools.removeLeadingTrivia(e));
					buf.add("   | ");
				}
				printExpr(e);
			}
			printColon(c.syntax.colon);
			for (e in c.body) {
				printBlockExpr(e);
			}
		}
		if (s.def != null) {
			printTextWithTrivia("default", s.def.syntax.keyword);
			printColon(s.def.syntax.colon);
			for (e in s.def.body) {
				printBlockExpr(e);
			}
		}
		printCloseBrace(s.syntax.closeBrace);
	}

	function printCondCompBlock(v:TCondCompVar, expr:TExpr) {
		switch expr.kind {
			case TEBlock(block):
				printTokenTrivia(v.syntax.ns);
				printTokenTrivia(v.syntax.sep);
				printTextWithTrivia("#if " + v.ns + "_" + v.name, v.syntax.name);
				printOpenBrace(block.syntax.openBrace);
				for (e in block.exprs) printBlockExpr(e);
				printTextWithTrivia("} #end", block.syntax.closeBrace);
			case _:
				throw "assert";
		}
	}

	function printCondCompVar(v:TCondCompVar) {
		printTokenTrivia(v.syntax.ns);
		printTokenTrivia(v.syntax.sep);
		buf.add(v.ns + "_" + v.name);
		printTokenTrivia(v.syntax.name);
	}

	function printUseNamespace(ns:UseNamespace) {
		printTextWithTrivia("/*use*/", ns.useKeyword);
		printTextWithTrivia("/*namespace*/", ns.namespaceKeyword);
		printTextWithTrivia("/*" + ns.name.text + "*/", ns.name);
	}

	function printTry(t:TTry) {
		printTextWithTrivia("try", t.keyword);
		printExpr(t.expr);
		for (c in t.catches) {
			printTextWithTrivia("catch", c.syntax.keyword);
			printOpenParen(c.syntax.openParen);
			printTextWithTrivia(c.v.name, c.syntax.name);
			printTypeHint({type: c.v.type, syntax: c.syntax.type});
			printCloseParen(c.syntax.closeParen);
			printExpr(c.expr);
		}
	}

	function printWhile(w:TWhile) {
		printTextWithTrivia("while", w.syntax.keyword);
		printOpenParen(w.syntax.openParen);
		printExpr(w.cond);
		printCloseParen(w.syntax.closeParen);
		printExpr(w.body);
	}

	function printDoWhile(w:TDoWhile) {
		printTextWithTrivia("do", w.syntax.doKeyword);
		printExpr(w.body);
		printTextWithTrivia("while", w.syntax.whileKeyword);
		printOpenParen(w.syntax.openParen);
		printExpr(w.cond);
		printCloseParen(w.syntax.closeParen);
	}

	function printFor(f:THaxeFor) {
		printTextWithTrivia("for", f.syntax.forKeyword);
		printOpenParen(f.syntax.openParen);
		printTextWithTrivia(f.vit.name, f.syntax.itName);
		printTextWithTrivia("in", f.syntax.inKeyword);
		printExpr(f.iter);
		printCloseParen(f.syntax.closeParen);
		printExpr(f.body);
	}

	function printNew(keyword:Token, eclass:TExpr, args:Null<TCallArgs>) {
		printTextWithTrivia("new", keyword);
		switch (eclass.kind) {
			case TEDeclRef(_) | TEVector(_) | TEBuiltin(_): printExpr(eclass);
			case other: throw "unprocessed expr for `new`: " + other;
		}
		if (args != null) printCallArgs(args) else buf.add("()");
	}

	function printVectorDecl(d:TVectorDecl) {
		printTrivia(d.syntax.newKeyword.leadTrivia);
		buf.add("flash.Vector.ofArray((");
		var trailTrivia = d.elements.syntax.closeBracket.trailTrivia;
		d.elements.syntax.closeBracket.trailTrivia = [];
		printArrayDecl(d.elements);
		buf.add(":Array<");
		printTType(d.type);
		buf.add(">))");
		printTrivia(trailTrivia);
	}

	function printArrayDecl(d:TArrayDecl) {
		printOpenBracket(d.syntax.openBracket);
		for (e in d.elements) {
			printExpr(e.expr);
			if (e.comma != null) printComma(e.comma);
		}
		printCloseBracket(d.syntax.closeBracket);
	}

	function printCallArgs(args:TCallArgs) {
		printOpenParen(args.openParen);
		for (a in args.args) {
			printExpr(a.expr);
			if (a.comma != null) printComma(a.comma);
		}
		printCloseParen(args.closeParen);
	}

	function printTernary(t:TTernary) {
		printExpr(t.econd);
		printTextWithTrivia("?", t.syntax.question);
		printExpr(t.ethen);
		printColon(t.syntax.colon);
		printExpr(t.eelse);
	}

	function printIf(i:TIf) {
		printTextWithTrivia("if", i.syntax.keyword);
		printOpenParen(i.syntax.openParen);
		printExpr(i.econd);
		printCloseParen(i.syntax.closeParen);
		printExpr(i.ethen);
		if (i.eelse != null) {
			printTextWithTrivia("else", i.eelse.keyword);
			printExpr(i.eelse.expr);
		}
	}

	function printPreUnop(op:PreUnop, e:TExpr) {
		switch (op) {
			case PreNot(t): printTextWithTrivia("!", t);
			case PreNeg(t): printTextWithTrivia("-", t);
			case PreIncr(t): printTextWithTrivia("++", t);
			case PreDecr(t): printTextWithTrivia("--", t);
			case PreBitNeg(t): printTextWithTrivia("~", t);
		}
		printExpr(e);
	}

	function printPostUnop(e:TExpr, op:PostUnop) {
		printExpr(e);
		switch (op) {
			case PostIncr(t): printTextWithTrivia("++", t);
			case PostDecr(t): printTextWithTrivia("--", t);
		}
	}

	function printCommaOperator(a:TExpr, comma:Token, b:TExpr) {
		// TODO: flatten nested commas (maybe this should be a filter...)
		printTrivia(TypedTreeTools.removeLeadingTrivia(a));
		buf.add("{");
		printExpr(a);
		printSemicolon(comma);
		printExpr(b);
		buf.add(";}");
		printTrivia(TypedTreeTools.removeTrailingTrivia(b));
	}

	function printBinop(a:TExpr, op:Binop, b:TExpr) {
		printExpr(a);
		switch (op) {
			case OpAdd(t): printTextWithTrivia("+", t);
			case OpSub(t): printTextWithTrivia("-", t);
			case OpDiv(t): printTextWithTrivia("/", t);
			case OpMul(t): printTextWithTrivia("*", t);
			case OpMod(t): printTextWithTrivia("%", t);
			case OpAssign(t): printTextWithTrivia("=", t);
			case OpAssignOp(AOpAdd(t)): printTextWithTrivia("+=", t);
			case OpAssignOp(AOpSub(t)): printTextWithTrivia("-=", t);
			case OpAssignOp(AOpMul(t)): printTextWithTrivia("*=", t);
			case OpAssignOp(AOpDiv(t)): printTextWithTrivia("/=", t);
			case OpAssignOp(AOpMod(t)): printTextWithTrivia("%=", t);
			case OpAssignOp(AOpAnd(t)): printTextWithTrivia("&&=", t);
			case OpAssignOp(AOpOr(t)): printTextWithTrivia("||=", t);
			case OpAssignOp(AOpBitAnd(t)): printTextWithTrivia("&=", t);
			case OpAssignOp(AOpBitOr(t)): printTextWithTrivia("|=", t);
			case OpAssignOp(AOpBitXor(t)): printTextWithTrivia("^=", t);
			case OpAssignOp(AOpShl(t)): printTextWithTrivia("<<=", t);
			case OpAssignOp(AOpShr(t)): printTextWithTrivia(">>=", t);
			case OpAssignOp(AOpUshr(t)): printTextWithTrivia(">>>=", t);
			case OpEquals(t): printTextWithTrivia("==", t);
			case OpNotEquals(t): printTextWithTrivia("!=", t);
			case OpStrictEquals(t): printTextWithTrivia("==", t);
			case OpNotStrictEquals(t): printTextWithTrivia("!=", t);
			case OpGt(t): printTextWithTrivia(">", t);
			case OpGte(t): printTextWithTrivia(">=", t);
			case OpLt(t): printTextWithTrivia("<", t);
			case OpLte(t): printTextWithTrivia("<=", t);
			case OpIn(t): printTextWithTrivia("in", t);
			case OpAnd(t): printTextWithTrivia("&&", t);
			case OpOr(t): printTextWithTrivia("||", t);
			case OpShl(t): printTextWithTrivia("<<", t);
			case OpShr(t): printTextWithTrivia(">>", t);
			case OpUshr(t): printTextWithTrivia(">>>", t);
			case OpBitAnd(t): printTextWithTrivia("&", t);
			case OpBitOr(t): printTextWithTrivia("|", t);
			case OpBitXor(t): printTextWithTrivia("^", t);
			case OpComma(t): printTextWithTrivia(",", t);
			case OpIs(t): throw "assert";
		}
		printExpr(b);
	}

	function printArrayAccess(a:TArrayAccess) {
		printExpr(a.eobj);
		printOpenBracket(a.syntax.openBracket);
		printExpr(a.eindex);
		printCloseBracket(a.syntax.closeBracket);
	}

	function printVarKind(kind:VarDeclKind) {
		switch (kind) {
			case VVar(t): printTextWithTrivia("var", t);
			case VConst(t): printTextWithTrivia("final", t);
		}
	}

	function printVars(kind:VarDeclKind, vars:Array<TVarDecl>) {
		printVarKind(kind);
		for (v in vars) {
			printTextWithTrivia(v.v.name, v.syntax.name);

			// TODO: skip type hint if there's an initializer with exactly the same type
			// if (v.init == null || !Type.enumEq(v.v.type, v.init.expr.type)) {
				printTypeHint({type: v.v.type, syntax: v.syntax.type});
			// }

			if (v.init != null) printVarInit(v.init);
			if (v.comma != null) printComma(v.comma);
		}
	}

	function printVarInit(init:TVarInit) {
		printTextWithTrivia("=", init.equalsToken);
		printExpr(init.expr);
	}

	function printObjectDecl(o:TObjectDecl) {
		printOpenBrace(o.syntax.openBrace);
		for (f in o.fields) {
			printTextWithTrivia(f.name, f.syntax.name); // TODO: quoted fields
			printColon(f.syntax.colon);
			printExpr(f.expr);
			if (f.syntax.comma != null) printComma(f.syntax.comma);
		}
		printCloseBrace(o.syntax.closeBrace);
	}

	function printFieldAccess(obj:TFieldObject, name:String, token:Token) {
		switch (obj.kind) {
			case TOExplicit(dot, e):
				printExpr(e);

				printTrivia(dot.leadTrivia);
				printTrivia(dot.trailTrivia); // haxe doesn't support some.<whitespace>fieldName, so we move whitespace before the dot (hopefully there won't be any line comments)
				printTrivia(token.leadTrivia);
				buf.add(".");

			case TOImplicitThis(_) | TOImplicitClass(_):
				printTrivia(token.leadTrivia);
		}
		buf.add(name);
		printTrivia(token.trailTrivia);
	}

	function printLiteral(l:TLiteral) {
		switch (l) {
			case TLSuper(syntax): printTextWithTrivia("super", syntax);
			case TLThis(syntax): printTextWithTrivia("this", syntax);
			case TLBool(syntax): printTextWithTrivia(syntax.text, syntax);
			case TLNull(syntax): printTextWithTrivia("null", syntax);
			case TLUndefined(syntax): printTextWithTrivia("/*undefined*/null", syntax);
			case TLInt(syntax): printTextWithTrivia(syntax.text, syntax);
			case TLNumber(syntax): printTextWithTrivia(syntax.text, syntax);
			case TLString(syntax): printTextWithTrivia(syntax.text, syntax);
			case TLRegExp(syntax): throw "assert";
		}
	}

	function printBlock(block:TBlock) {
		printOpenBrace(block.syntax.openBrace);
		for (e in block.exprs) {
			printBlockExpr(e);
		}
		printCloseBrace(block.syntax.closeBrace);
	}

	function printBlockExpr(e:TBlockExpr) {
		printExpr(e.expr);
		if (e.semicolon != null) {
			if (e.expr.kind.match(TEUseNamespace(_) | TEBinop(_, OpComma(_), _))) {
				printTrivia(e.semicolon.leadTrivia);
				printTrivia(e.semicolon.trailTrivia);
			} else {
				printSemicolon(e.semicolon);
			}
		} else if (needsSemicolon(e.expr)) {
			buf.add(";");
		}
	}

	static function needsSemicolon(e:TExpr) {
		return switch e.kind {
			case TEBlock(_) | TECondCompBlock(_) | TETry(_) | TESwitch(_) | TEUseNamespace(_) | TEBinop(_, OpComma(_), _):
				false;
			case TEIf(i):
				needsSemicolon(if (i.eelse != null) i.eelse.expr else i.ethen);
			case TEHaxeFor({body: b}), TEFor({body: b}) | TEForIn({body: b}) | TEForEach({body: b}) | TEWhile({body: b}) | TEDoWhile({body: b}):
				needsSemicolon(b);
			case TELocalFunction(f):
				needsSemicolon(f.fun.expr);
			case _:
				true;
		}
	}

	inline function printTokenTrivia(t:Token) {
		printTrivia(t.leadTrivia);
		printTrivia(t.trailTrivia);
	}
}
