import ParseTree;

class Parser {
	var stream:TokenInfoStream;

	public function new(stream) {
		this.stream = stream;
	}

	public inline function parse() return parseFile();

	function parseFile():File {
		var pack = parsePackage();
		var decls = [];
		return {
			pack: pack,
			declarations: decls,
		};
	}

	function parsePackage():Package {
		var keyword = expectKeyword("package");

		var brOpen, name;
		var token = stream.advance();
		switch token.kind {
			case TkBraceOpen:
				name = null;
				brOpen = stream.consume();
			case TkIdent:
				name = parseDotPathNext(stream.consume());
				brOpen = expectKind(TkBraceOpen);
			case _:
				throw "Expected package path or open brace";
		}

		var decls = parseSequence(parseDeclaration);

		var brClose = expectKind(TkBraceClose);

		return {
			keyword: keyword,
			name: name,
			openBrace: brOpen,
			closeBrace: brClose,
			declarations: decls
		};
	}

	function parseDeclaration():Declaration {
		var modifiers = [];
		while (true) {
			var token = stream.advance();
			switch [token.kind, token.text] {
				case [TkIdent, "import"]:
					return DImport(parseImportNext(stream.consume()));
				case [TkIdent, "public" | "internal" | "final" | "dynamic"]:
					modifiers.push(stream.consume());
				case [TkIdent, "class"]:
					return DClass(parseClassNext(modifiers, stream.consume()));
				case [TkIdent, "interface"]:
					return DInterface(parseInterfaceNext(modifiers, stream.consume()));
				case _:
					if (modifiers.length > 0)
						throw "Modifiers without declaration";
					return null;
			}
		}
	}

	function parseImportNext(keyword:TokenInfo):ImportDecl {
		var first = expectKind(TkIdent);
		var rest = [];
		var wildcard = null;
		while (true) {
			var token = stream.advance();
			if (token.kind == TkDot) {
				var dot = stream.consume();
				var token = stream.advance();
				switch token.kind {
					case TkIdent:
						rest.push({sep: dot, element: stream.consume()});
					case TkAsterisk:
						wildcard = stream.consume();
						break;
					case _:
						break;
				}
			} else {
				break;
			}
		}
		var path = {first: first, rest: rest};
		var semicolon = expectKind(TkSemicolon);
		return {
			wildcard: wildcard,
			semicolon: semicolon,
			path: path,
			keyword: keyword
		};
	}

	function parseClassNext(modifiers:Array<TokenInfo>, keyword:TokenInfo):ClassDecl {
		var name = expectKind(TkIdent);

		var extend = {
			var token = stream.advance();
			if (token.kind == TkIdent && token.text == "extends") {
				var keyword = stream.consume();
				var path = parseDotPath();
				{keyword: keyword, path: path};
			} else {
				null;
			}
		}

		var implement = {
			var token = stream.advance();
			if (token.kind == TkIdent && token.text == "implements") {
				var keyword = stream.consume();
				var paths = parseSeparated(parseDotPath, t -> t.kind == TkComma);
				{keyword: keyword, paths: paths};
			} else {
				null;
			}
		}

		var openBrace = expectKind(TkBraceOpen);

		var fields = parseSequence(parseClassField);

		var closeBrace = expectKind(TkBraceClose);

		return {
			modifiers: modifiers,
			keyword: keyword,
			name: name,
			extend: extend,
			implement: implement,
			openBrace: openBrace,
			fields: fields,
			closeBrace: closeBrace
		};
	}

	function parseClassField():Null<ClassField> {
		var modifiers = [];
		while (true) {
			var token = stream.advance();
			switch [token.kind, token.text] {
				case [TkIdent, "public" | "private" | "protected" | "internal" | "override" | "static"]:
					modifiers.push(stream.consume());
				case [TkIdent, "var" | "const"]:
					return parseClassVarNext(modifiers, stream.consume());
				case [TkIdent, "function"]:
					return parseClassFunNext(modifiers, stream.consume());
				case _:
					if (modifiers.length > 0)
						throw "Modifiers without declaration";
					return null;
			}
		}
	}

	function parseClassVarNext(modifiers:Array<TokenInfo>, keyword:TokenInfo):ClassField {
		var name = expectKind(TkIdent);
		var hint = parseOptionalTypeHint();
		var init = parseOptionalVarInit();
		var semicolon = expectKind(TkSemicolon);
		return {
			modifiers: modifiers,
			name: name,
			kind: FVar({
				keyword: keyword,
				hint: hint,
				init: init,
				semicolon: semicolon
			})
		};
	}

	function parseOptionalTypeHint():Null<TypeHint> {
		var token = stream.advance();
		if (token.kind == TkColon) {
			var colon = stream.consume();
			var type = parseSyntaxType();
			return {colon: colon, type: type};
		} else {
			return null;
		}
	}

	function parseOptionalVarInit():Null<VarInit> {
		var token = stream.advance();
		if (token.kind == TkEquals) {
			var equals = stream.consume();
			var expr = parseExpr();
			return {equals: equals, expr: expr};
		} else {
			return null;
		}
	}

	function parseClassFunNext(modifiers:Array<TokenInfo>, keyword:TokenInfo):ClassField {
		var name, propKind;
		var nameToken = expectKind(TkIdent);
		switch nameToken.token.text {
			case type = "get" | "set" if (stream.advance().kind == TkIdent):
				name = stream.consume();
				propKind = if (type == "get") PGet(nameToken) else PSet(nameToken);
			case _:
				name = nameToken;
				propKind = null;
		}

		var openParen = expectKind(TkParenOpen);
		var args = {
			var token = stream.advance();
			if (token.kind == TkIdent) {
				var first = parseFunctionArgNext(stream.consume());
				parseSeparatedNext(first, parseFunctionArg, t -> t.kind == TkComma);
			} else {
				null;
			}
		}
		var closeParen = expectKind(TkParenClose);
		var ret = parseOptionalTypeHint();
		var openBrace = expectKind(TkBraceOpen);
		var exprs = parseSequence(parseOptionalBlockExpr);
		var closeBrace = expectKind(TkBraceClose);

		var fun:ClassFun = {
			keyword: keyword,
			openParen: openParen,
			args: args,
			closeParen: closeParen,
			ret: ret,
			openBrace: openBrace,
			exprs: exprs,
			closeBrace: closeBrace
		};

		return {
			modifiers: modifiers,
			name: name,
			kind: if (propKind == null) FFun(fun) else FProp(propKind, fun)
		};
	}

	function parseFunctionArg():FunctionArg {
		var name = expectKind(TkIdent);
		return parseFunctionArgNext(name);
	}

	function parseFunctionArgNext(name:TokenInfo):FunctionArg {
		var hint = parseOptionalTypeHint();
		var init = parseOptionalVarInit();
		return {name: name, hint: hint, init: init};
	}

	function parseSyntaxType():SyntaxType {
		var token = stream.advance();
		switch token.kind {
			case TkAsterisk:
				return TAny(stream.consume());
			case TkIdent:
				return TPath(parseDotPathNext(stream.consume()));
			case _:
				throw "Unexpected token for type hint";
		}
	}

	function parseOptionalBlockExpr():Null<Expr> {
		var expr = parseOptionalExpr();
		if (expr != null) {
			// TODO: only require semicolon if last expr token wasn't a closing brace
			expectKind(TkSemicolon);
		}
		return expr;
	}

	function parseExpr():Expr {
		var expr = parseOptionalExpr();
		if (expr == null)
			throw "Expression expected";
		return expr;
	}

	function parseOptionalExpr():Null<Expr> {
		var token = stream.advance();
		switch token.kind {
			case TkIdent:
				switch token.text {
					case "return":
						return EReturn(stream.consume(), parseOptionalExpr());
					case _:
						var expr = EIdent(stream.consume());
						return parseExprNext(expr);
				}
			case TkStringSingle | TkStringDouble:
				return ELiteral(LString(stream.consume()));
			case _:
				return null;
		}
	}

	function parseExprNext(first:Expr) {
		var token = stream.advance();
		switch token.kind {
			case TkParenOpen:
				return parseCallNext(first, stream.consume());
			case _:
				return first;
		}
	}

	function parseCallNext(e:Expr, openParen:TokenInfo):Expr {
		var token = stream.advance();
		switch token.kind {
			case TkParenClose:
				return ECall(e, openParen, null, stream.consume());
			case _:
				var args = parseSeparated(parseExpr, t -> t.kind == TkComma);
				return ECall(e, openParen, args, expectKind(TkParenClose));
		}
	}

	function parseInterfaceNext(modifiers:Array<TokenInfo>, keyword:TokenInfo):InterfaceDecl {
		var name = expectKind(TkIdent);

		var extend = null;
		{
			var token = stream.advance();
			switch token.kind {
				case TkIdent if (token.text == "extends"):
					var keyword = stream.consume();
					var paths = parseSeparated(parseDotPath, t -> t.kind == TkComma);
					extend = {keyword: keyword, paths: paths};
				case _:
			}
		}

		var openBrace = expectKind(TkBraceOpen);
		var closeBrace = expectKind(TkBraceClose);
		return {
			modifiers: modifiers,
			keyword: keyword,
			name: name,
			extend: extend,
			openBrace: openBrace,
			closeBrace: closeBrace
		};
	}

	function parseSequence<T>(parse:Void->Null<T>):Array<T> {
		var seq = [];
		while (true) {
			var item = parse();
			if (item != null) {
				seq.push(item);
			} else {
				break;
			}
		}
		return seq;
	}

	function parseSeparated<T>(parsePart:Void->T, checkSep:Token->Bool):Separated<T> {
		var first = parsePart();
		return parseSeparatedNext(first, parsePart, checkSep);
	}

	function parseSeparatedNext<T>(first:T, parsePart:Void->T, checkSep:Token->Bool):Separated<T> {
		var rest = [];
		while (true) {
			var token = stream.advance();
			if (checkSep(token)) {
				var sep = stream.consume();
				var part = parsePart();
				rest.push({sep: sep, element: part});
			} else {
				break;
			}
		}
		return {first: first, rest: rest};
	}

	function parseDotPath():DotPath {
		return parseSeparated(expectKind.bind(TkIdent), t -> t.kind == TkDot);
	}

	function parseDotPathNext(first:TokenInfo):DotPath {
		return parseSeparatedNext(first, expectKind.bind(TkIdent), t -> t.kind == TkDot);
	}

	function expect(check, msg) {
		var token = stream.advance();
		return if (check(token)) stream.consume() else throw msg;
	}

	function expectKind(kind) {
		return expect(t -> t.kind == kind, 'Expected token: ${kind.getName()}');
	}

	function expectKeyword(name) {
		return expect(t -> t.kind == TkIdent && t.text == name, 'Expected keyword: $name');
	}
}
