package ax3;

import ax3.ParseTree;
import ax3.TypedTree;
import ax3.Token.Trivia;

typedef RegisterPropertyCallback = (name:String, set:Bool, isPublic:Bool, type:TType)->Void;

@:nullSafety
class GenHaxe extends PrinterBase {
	public function writeModule(m:TModule) {
		printPackage(m.pack);
		for (d in m.privateDecls) {
			printDecl(d);
		}
		printTrivia(m.eof.leadTrivia);
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
		printTextWithTrivia("import", i.syntax.keyword);
		printDotPath(i.syntax.path);
		switch i.kind {
			case TIDecl(_):
			case TIAliased(d, as, name):
				printTextWithTrivia("as", as);
				printTextWithTrivia(name.text, name);
			case TIAll(dot, asterisk):
				printDot(dot);
				printTextWithTrivia("*", asterisk);
		}
		printSemicolon(i.syntax.semicolon);
		if (i.syntax.condCompEnd != null) printCompCondEnd(i.syntax.condCompEnd);
	}

	function printDecl(d:TDecl) {
		switch (d) {
			case TDClass(c): printClassDecl(c);
			case TDInterface(i): printInterfaceDecl(i);
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

	function printInterfaceDecl(i:TInterfaceDecl) {
		printMetadata(i.metadata);
		printDeclModifiers(i.modifiers);
		printTextWithTrivia("interface", i.syntax.keyword);
		printTextWithTrivia(i.name, i.syntax.name);
		if (i.extend != null) {
			printTextWithTrivia("extends", i.extend.syntax.keyword);
			for (i in i.extend.interfaces) {
				printDotPath(i.syntax);
				if (i.comma != null) printComma(i.comma);
			}
		}
		printOpenBrace(i.syntax.openBrace);

		// TODO: not generate properties that are already present in parent classes... we might have to do this properly in a separate pass....
		var properties = new Map();
		function prop(name:String, set:Bool, meta:Array<Metadata>, trivia:Array<Trivia>, type:TType) {
			var p = switch properties[name] {
				case null: properties[name] = {trivia: [], meta: [], get: false, set: false, type: type};
				case existing: existing;
			};
			p.meta = p.meta.concat(meta);
			p.trivia = p.trivia.concat(trivia);
			if (set) p.set = true else p.get = true;
		}

		for (m in i.members) {
			switch (m) {
				case TIMField(field):
					switch field.kind {
						case TIFFun(f):
							printMetadata(field.metadata);
							printTextWithTrivia("function", f.syntax.keyword);
							printTextWithTrivia(f.name, f.syntax.name);
							printSignature(f.sig);
							printSemicolon(field.semicolon);

						case TIFGetter(f):
							prop(f.name, false, field.metadata, f.syntax.functionKeyword.leadTrivia.concat(field.semicolon.trailTrivia), f.sig.ret.type);

						case TIFSetter(f):
							prop(f.name, true, field.metadata, f.syntax.functionKeyword.leadTrivia.concat(field.semicolon.trailTrivia), f.sig.args[0].type);
					}
				case TIMCondCompBegin(b): printCondCompBegin(b);
				case TIMCondCompEnd(b): printCompCondEnd(b);
			}
		}

		for (name => desc in properties) {
			printTrivia(desc.trivia);
			printMetadata(desc.meta);
			buf.add("var ");
			buf.add(name);
			buf.add(if (desc.get) "(get," else "(never,");
			buf.add(if (desc.set) "set):" else "never):");
			printTType(desc.type);
			buf.add(";\n");
		}

		printCloseBrace(i.syntax.closeBrace);
	}

	function printClassDecl(c:TClassDecl) {
		printMetadata(c.metadata);
		printDeclModifiers(c.modifiers);
		printTextWithTrivia("class", c.syntax.keyword);
		printTextWithTrivia(c.name, c.syntax.name);
		if (c.extend != null) {
			printTextWithTrivia("extends", c.extend.syntax.keyword);
			printDotPath(c.extend.syntax.path);
		}
		if (c.implement != null) {
			printTextWithTrivia("implements", c.implement.syntax.keyword);
			for (i in c.implement.interfaces) {
				printDotPath(i.syntax);
				if (i.comma != null) printComma(i.comma);
			}
		}
		printOpenBrace(c.syntax.openBrace);

		var properties = new Map();
		function registerProperty(name:String, set:Bool, isPublic:Bool, type:TType) {
			var prop = switch properties[name] {
				case null: properties[name] = {get: false, set: false, isPublic: false, type: type};
				case existing: existing;
			}
			if (set) prop.set = true else prop.get = true;
			if (isPublic) prop.isPublic = true;
		}

		for (m in c.members) {
			switch (m) {
				case TMCondCompBegin(b): printCondCompBegin(b);
				case TMCondCompEnd(b): printCompCondEnd(b);
				case TMField(f): printClassField(c.name, f, registerProperty);
				case TMUseNamespace(n, semicolon): printUseNamespace(n); printTextWithTrivia("", semicolon);
				case TMStaticInit(i): trace("TODO: INIT EXPR FOR " + c.name);//printExpr(i.expr);
			}
		}

		for (name => desc in properties) {
			if (desc.isPublic) buf.add("public ");
			buf.add("var ");
			buf.add(name);
			buf.add(if (desc.get) "(get," else "(never,");
			buf.add(if (desc.set) "set):" else "never):");
			printTType(desc.type);
			buf.add(";\n");
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
		printTextWithTrivia("#end", e.closeBrace);
	}

	function printDeclModifiers(modifiers:Array<DeclModifier>) {
		for (m in modifiers) {
			switch (m) {
				case DMPublic(t): printTokenTrivia(t);
				case DMInternal(t): printTextWithTrivia("/*internal*/", t);
				case DMFinal(t): printTextWithTrivia("@:final", t);
				case DMDynamic(t): printTextWithTrivia("/*dynamic*/", t);
			}
		}
	}

	function printClassField(className:String, f:TClassField, registerProperty:RegisterPropertyCallback) {
		printMetadata(f.metadata);

		if (f.namespace != null) printTextWithTrivia("/*"+f.namespace.text+"*/", f.namespace);

		var isPublic = false;
		for (m in f.modifiers) {
			switch (m) {
				case FMPublic(t):
					isPublic = true;
					printTextWithTrivia("public", t);
				case FMPrivate(t): printTextWithTrivia("private", t);
				case FMProtected(t): printTextWithTrivia("/*protected*/private", t);
				case FMInternal(t): printTextWithTrivia("/*internal*/", t);
				case FMOverride(t): printTextWithTrivia("override", t);
				case FMStatic(t): printTextWithTrivia("static", t);
				case FMFinal(t): printTextWithTrivia("/*final*/", t); // TODO: in haxe3 @:final should go before other modifiers
			}
		}

		switch (f.kind) {
			case TFVar(v):
				printVarField(v);
			case TFFun(f):
				printTextWithTrivia("function", f.syntax.keyword);
				var isCtor = f.name == className;
				printTextWithTrivia(if (isCtor) "new" else f.name, f.syntax.name);
				printSignature(f.fun.sig, !isCtor);
				printExpr(f.fun.expr);
			case TFGetter(f):
				printTextWithTrivia("function", f.syntax.functionKeyword);
				printTokenTrivia(f.syntax.accessorKeyword);
				printTextWithTrivia("get_" + f.name, f.syntax.name);
				printSignature(f.fun.sig);
				printExpr(f.fun.expr);
				registerProperty(f.name, false, isPublic, f.fun.sig.ret.type);
			case TFSetter(f):
				printTextWithTrivia("function", f.syntax.functionKeyword);
				printTokenTrivia(f.syntax.accessorKeyword);
				printTextWithTrivia("set_" + f.name, f.syntax.name);
				printSignature(f.fun.sig);
				printExpr(f.fun.expr);
				registerProperty(f.name, true, isPublic, f.fun.sig.args[0].type);
			case TFHaxeProp(f):
				printTrivia(f.syntax.leadTrivia);
				buf.add("var ");
				buf.add(f.name);
				buf.add(if (f.get) "(get," else "(never,");
				buf.add(if (f.set) "set):" else "never):");
				printTType(f.type);
				buf.add(";\n");
		}
	}

	function printVarField(v:TVarField) {
		printVarKind(v.kind);
		for (v in v.vars) {
			printTextWithTrivia(v.name, v.syntax.name);
			if (v.syntax.type != null) {
				// printSyntaxTypeHint(v.syntax.type);
				printColon(v.syntax.type.colon);
			} else {
				buf.add(":");
			}
			printTType(v.type);
			if (v.init != null) printVarInit(v.init);
			if (v.comma != null) printComma(v.comma);
		}
		printSemicolon(v.semicolon);
	}

	function printMetadata(metas:Array<Metadata>) {
		for (m in metas) {
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
		}
	}

	function printSignature(sig:TFunctionSignature, printReturnType = true) {
		printOpenParen(sig.syntax.openParen);
		for (arg in sig.args) {
			switch (arg.kind) {
				case TArgNormal(hint, init):
					printTextWithTrivia(arg.name, arg.syntax.name);
					if (hint != null) {
						printColon(hint.colon);
					} else {
						buf.add(":");
					}
					printTType(arg.type);
					// if (hint != null) printSyntaxTypeHint(hint);
					if (init != null) printVarInit(init);

				case TArgRest(dots):
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

	function printTypeHint(hint:TTypeHint) {
		if (hint.syntax != null) {
			// printSyntaxTypeHint(hint.syntax);
			printColon(hint.syntax.colon);
		} else {
			buf.add(":");
		}
		// TODO don't forget trivia
		printTType(hint.type);
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
			case TTFunction: buf.add("haxe.Constraints.Function");
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

			case TTInst(cls): buf.add(cls.name);
			case TTStatic(cls): buf.add("Class<" + cls.name + ">");
		}
	}

	function printSyntaxTypeHint(t:TypeHint) {
		printColon(t.colon);
		printSyntaxType(t.type);
	}

	function printExpr(e:TExpr) {
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
				buf.add("flash.Vector<");
				printTType(type);
				buf.add(">");
				// printVectorSyntax(syntax);

			case TETernary(t): printTernary(t);
			case TEIf(i): printIf(i);
			case TEWhile(w): printWhile(w);
			case TEDoWhile(w): printDoWhile(w);
			case TEHaxeFor(f): printFor(f);
			case TEFor(_) | TEForIn(_) | TEForEach(_): //throw "unprocessed `for` expression";
			case TEBinop(a, op, b): printBinop(a, op, b);
			case TEPreUnop(op, e): printPreUnop(op, e);
			case TEPostUnop(e, op): printPostUnop(e, op);
			case TEAs(e, keyword, type): printAs(e, keyword, type);
			case TESwitch(s): printSwitch(s);
			case TENew(keyword, eclass, args): printNew(keyword, eclass, args);
			case TECondCompValue(v): printCondCompVar(v);
			case TECondCompBlock(v, expr): printCondCompBlock(v, expr);
			case TEXmlChild(x): printXmlChild(x);
			case TEXmlAttr(x): printXmlAttr(x);
			case TEXmlAttrExpr(x): printXmlAttrExpr(x);
			case TEXmlDescend(x): printXmlDescend(x);
			case TEUseNamespace(ns): printUseNamespace(ns);
		}
	}

	function printBuiltin(token:Token, name:String) {
		// TODO: this is hacky (builtins in general are hacky...)
		name = switch name {
			case "Std.is" | "Std.int" | "String" | "Reflect.deleteField": name;
			case "Number": "Float";
			case "int": "Int";
			case "uint": "UInt";
			case "Boolean": "Bool";
			case "Object": "ASObject";
			case "XML": "flash.utils.XML";
			case "XMLList": "flash.utils.XMLList";
			case "Array": "Array";
			case "RegExp": "flash.utils.RegExp";
			case "parseInt": "Std.parseInt";
			case "parseFloat": "Std.parseFloat";
			case "NaN": "Math.NaN";
			case "isNaN": "Math.isNaN";
			case "escape": "escape";
			case "arguments": "/*TODO*/arguments";
			case "trace": "trace";
			case _:
				throw "unknown builtin: " + name;
		}
		printTextWithTrivia(name, token);
	}

	function printAs(e:TExpr, keyword:Token, type:TTypeRef) {
		printTrivia(TypedTreeTools.removeLeadingTrivia(e));
		buf.add("Std.instance(");
		printExpr(e);
		printTextWithTrivia(",", keyword);
		printTType(type.type);
		// printSyntaxType(type.syntax);
		buf.add(")");
	}

	function printCast(c:TCast) {
		printTrivia(c.syntax.path.first.leadTrivia);
		c.syntax.path.first.leadTrivia = [];
		buf.add("cast");
		printOpenParen(c.syntax.openParen);
		printExpr(c.expr);
		buf.add(",");
		// printDotPath(c.syntax.path);
		printTType(c.type);
		printCloseParen(c.syntax.closeParen);
	}

	function printLocalFunction(f:TLocalFunction) {
		printTextWithTrivia("function", f.syntax.keyword);
		if (f.name != null) printTextWithTrivia(f.name.name, f.name.syntax);
		printSignature(f.fun.sig);
		printExpr(f.fun.expr);
	}

	function printXmlDescend(x:TXmlDescend) {
		printExpr(x.eobj);
		printTextWithTrivia("..", x.syntax.dotDot);
		printTextWithTrivia(x.name, x.syntax.name);
	}

	function printXmlChild(x:TXmlChild) {
		printExpr(x.eobj);
		printDot(x.syntax.dot);
		printTextWithTrivia(x.name, x.syntax.name);
	}

	function printXmlAttr(x:TXmlAttr) {
		printExpr(x.eobj);
		printDot(x.syntax.dot);
		printTextWithTrivia("@", x.syntax.at);
		printTextWithTrivia(x.name, x.syntax.name);
	}

	function printXmlAttrExpr(x:TXmlAttrExpr) {
		printExpr(x.eobj);
		printDot(x.syntax.dot);
		printTextWithTrivia("@", x.syntax.at);
		printOpenBracket(x.syntax.openBracket);
		printExpr(x.eattr);
		printCloseBracket(x.syntax.closeBracket);
	}

	function printSwitch(s:TSwitch) {
		printTextWithTrivia("switch", s.syntax.keyword);
		printOpenParen(s.syntax.openParen);
		printExpr(s.subj);
		printCloseParen(s.syntax.closeParen);
		printOpenBrace(s.syntax.openBrace);
		for (c in s.cases) {
			printTextWithTrivia("case", c.syntax.keyword);
			printExpr(c.value);
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

	function printVectorSyntax(syntax:VectorSyntax) {
		printTextWithTrivia("Vector", syntax.name);
		printDot(syntax.dot);
		printTypeParam(syntax.t);
	}

	function printTypeParam(t:TypeParam) {
		printTextWithTrivia("<", t.lt);
		printSyntaxType(t.type);
		printTextWithTrivia(">", t.gt);
	}

	function printSyntaxType(t:SyntaxType) {
		switch (t) {
			case TAny(star): printTextWithTrivia("*", star);
			case TPath(path): printDotPath(path);
			case TVector(v): printVectorSyntax(v);
		}
	}

	function printCondCompBlock(v:TCondCompVar, expr:TExpr) {
		printTokenTrivia(v.syntax.ns);
		printTokenTrivia(v.syntax.sep);
		printTextWithTrivia("#if " + v.ns + "_" + v.name, v.syntax.name);
		printExpr(expr);
		buf.add("#end");
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
			printColon(c.syntax.type.colon);
			// printSyntaxType(c.syntax.type.type);
			printTType(c.v.type);
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
			case TEDeclRef(_): printExpr(eclass);
			case _: buf.add("/*local*/String");
		}
		// printExpr(eclass);
		if (args != null) printCallArgs(args) else buf.add("()");
	}

	function printVectorDecl(d:TVectorDecl) {
		// printTextWithTrivia("new", d.syntax.newKeyword);
		// printTypeParam(d.syntax.typeParam);
		printTextWithTrivia("flash.Vector.ofArray(", d.syntax.newKeyword);
		var t = d.elements.syntax.closeBracket.trailTrivia;
		d.elements.syntax.closeBracket.trailTrivia = [];
		printArrayDecl(d.elements);
		buf.add(")");
		printTrivia(t);
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
			case VConst(t): printTextWithTrivia("/*final*/var", t);
		}
	}

	function printVars(kind:VarDeclKind, vars:Array<TVarDecl>) {
		printVarKind(kind);
		for (v in vars) {
			printTextWithTrivia(v.v.name, v.syntax.name);
			if (v.syntax.type != null) {
				printColon(v.syntax.type.colon);
				// printSyntaxTypeHint(v.syntax.type);
			} else {
				buf.add(":");
			}
			printTType(v.v.type);
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
				printDot(dot);
			case TOImplicitThis(_):
			case TOImplicitClass(_):
		}
		printTextWithTrivia(name, token);
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
			case TLRegExp(syntax): printTextWithTrivia("~"+syntax.text, syntax);
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
			printSemicolon(e.semicolon);
		} else if (!endsWithBlock(e.expr)) {
			buf.add(";");
		}
	}

	static function endsWithBlock(e:TExpr) {
		return switch e.kind {
			case TEBlock(_) | TECondCompBlock(_) | TETry(_) | TESwitch(_):
				true;
			case TEIf(i):
				endsWithBlock(if (i.eelse != null) i.eelse.expr else i.ethen);
			case TEHaxeFor({body: b}), TEFor({body: b}) | TEForIn({body: b}) | TEForEach({body: b}) | TEWhile({body: b}) | TEDoWhile({body: b}):
				endsWithBlock(b);
			case TELocalFunction(f):
				endsWithBlock(f.fun.expr);
			case _:
				false;
		}
	}

	inline function printTokenTrivia(t:Token) {
		printTrivia(t.leadTrivia);
		printTrivia(t.trailTrivia);
	}
}
