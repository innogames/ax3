import ParseTree;
import Token;

class Parser {
	var scanner:Scanner;

	public function new(scanner) {
		this.scanner = scanner;
	}

	public inline function parse() return parseFile();

	function parseFile():File {
		return {
			declarations: parseSequence(parseDeclaration),
			eof: expectKind(TkEof),
		};
	}

	function parseDeclaration():Declaration {
		var modifiers = [];
		var metadata = parseSequence(parseOptionalMetadata);
		while (true) {
			var token = scanner.advance();
			switch [token.kind, token.text] {
				case [TkIdent, "public" | "internal" | "final" | "dynamic"]:
					modifiers.push(scanner.consume());
				case [TkIdent, "class"]:
					return DClass(parseClassNext(metadata, modifiers, scanner.consume()));
				case [TkIdent, "interface"]:
					return DInterface(parseInterfaceNext(metadata, modifiers, scanner.consume()));
				case [TkIdent, "function"]:
					return DFunction(parseFunctionDeclNext(metadata, modifiers, scanner.consume()));
				case [TkIdent, "var" | "const"]:
					return DVar(scanner.consume(), parseVarDecls(), expectKind(TkSemicolon));
				case [TkIdent, "namespace"]:
					return DNamespace({
						modifiers: modifiers,
						keyword: scanner.consume(),
						name: expectKind(TkIdent),
						semicolon: expectKind(TkSemicolon)
					});
				case _:
					if (modifiers.length > 0)
						throw "Modifiers without declaration";
					if (metadata.length > 0)
						throw "Metadata without declaration";

					if (token.kind == TkIdent) {
						switch token.text {
							case "package":
								return DPackage(parsePackage(scanner.consume()));
							case "import":
								return DImport(parseImportNext(scanner.consume()));
							case "use":
								return DUseNamespace(parseUseNamespace(scanner.consume()), expectKind(TkSemicolon));
							case _:
								var ns = scanner.consume();
								var sep = expectKind(TkColonColon);
								var name = expectKind(TkIdent);
								var openBrace = expectKind(TkBraceOpen);
								var decls = parseSequence(parseDeclaration);
								var closeBrace = expectKind(TkBraceClose);
								var condComp = {ns: ns, sep: sep, name: name};
								return DCondComp(condComp, openBrace, decls, closeBrace);
						}
					}

					return null;
			}
		}
	}

	function parsePackage(keyword:Token):PackageDecl {
		var brOpen, name;
		var token = scanner.advance();
		switch token.kind {
			case TkBraceOpen:
				name = null;
				brOpen = scanner.consume();
			case TkIdent:
				name = parseDotPathNext(scanner.consume());
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

	function parseOptionalMetadata():Metadata {
		return switch scanner.advance().kind {
			case TkBracketOpen: parseMetadataNext(scanner.consume());
			case _: null;
		}
	}

	function parseMetadataNext(openBracket:Token):Metadata {
		var name = expectKind(TkIdent);
		var args = switch scanner.advance().kind {
			case TkParenOpen:
				parseCallArgsNext(scanner.consume());
			case _:
				null;
		}
		var closeBracket = expectKind(TkBracketClose);
		return {
			openBracket: openBracket,
			name: name,
			args: args,
			closeBracket: closeBracket
		};
	}

	function parseUseNamespace(useKeyword:Token):UseNamespace {
		var namespaceKeyword = expectKeyword("namespace");
		var name = expectKind(TkIdent);
		return {
			useKeyword: useKeyword,
			namespaceKeyword: namespaceKeyword,
			name: name
		};
	}

	function parseImportNext(keyword:Token):ImportDecl {
		var first = expectKind(TkIdent);
		var rest = [];
		var wildcard = null;
		while (true) {
			var token = scanner.advance();
			if (token.kind == TkDot) {
				var dot = scanner.consume();
				var token = scanner.advance();
				switch token.kind {
					case TkIdent:
						rest.push({sep: dot, element: scanner.consume()});
					case TkAsterisk:
						wildcard = scanner.consume();
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

	function parseClassNext(metadata:Array<Metadata>, modifiers:Array<Token>, keyword:Token):ClassDecl {
		var name = expectKind(TkIdent);

		var extend = {
			var token = scanner.advance();
			if (token.kind == TkIdent && token.text == "extends") {
				var keyword = scanner.consume();
				var path = parseDotPath();
				{keyword: keyword, path: path};
			} else {
				null;
			}
		}

		var implement = {
			var token = scanner.advance();
			if (token.kind == TkIdent && token.text == "implements") {
				var keyword = scanner.consume();
				var paths = parseSeparated(parseDotPath, t -> t.kind == TkComma);
				{keyword: keyword, paths: paths};
			} else {
				null;
			}
		}

		var openBrace = expectKind(TkBraceOpen);

		var members = parseSequence(parseClassMember);

		var closeBrace = expectKind(TkBraceClose);

		return {
			metadata: metadata,
			modifiers: modifiers,
			keyword: keyword,
			name: name,
			extend: extend,
			implement: implement,
			openBrace: openBrace,
			members: members,
			closeBrace: closeBrace
		};
	}

	function parseClassMember():Null<ClassMember> {
		var modifiers = [];
		var namespace = null;
		var metadata = parseSequence(parseOptionalMetadata);
		while (true) {
			var token = scanner.advance();
			if (token.kind != TkIdent)
				return null;

			switch token.text {
				case "public" | "private" | "protected" | "internal" | "override" | "static" | "final":
					modifiers.push(scanner.consume());
				case "var" | "const":
					return MField(parseClassVarNext(metadata, namespace, modifiers, scanner.consume()));
				case "function":
					return MField(parseClassFunNext(metadata, namespace, modifiers, scanner.consume()));
				case text:
					if (modifiers.length > 0)
						throw "Modifiers without declaration";
					if (metadata.length > 0)
						throw "Metadata without declaration";
					if (namespace != null)
						throw "Namespace without declaration";

					if (text == "use") {
						return MUseNamespace(parseUseNamespace(scanner.consume()), expectKind(TkSemicolon));
					}

					var token = scanner.consume();
					switch scanner.advance().kind {
						case TkColonColon:
							var ns = token;
							var sep = scanner.consume();
							var name = expectKind(TkIdent);
							var openBrace = expectKind(TkBraceOpen);
							var members = parseSequence(parseClassMember);
							var closeBrace = expectKind(TkBraceClose);
							var condComp = {ns: ns, sep: sep, name: name};
							return MCondComp(condComp, openBrace, members, closeBrace);
						case _:
							if (namespace != null)
								throw "Namespace already defined";
							namespace = token;
					}
			}
		}
	}

	function parseClassVarNext(metadata:Array<Metadata>, namespace:Null<Token>, modifiers:Array<Token>, keyword:Token):ClassField {
		var vars = parseVarDecls();
		var semicolon = expectKind(TkSemicolon);
		return {
			metadata: metadata,
			namespace: namespace,
			modifiers: modifiers,
			kind: FVar(keyword, vars, semicolon)
		};
	}

	function parseOptionalTypeHint():Null<TypeHint> {
		var token = scanner.advance();
		if (token.kind == TkColon) {
			var colon = scanner.consume();
			var type = parseSyntaxType(true);
			return {colon: colon, type: type};
		} else {
			return null;
		}
	}

	function parseTypeHint():TypeHint {
		var hint = parseOptionalTypeHint();
		if (hint == null)
			throw "Type hint expected";
		return hint;
	}

	function parseOptionalVarInit():Null<VarInit> {
		var token = scanner.advance();
		if (token.kind == TkEquals) {
			var equals = scanner.consume();
			var expr = parseExpr(false);
			return {equals: equals, expr: expr};
		} else {
			return null;
		}
	}

	function parseLocalFunction(keyword:Token):Expr {
		var name = switch scanner.advance().kind {
			case TkIdent: scanner.consume();
			case _: null;
		}
		return EFunction(keyword, name, parseFunctionNext());
	}

	function parseFunctionSignature():FunctionSignature {
		var openParen = expectKind(TkParenOpen);
		var args = parseFunctionArgs();
		var closeParen = expectKind(TkParenClose);
		var ret = parseOptionalTypeHint();
		return {
			openParen: openParen,
			args: args,
			closeParen: closeParen,
			ret: ret
		};
	}

	function parseFunctionNext():Function {
		var signature = parseFunctionSignature();
		var block = parseBracedExprBlock(expectKind(TkBraceOpen));
		return {
			signature: signature,
			block: block,
		};
	}

	function parseClassFunNext(metadata:Array<Metadata>, namespace:Null<Token>, modifiers:Array<Token>, keyword:Token):ClassField {
		var name, propKind;
		var nameToken = expectKind(TkIdent);
		switch nameToken.text {
			case type = "get" | "set" if (scanner.advance().kind == TkIdent):
				name = scanner.consume();
				propKind = if (type == "get") PGet(nameToken) else PSet(nameToken);
			case _:
				name = nameToken;
				propKind = null;
		}

		var fun = parseFunctionNext();
		return {
			metadata: metadata,
			namespace: namespace,
			modifiers: modifiers,
			kind: if (propKind == null) FFun(keyword, name, fun) else FProp(keyword, propKind, name, fun)
		};
	}

	function parseBracedExprBlock(openBrace:Token):BracedExprBlock {
		return {
			openBrace: openBrace,
			exprs: parseSequence(parseOptionalBlockExpr),
			closeBrace: expectKind(TkBraceClose)
		}
	}

	function parseOptionalFunctionArg():Null<FunctionArg> {
		return switch scanner.advance().kind {
			case TkIdent:
				return ArgNormal(parseFunctionArgNext(scanner.consume()));
			case TkDotDotDot:
				return ArgRest(scanner.consume(), expectKind(TkIdent));
			case _:
				null;
		}
	}

	function parseFunctionArg():FunctionArg {
		var arg = parseOptionalFunctionArg();
		if (arg == null)
			throw "Function argument expected";
		return arg;
	}

	function parseFunctionArgNext(name:Token):FunctionArgNormal {
		var hint = parseOptionalTypeHint();
		var init = parseOptionalVarInit();
		return {name: name, hint: hint, init: init};
	}

	function parseFunctionArgs():Null<Separated<FunctionArg>> {
		var first = parseOptionalFunctionArg();
		if (first == null)
			return null;
		return parseSeparatedNext(first, parseFunctionArg, t -> t.kind == TkComma);
	}

	function parseSyntaxType(allowAny:Bool):SyntaxType {
		var token = scanner.advance();
		switch token.kind {
			case TkAsterisk if (allowAny):
				return TAny(scanner.consume());
			case TkIdent if (token.text == "Vector"): // vector is special and should contain type params
				return TVector(parseVectorSyntax(scanner.consume()));
			case TkIdent:
				return TPath(parseDotPathNext(scanner.consume()));
			case _:
				throw "Unexpected token for type hint";
		}
	}

	function parseVectorSyntax(name:Token):VectorSyntax {
		return {
			name: name,
			dot: expectKind(TkDot),
			t: parseTypeParam(expectKind(TkLt))
		};
	}

	function parseTypeParam(lt:Token):TypeParam {
		var type = parseSyntaxType(true);
		var gt = switch scanner.advanceNoRightShift().kind {
			case TkGt: scanner.consume();
			case _: throw "Expected >";
		}
		return {
			lt: lt,
			type: type,
			gt: gt,
		};
	}

	function parseOptionalBlockExpr():Null<BlockElement> {
		var expr = parseOptionalExpr(true);
		if (expr == null)
			return null;
		return parseBlockExprNext(expr);
	}

	function parseBlockExprNext(expr:Expr):BlockElement {
		var semicolon = switch scanner.advance().kind {
			case TkSemicolon:
				scanner.consume();
			case TkBraceClose:
				null; // if the next token is `}` then okay, allow no semicolon
			case _ if (scanner.lastConsumedToken.kind != TkBraceClose):
				throw "Semicolon expected after block expression";
			case _:
				null;
		}
		return {expr: expr, semicolon: semicolon};
	}

	function parseExpr(allowComma:Bool):Expr {
		var expr = parseOptionalExpr(allowComma);
		if (expr == null)
			throw "Expression expected";
		return expr;
	}

	function parseOptionalExpr(allowComma:Bool):Null<Expr> {
		var token = scanner.advanceExprStart();
		switch token.kind {
			case TkIdent:
				if (token.text ==  "case" || token.text == "default") // not part of expression, so don't even consume the token
					return null;
				else
					return parseIdent(scanner.consume(), allowComma);
			case TkStringSingle | TkStringDouble:
				return parseExprNext(ELiteral(LString(scanner.consume())), allowComma);
			case TkRegExp:
				return parseExprNext(ELiteral(LRegExp(scanner.consume())), allowComma);
			case TkDecimalInteger:
				return parseExprNext(ELiteral(LDecInt(scanner.consume())), allowComma);
			case TkHexadecimalInteger:
				return parseExprNext(ELiteral(LHexInt(scanner.consume())), allowComma);
			case TkFloat:
				return parseExprNext(ELiteral(LFloat(scanner.consume())), allowComma);
			case TkParenOpen:
				return parseExprNext(EParens(scanner.consume(), parseExpr(true), expectKind(TkParenClose)), allowComma);
			case TkBraceOpen:
				return parseBlockOrObject(scanner.consume());
			case TkExclamation:
				return EPreUnop(PreNot(scanner.consume()), parseExpr(allowComma));
			case TkTilde:
				return EPreUnop(PreBitNeg(scanner.consume()), parseExpr(allowComma));
			case TkMinus:
				return EPreUnop(PreNeg(scanner.consume()), parseExpr(allowComma));
			case TkPlusPlus:
				return EPreUnop(PreIncr(scanner.consume()), parseExpr(allowComma));
			case TkMinusMinus:
				return EPreUnop(PreDecr(scanner.consume()), parseExpr(allowComma));
			case TkBracketOpen:
				return parseExprNext(EArrayDecl(parseArrayDecl(scanner.consume())), allowComma);
			case _:
				return null;
		}
	}

	function parseIdent(consumedToken:Token, allowComma:Bool):Expr {
		switch consumedToken.text {
			case "new":
				return parseNewNext(consumedToken);
			case "return":
				return EReturn(consumedToken, parseOptionalExpr(allowComma));
			case "throw":
				return EThrow(consumedToken, parseExpr(allowComma));
			case "delete":
				return EDelete(consumedToken, parseExpr(allowComma));
			case "if":
				return parseIf(consumedToken);
			case "switch":
				return parseSwitch(consumedToken);
			case "while":
				return parseWhile(consumedToken);
			case "do":
				return parseDoWhile(consumedToken);
			case "for":
				return parseFor(consumedToken);
			case "break":
				return EBreak(consumedToken);
			case "continue":
				return EContinue(consumedToken);
			case "var" | "const":
				return EVars(consumedToken, parseVarDecls());
			case "try":
				return parseTry(consumedToken);
			case "function":
				return parseLocalFunction(consumedToken);
			case "use":
				return EUseNamespace(parseUseNamespace(consumedToken));
			case "Vector":
				return parseExprNext(EVector(parseVectorSyntax(consumedToken)), allowComma);
			case _:
				return parseActualIdent(consumedToken, allowComma);
		}
	}

	function parseActualIdent(token:Token, allowComma:Bool):Expr {
		switch scanner.advance().kind {
			case TkColonColon:
				// conditional compilation
				var sep = scanner.consume();
				var name = expectKind(TkIdent);
				var condComp = {ns: token, sep: sep, name: name};
				switch scanner.advance().kind {
					case TkBraceOpen:
						return ECondCompBlock(condComp, parseBracedExprBlock(scanner.consume()));
					case _:
						return ECondCompValue(condComp);
				}
			case _:
				// just an indentifier
				return parseExprNext(EIdent(token), allowComma);
		}
	}

	function parseBlockOrObject(openBrace:Token):Expr {
		var token = scanner.advance();
		switch token.kind {
			case TkBraceClose:
				return EBlock({openBrace: openBrace, exprs: [], closeBrace: scanner.consume()});
			case TkIdent | TkStringSingle | TkStringDouble:
				var stringOrIdent = scanner.consume();
				switch scanner.advance().kind {
					case TkColon:
						return parseObjectNext(openBrace, stringOrIdent, scanner.consume());
					case _:
						var firstExpr = switch stringOrIdent.kind {
							case TkIdent: parseIdent(stringOrIdent, true);
							case TkStringSingle | TkStringDouble: return parseExprNext(ELiteral(LString(stringOrIdent)), true);
							case _: throw "assert";
						}
						var first = parseBlockExprNext(firstExpr);
						var exprs = parseSequence(parseOptionalBlockExpr);
						exprs.unshift(first);
						var b:BracedExprBlock = {
							openBrace: openBrace,
							exprs: exprs,
							closeBrace: expectKind(TkBraceClose)
						}
						return EBlock(b);

				}
			case _:
				return EBlock(parseBracedExprBlock(openBrace));
		}
	}

	function parseObjectNext(openBrace:Token, firstIdent:Token, firstColon:Token):Expr {
		var first = {name: firstIdent, colon: firstColon, value: parseExpr(false)};
		var fields = parseSeparatedNext(first, function() {
			return switch scanner.advance().kind {
				case TkIdent | TkStringSingle | TkStringDouble:
					var name = scanner.consume();
					var colon = expectKind(TkColon);
					var expr = parseExpr(false);
					{name: name, colon: colon, value: expr};
				case _:
					throw "Object keys must be identifiers or strings";
			}
		}, t -> t.kind == TkComma);
		var closeBrace = expectKind(TkBraceClose);
		return EObjectDecl(openBrace, fields, closeBrace);
	}

	function parseArrayDecl(openBracket:Token):ArrayDecl {
		return switch scanner.advance().kind {
			case TkBracketClose:
				{openBracket: openBracket, elems: null, closeBracket: scanner.consume()};
			case _:
				var elems = parseSeparated(parseExpr.bind(false), t -> t.kind == TkComma);
				{openBracket: openBracket, elems: elems, closeBracket: expectKind(TkBracketClose)};
		};
	}

	function parseVarDecls():Separated<VarDecl> {
		return parseSeparated(function() {
			var firstName = expectKind(TkIdent);
			var type = parseOptionalTypeHint();
			var init = parseOptionalVarInit();
			return {name: firstName, type: type, init: init};
		}, t -> t.kind == TkComma);
	}

	function parseTry(keyword:Token):Expr {
		var block = parseBracedExprBlock(expectKind(TkBraceOpen));
		var catches = parseSequence(function():Catch {
			return switch scanner.advance() {
				case {kind: TkIdent, text: "catch"}:
					{
						keyword: scanner.consume(),
						openParen: expectKind(TkParenOpen),
						name: expectKind(TkIdent),
						type: parseTypeHint(),
						closeParen: expectKind(TkParenClose),
						block: parseBracedExprBlock(expectKind(TkBraceOpen))
					}
				case _:
					null;
			}
		});

		if (catches.length == 0)
			throw "try without catches";

		var finally = switch scanner.advance() {
			case {kind: TkIdent, text: "finally"}:
				{keyword: scanner.consume(), block: parseBracedExprBlock(expectKind(TkBraceOpen))};
			case _:
				null;
		}

		return ETry(keyword, block, catches, finally);
	}

	function parseIf(keyword:Token):Expr {
		var openParen = expectKind(TkParenOpen);
		var econd = parseExpr(true);
		var closeParen = expectKind(TkParenClose);
		var ethen = parseExpr(true);
		var eelse = switch scanner.advance() {
			case {kind: TkIdent, text: "else"}:
				{keyword: scanner.consume(), expr: parseExpr(true)};
			case _:
				null;
		}
		return EIf(keyword, openParen, econd, closeParen, ethen, eelse);
	}

	function parseSwitch(keyword:Token):Expr {
		var openParen = expectKind(TkParenOpen);
		var esubj = parseExpr(true);
		var closeParen = expectKind(TkParenClose);
		var openBrace = expectKind(TkBraceOpen);
		var cases = parseSequence(function() {
			var token = scanner.advance();
			return switch [token.kind, token.text] {
				case [TkIdent, "case"]:
					var keyword = scanner.consume();
					var v = parseExpr(false);
					var colon = expectKind(TkColon);
					var exprs = parseSequence(parseOptionalBlockExpr);
					CCase(keyword, v, colon, exprs);

				case [TkIdent, "default"]:
					var keyword = scanner.consume();
					var colon = expectKind(TkColon);
					var exprs = parseSequence(parseOptionalBlockExpr);
					CDefault(keyword, colon, exprs);

				case _:
					null;
			}
		});
		var closeBrace = expectKind(TkBraceClose);
		return ESwitch(keyword, openParen, esubj, closeParen, openBrace, cases, closeBrace);
	}

	function parseWhile(keyword:Token):Expr {
		var openParen = expectKind(TkParenOpen);
		var econd = parseExpr(true);
		var closeParen = expectKind(TkParenClose);
		var ebody = parseExpr(true);
		return EWhile(keyword, openParen, econd, closeParen, ebody);
	}

	function parseDoWhile(doKeyword:Token):Expr {
		var ebody = parseExpr(true);
		var whileKeyword = expectKeyword("while");
		var openParen = expectKind(TkParenOpen);
		var econd = parseExpr(true);
		var closeParen = expectKind(TkParenClose);
		return EDoWhile(doKeyword, ebody, whileKeyword, openParen, econd, closeParen);
	}

	function parseFor(keyword:Token):Expr {
		return switch scanner.advance() {
			case {kind: TkIdent, text: "each"}:
				parseForEach(keyword, scanner.consume());
			case _:
				var openParen = expectKind(TkParenOpen);
				var einit = parseOptionalExpr(true);
				if (einit == null) {
					parseCFor(keyword, openParen, null);
				} else {
					var forIter = parseOptionalForIter(einit);
					if (forIter == null) {
						parseCFor(keyword, openParen, einit);
 					} else {
						var closeParen = expectKind(TkParenClose);
						var ebody = parseExpr(true);
						EForIn(keyword, openParen, forIter, closeParen, ebody);
					}
				}
		}
	}

	function parseOptionalForIter(expr:Null<Expr>):ForIter {
		return switch expr {
			case EBinop(a, OpIn(inKeyword), b):
				{eit: a, inKeyword: inKeyword, eobj: b}
			case _:
				switch scanner.advance() {
					case {kind: TkIdent, text: "in"}:
						{eit: expr, inKeyword: scanner.consume(), eobj: parseExpr(true)}
					case _:
						null;
				}
		}
	}

	function parseForEach(forKeyword:Token, eachKeyword:Token):Expr {
		var openParen = expectKind(TkParenOpen);
		var iter = parseOptionalForIter(parseExpr(true));
		if (iter == null)
			throw "`a in b` expression expected for the `for each` loop";
		var closeParen = expectKind(TkParenClose);
		var body = parseExpr(true);
		return EForEach(forKeyword, eachKeyword, openParen, iter, closeParen, body);
	}

	function parseCFor(forKeyword:Token, openParen:Token, einit:Expr):Expr {
		var einitSep = expectKind(TkSemicolon);
		var econd = parseOptionalExpr(true);
		var econdSep = expectKind(TkSemicolon);
		var eincr = parseOptionalExpr(true);
		var closeParen = expectKind(TkParenClose);
		var ebody = parseExpr(true);
		return EFor(forKeyword, openParen, einit, einitSep, econd, econdSep, eincr, closeParen, ebody);
	}

	function parseNewNext(keyword:Token):Expr {
		return switch scanner.advance().kind {
			case TkLt:
				var t = parseTypeParam(scanner.consume());
				var decl = parseArrayDecl(expectKind(TkBracketOpen));
				EVectorDecl(keyword, t, decl);
			case _:
				switch parseExpr(false) {
					case ECall(e, args): ENew(keyword, e, args);
					case e: ENew(keyword, e, null);
				}
		}
	}

	function parseExprNext(first:Expr, allowComma:Bool) {
		var token = scanner.advance();
		switch token.kind {
			case TkParenOpen:
				return parseExprNext(ECall(first, parseCallArgsNext(scanner.consume())), allowComma);
			case TkDot:
				var dot = scanner.consume();
				var fieldName = expectKind(TkIdent);
				return parseExprNext(EField(first, dot, fieldName), allowComma);
			case TkPlus:
				return parseBinop(first, OpAdd, allowComma);
			case TkPlusEquals:
				return parseBinop(first, OpAssignAdd, allowComma);
			case TkPlusPlus:
				return parseExprNext(EPostUnop(first, PostIncr(scanner.consume())), allowComma);
			case TkMinus:
				return parseBinop(first, OpSub, allowComma);
			case TkMinusEquals:
				return parseBinop(first, OpAssignSub, allowComma);
			case TkMinusMinus:
				return parseExprNext(EPostUnop(first, PostDecr(scanner.consume())), allowComma);
			case TkAsterisk:
				return parseBinop(first, OpMul, allowComma);
			case TkAsteriskEquals:
				return parseBinop(first, OpAssignMul, allowComma);
			case TkSlash:
				return parseBinop(first, OpDiv, allowComma);
			case TkSlashEquals:
				return parseBinop(first, OpAssignDiv, allowComma);
			case TkPercent:
				return parseBinop(first, OpMod, allowComma);
			case TkPercentEquals:
				return parseBinop(first, OpAssignMod, allowComma);
			case TkEquals:
				return parseBinop(first, OpAssign, allowComma);
			case TkEqualsEquals:
				return parseBinop(first, OpEquals, allowComma);
			case TkEqualsEqualsEquals:
				return parseBinop(first, OpStrictEquals, allowComma);
			case TkExclamationEquals:
				return parseBinop(first, OpNotEquals, allowComma);
			case TkExclamationEqualsEquals:
				return parseBinop(first, OpNotStrictEquals, allowComma);
			case TkLt:
				return parseBinop(first, OpLt, allowComma);
			case TkLtLt:
				return parseBinop(first, OpShl, allowComma);
			case TkLtLtEquals:
				return parseBinop(first, OpAssignShl, allowComma);
			case TkLtEquals:
				return parseBinop(first, OpLte, allowComma);
			case TkGt:
				return parseBinop(first, OpGt, allowComma);
			case TkGtGt:
				return parseBinop(first, OpShr, allowComma);
			case TkGtGtEquals:
				return parseBinop(first, OpAssignShr, allowComma);
			case TkGtGtGt:
				return parseBinop(first, OpUshr, allowComma);
			case TkGtGtGtEquals:
				return parseBinop(first, OpAssignUshr, allowComma);
			case TkGtEquals:
				return parseBinop(first, OpGte, allowComma);
			case TkAmpersand:
				return parseBinop(first, OpBitAnd, allowComma);
			case TkAmpersandAmpersand:
				return parseBinop(first, OpAnd, allowComma);
			case TkAmpersandAmpersandEquals:
				return parseBinop(first, OpAssignAnd, allowComma);
			case TkAmpersandEquals:
				return parseBinop(first, OpAssignBitAnd, allowComma);
			case TkPipe:
				return parseBinop(first, OpBitOr, allowComma);
			case TkPipePipe:
				return parseBinop(first, OpOr, allowComma);
			case TkPipePipeEquals:
				return parseBinop(first, OpAssignOr, allowComma);
			case TkPipeEquals:
				return parseBinop(first, OpAssignBitOr, allowComma);
			case TkCaret:
				return parseBinop(first, OpBitXor, allowComma);
			case TkCaretEquals:
				return parseBinop(first, OpAssignBitXor, allowComma);
			case TkBracketOpen:
				var openBracket = scanner.consume();
				var eindex = parseExpr(true);
				var closeBracket = expectKind(TkBracketClose);
				return parseExprNext(EArrayAccess(first, openBracket, eindex, closeBracket), allowComma);
			case TkQuestion:
				return parseTernary(first, scanner.consume(), allowComma);
			case TkIdent:
				switch token.text {
					case "in":
						return parseBinop(first, OpIn, allowComma);
					case "is":
						return parseExprNext(EIs(first, scanner.consume(), parseSyntaxType(false)), allowComma);
					case "as":
						return parseExprNext(EAs(first, scanner.consume(), parseSyntaxType(false)), allowComma);
					case _:
				}
			case TkComma if (allowComma):
				return parseExprNext(EComma(first, scanner.consume(), parseExpr(false)), true);
			case _:
		}
		return first;
	}

	function parseTernary(econd:Expr, question:Token, allowComma:Bool):Expr {
		var ethen = parseExpr(true);
		var colon = expectKind(TkColon);
		var eelse = parseExpr(allowComma);
		return ETernary(econd, question, ethen, colon, eelse);
	}

	function parseBinop(a:Expr, ctor:Token->Binop, allowComma:Bool):Expr {
		// TODO: handle precedence here (swap expressions when needed)
		var token = scanner.consume();
		var second = parseExpr(allowComma);
		return parseExprNext(EBinop(a, ctor(token), second), allowComma);
	}

	function parseCallArgsNext(openParen:Token):CallArgs {
		var token = scanner.advance();
		switch token.kind {
			case TkParenClose:
				return {openParen: openParen, args: null, closeParen: scanner.consume()};
			case _:
				var args = parseSeparated(parseExpr.bind(false), t -> t.kind == TkComma);
				return {openParen: openParen, args: args, closeParen: expectKind(TkParenClose)};
		}
	}

	function parseInterfaceNext(metadata:Array<Metadata>, modifiers:Array<Token>, keyword:Token):InterfaceDecl {
		var name = expectKind(TkIdent);

		var extend = null;
		{
			var token = scanner.advance();
			switch token.kind {
				case TkIdent if (token.text == "extends"):
					var keyword = scanner.consume();
					var paths = parseSeparated(parseDotPath, t -> t.kind == TkComma);
					extend = {keyword: keyword, paths: paths};
				case _:
			}
		}

		var openBrace = expectKind(TkBraceOpen);
		var members = parseSequence(parseInterfaceMember);
		var closeBrace = expectKind(TkBraceClose);
		return {
			metadata: metadata,
			modifiers: modifiers,
			keyword: keyword,
			name: name,
			extend: extend,
			openBrace: openBrace,
			members: members,
			closeBrace: closeBrace
		};
	}

	function parseFunctionDeclNext(metadata:Array<Metadata>, modifiers:Array<Token>, keyword:Token):FunctionDecl {
		return {
			metadata: metadata,
			modifiers: modifiers,
			keyword: keyword,
			name: expectKind(TkIdent),
			fun: parseFunctionNext()
		};
	}

	function parseInterfaceMember():Null<InterfaceMember> {
		var metadata = parseSequence(parseOptionalMetadata);
		var token = scanner.advance();
		if (token.kind != TkIdent)
			return null;

		switch token.text {
			case "function":
				return MIField(parseInterfaceFunNext(metadata, scanner.consume()));
			case _:
				var token = scanner.consume();
				switch scanner.advance().kind {
					case TkColonColon:
						var ns = token;
						var sep = scanner.consume();
						var name = expectKind(TkIdent);
						var openBrace = expectKind(TkBraceOpen);
						var members = parseSequence(parseInterfaceMember);
						var closeBrace = expectKind(TkBraceClose);
						var condComp = {ns: ns, sep: sep, name: name};
						return MICondComp(condComp, openBrace, members, closeBrace);
					case other:
						throw "unexpected token: " + other;
				}
		}
		return null;
	}

	function parseInterfaceFunNext(metadata:Array<Metadata>, keyword:Token):InterfaceField {
		var name, propKind;
		var nameToken = expectKind(TkIdent);
		switch nameToken.text {
			case type = "get" | "set" if (scanner.advance().kind == TkIdent):
				name = scanner.consume();
				propKind = if (type == "get") PGet(nameToken) else PSet(nameToken);
			case _:
				name = nameToken;
				propKind = null;
		}

		var signature = parseFunctionSignature();
		var semicolon = expectKind(TkSemicolon);

		return {
			metadata: metadata,
			kind: if (propKind == null) IFFun(keyword, name, signature) else IFProp(keyword, propKind, name, signature),
			semicolon: semicolon
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

	function parseSeparated<T>(parsePart:Void->T, checkSep:PeekToken->Bool):Separated<T> {
		var first = parsePart();
		return parseSeparatedNext(first, parsePart, checkSep);
	}

	function parseSeparatedNext<T>(first:T, parsePart:Void->T, checkSep:PeekToken->Bool):Separated<T> {
		var rest = [];
		while (true) {
			var token = scanner.advance();
			if (checkSep(token)) {
				var sep = scanner.consume();
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

	function parseDotPathNext(first:Token):DotPath {
		return parseSeparatedNext(first, expectKind.bind(TkIdent), t -> t.kind == TkDot);
	}

	function expect(check, msg) {
		var token = scanner.advance();
		return if (check(token)) scanner.consume() else throw msg;
	}

	function expectKind(kind) {
		return expect(t -> t.kind == kind, 'Expected token: ${kind.getName()}');
	}

	function expectKeyword(name) {
		return expect(t -> t.kind == TkIdent && t.text == name, 'Expected keyword: $name');
	}
}
