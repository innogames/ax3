package ax3;

import ax3.ParseTree;
import ax3.Token;

class Parser {
	var scanner:Scanner;
	var path:String;

	public function new(scanner, path) {
		this.scanner = scanner;
		this.path = path;
	}

	public inline function parse() return parseFile();

	function parseFile():File {
		return {
			path: path,
			name: new haxe.io.Path(path).file,
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
				case [TkIdent, "public"]:
					modifiers.push(DMPublic(scanner.consume()));
				case [TkIdent, "internal"]:
					modifiers.push(DMInternal(scanner.consume()));
				case [TkIdent, "final"]:
					modifiers.push(DMFinal(scanner.consume()));
				case [TkIdent, "dynamic"]:
					modifiers.push(DMDynamic(scanner.consume()));
				case [TkIdent, "class"]:
					return DClass(parseClassNext(metadata, modifiers, scanner.consume()));
				case [TkIdent, "interface"]:
					return DInterface(parseInterfaceNext(metadata, modifiers, scanner.consume()));
				case [TkIdent, "function"]:
					return DFunction(parseFunctionDeclNext(metadata, modifiers, scanner.consume()));
				case [TkIdent, "var"]:
					return DVar(parseModuleVarDeclNext(metadata, modifiers, VVar(scanner.consume())));
				case [TkIdent, "const"]:
					return DVar(parseModuleVarDeclNext(metadata, modifiers, VConst(scanner.consume())));
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

	function parseOptionalCallArgs():Null<CallArgs> {
		return switch scanner.advance().kind {
			case TkParenOpen:
				parseCallArgsNext(scanner.consume());
			case _:
				null;
		}
	}

	function parseMetadataNext(openBracket:Token):Metadata {
		var name = expectKind(TkIdent);
		var args = parseOptionalCallArgs();
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
						wildcard = {dot: dot, asterisk: scanner.consume()};
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

	function parseClassNext(metadata:Array<Metadata>, modifiers:Array<DeclModifier>, keyword:Token):ClassDecl {
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
		var namespaceSetted: Bool = false;
		while (true) {
			var token = scanner.advance();

			switch token.kind {
				case TkBraceOpen:
					var initBlock = parseBracedExprBlock(scanner.consume());
					return MStaticInit(initBlock);
				case TkIdent:
					// the logic follows
				case _:
					return null;
			}

			switch token.text {
				case "public":
					if (namespaceSetted) throw "Namespace setted";
					modifiers.push(FMPublic(scanner.consume()));
					namespaceSetted = true;
				case "private":
					if (namespaceSetted) throw "Namespace setted";
					modifiers.push(FMPrivate(scanner.consume()));
					namespaceSetted = true;
				case "protected":
					if (namespaceSetted) throw "Namespace setted";
					modifiers.push(FMProtected(scanner.consume()));
					namespaceSetted = true;
				case "internal":
					if (namespaceSetted) throw "Namespace setted";
					modifiers.push(FMInternal(scanner.consume()));
					namespaceSetted = true;
				case "override":
					modifiers.push(FMOverride(scanner.consume()));
				case "static":
					modifiers.push(FMStatic(scanner.consume()));
				case "final":
					modifiers.push(FMFinal(scanner.consume()));
				case "var":
					return MField(parseClassVarNext(metadata, namespace, modifiers, VVar(scanner.consume())));
				case "const":
					return MField(parseClassVarNext(metadata, namespace, modifiers, VConst(scanner.consume())));
				case "function":
					return MField(parseClassFunNext(metadata, namespace, modifiers, scanner.consume()));
				case text:
					if (modifiers.length > 0) {
						if (!namespaceSetted) {
							modifiers.push(FMPublic(scanner.consume()));
							namespaceSetted = true;
							continue;
						} else {
							throw "Modifiers without declaration";
						}
					}
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

	function parseClassVarNext(metadata:Array<Metadata>, namespace:Null<Token>, modifiers:Array<ClassFieldModifier>, kind:VarDeclKind):ClassField {
		var vars = parseVarDecls();
		var semicolon = expectKind(TkSemicolon);
		return {
			metadata: metadata,
			namespace: namespace,
			modifiers: modifiers,
			kind: FVar(kind, vars, semicolon)
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
			return {equalsToken: equals, expr: expr};
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

	function parseClassFunNext(metadata:Array<Metadata>, namespace:Null<Token>, modifiers:Array<ClassFieldModifier>, keyword:Token):ClassField {
		var kind;
		var nameToken = expectKind(TkIdent);
		switch nameToken.text {
			case type = "get" | "set" if (scanner.advance().kind == TkIdent):
				var name = scanner.consume();
				var fun = parseFunctionNext();
				kind =
					if (type == "get") FGetter(keyword, nameToken, name, fun)
					else FSetter(keyword, nameToken, name, fun);
			case _:
				kind = FFun(keyword, nameToken, parseFunctionNext());
		}

		return {
			metadata: metadata,
			namespace: namespace,
			modifiers: modifiers,
			kind: kind
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
				return ArgNormal(parseVarDeclNext(scanner.consume()));
			case TkDotDotDot:
				return ArgRest(scanner.consume(), expectKind(TkIdent), parseOptionalTypeHint());
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

	function parseVarDeclNext(name:Token):VarDecl {
		var type = parseOptionalTypeHint();
		var init = parseOptionalVarInit();
		return {name: name, type: type, init: init};
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
				throw "Unexpected token for type hint: " + token;
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
			case TkColonColon:
				Utils.printerr('Skip expression ' + scanner.consume().toString());
				scanner.advance();
				Utils.printerr('Skip expression ' + scanner.consume().toString());
				return {expr: EIdent(new Token(-1, TkIdent, "null", [], [])), semicolon: null}; // todo
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
				return makePreUnop(PreNot(scanner.consume()), parseExpr(allowComma));
			case TkTilde:
				return makePreUnop(PreBitNeg(scanner.consume()), parseExpr(allowComma));
			case TkMinus:
				var minusToken = scanner.consume();
				if (minusToken.trailTrivia.length == 0) {
					inline function mkNegative(ctor:Token->Literal, numberToken:Token):Expr {
						return parseExprNext(ELiteral(ctor(new Token(minusToken.pos, numberToken.kind, minusToken.text + numberToken.text, minusToken.leadTrivia, numberToken.trailTrivia))), allowComma);
					}
					switch scanner.advanceExprStart() {
						case {kind: TkDecimalInteger, leadTrivia: []}:
							return mkNegative(LDecInt, scanner.consume());
						case {kind: TkHexadecimalInteger, leadTrivia: []}:
							return mkNegative(LHexInt, scanner.consume());
						case {kind: TkFloat, leadTrivia: []}:
							return mkNegative(LFloat, scanner.consume());
						case _:
					}
				}
				return makePreUnop(PreNeg(minusToken), parseExpr(allowComma));

			case TkPlusPlus:
				return makePreUnop(PreIncr(scanner.consume()), parseExpr(allowComma));
			case TkMinusMinus:
				return makePreUnop(PreDecr(scanner.consume()), parseExpr(allowComma));
			case TkBracketOpen:
				return parseExprNext(EArrayDecl(parseArrayDecl(scanner.consume())), allowComma);
			case _:
				return null;
		}
	}

	function makePreUnop(op:PreUnop, e:Expr):Expr {
		return switch e {
			case EBinop(a, bop, b):
				EBinop(makePreUnop(op, a), bop, b);
			case ETernary(econd, question, ethen, colon, eelse):
				ETernary(makePreUnop(op, econd), question, ethen, colon, eelse);
			case _:
				EPreUnop(op, e);
		}
	}

	function parseIdent(consumedToken:Token, allowComma:Bool):Expr {
		switch consumedToken.text {
			case "new":
				return parseNewNext(consumedToken, allowComma);
			case "typeof":
				return ETypeof(consumedToken, parseExpr(allowComma));
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
			case "var":
				return EVars(VVar(consumedToken), parseVarDecls());
			case "const":
				return EVars(VConst(consumedToken), parseVarDecls());
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
			case TkIdent | TkStringSingle | TkStringDouble | TkDecimalInteger:
				var stringOrIdentOrInt = scanner.consume();
				switch scanner.advance().kind {
					case TkColon:
						return parseObjectNext(openBrace, stringOrIdentOrInt, scanner.consume());
					case _:
						var firstExpr = switch stringOrIdentOrInt.kind {
							case TkIdent: parseIdent(stringOrIdentOrInt, true);
							case TkStringSingle | TkStringDouble: return parseExprNext(ELiteral(LString(stringOrIdentOrInt)), true);
							case TkDecimalInteger: return parseExprNext(ELiteral(LDecInt(stringOrIdentOrInt)), true);
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
		var first = makeObjectField(firstIdent, firstColon, parseExpr(false));
		var fields = parseSeparatedNext(first, function() {
			return switch scanner.advance().kind {
				case TkIdent | TkStringSingle | TkStringDouble | TkDecimalInteger:
					makeObjectField(scanner.consume(), expectKind(TkColon), parseExpr(false));
				case _:
					throw "Object keys must be identifiers or strings";
			}
		}, t -> t.kind == TkComma);
		var closeBrace = expectKind(TkBraceClose);
		return EObjectDecl(openBrace, fields, closeBrace);
	}

	static function makeObjectField(name:Token, colon:Token, expr:Expr):ObjectField {
		return {
			name: name,
			nameKind: switch name.kind {
				case TkIdent: FNIdent;
				case TkStringSingle: FNStringSingle;
				case TkStringDouble: FNStringDouble;
				case TkDecimalInteger: FNInteger;
				case _: throw "assert";
			},
			colon: colon,
			value: expr
		};
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
		return parseSeparated(() -> parseVarDeclNext(expectKind(TkIdent)), t -> t.kind == TkComma);
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
				{keyword: scanner.consume(), expr: parseExpr(true), semiliconBefore: false};
			case {kind: TkSemicolon, text: ";"}:
				scanner.savePos();
				scanner.consume();
				switch scanner.advance() {
					case {kind: TkIdent, text: "else"}:
						{keyword: scanner.consume(), expr: parseExpr(true), semiliconBefore: true};
					case _:
						scanner.cancelConsume();
						scanner.restorePos();
						null;
				}
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
		return EWhile({
			keyword: keyword,
			openParen: openParen,
			cond: econd,
			closeParen: closeParen,
			body: ebody
		});
	}

	function parseDoWhile(doKeyword:Token):Expr {
		var ebody = parseExpr(true);
		var whileKeyword = expectKeyword("while");
		var openParen = expectKind(TkParenOpen);
		var econd = parseExpr(true);
		var closeParen = expectKind(TkParenClose);
		return EDoWhile({
			doKeyword: doKeyword,
			body: ebody,
			whileKeyword: whileKeyword,
			openParen: openParen,
			cond: econd,
			closeParen: closeParen
		});
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
						EForIn({
							forKeyword: keyword,
							openParen: openParen,
							iter: forIter,
							closeParen: closeParen,
							body: ebody
						});
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
		return EForEach({
			forKeyword: forKeyword,
			eachKeyword: eachKeyword,
			openParen: openParen,
			iter: iter,
			closeParen: closeParen,
			body: body
		});
	}

	function parseCFor(forKeyword:Token, openParen:Token, einit:Expr):Expr {
		var einitSep = expectKind(TkSemicolon);
		var econd = parseOptionalExpr(true);
		var econdSep = expectKind(TkSemicolon);
		var eincr = parseOptionalExpr(true);
		var closeParen = expectKind(TkParenClose);
		var ebody = parseExpr(true);
		return EFor({
			keyword: forKeyword,
			openParen: openParen,
			einit: einit,
			initSep: einitSep,
			econd: econd,
			condSep: econdSep,
			eincr: eincr,
			closeParen: closeParen,
			body: ebody
		});
	}

	function parseNewNext(keyword:Token, allowComma:Bool):Expr {
		return switch scanner.advance().kind {
			case TkLt:
				var t = parseTypeParam(scanner.consume());
				var decl = parseArrayDecl(expectKind(TkBracketOpen));
				EVectorDecl(keyword, t, decl);
			case _:
				var newObject = parseNewObject();
				var args = parseOptionalCallArgs();
				parseExprNext(ENew(keyword, newObject, args), allowComma);
		}
	}

	// parse limited set of expressions for the `new` operator
	function parseNewObject():Expr {
		var token = scanner.advance();
		return switch token.kind {
			case TkParenOpen:
				// anything in parens
				EParens(scanner.consume(), parseExpr(true), expectKind(TkParenClose));
			case TkIdent if (token.text == "Vector"):
				// new Vector.<type>
				EVector(parseVectorSyntax(scanner.consume()));
			case TkIdent:
				// some or some.Field or some[expr]
				parseNewFieldsNext(EIdent(scanner.consume()));
			case other:
				throw "unexpected token: " + other;
		}
	}

	function parseNewFieldsNext(first:Expr):Expr {
		return switch scanner.advance().kind {
			case TkDot:
				parseNewFieldsNext(EField(first, scanner.consume(), expectKind(TkIdent)));
			case TkBracketOpen:
				var openBracket = scanner.consume();
				var eindex = parseExpr(true);
				var closeBracket = expectKind(TkBracketClose);
				return parseNewFieldsNext(EArrayAccess(first, openBracket, eindex, closeBracket));
			case _: first;
		}
	}

	function parseExprNext(first:Expr, allowComma:Bool) {
		var token = scanner.advance();
		switch token.kind {
			case TkParenOpen:
				return parseExprNext(ECall(first, parseCallArgsNext(scanner.consume())), allowComma);
			case TkDot:
				var dot = scanner.consume();
				switch scanner.advance().kind {
					case TkAt:
						var at = scanner.consume();
						switch scanner.advance().kind {
							case TkIdent:
								return parseExprNext(EXmlAttr(first, dot, at, scanner.consume()), allowComma);
							case TkBracketOpen:
								return parseExprNext(EXmlAttrExpr(first, dot, at, scanner.consume(), parseExpr(true), expectKind(TkBracketClose)), allowComma);
							case _:
								throw "Invalid @ syntax: @field or @[expr] expected";
						}
					case TkIdent:
						return parseExprNext(EField(first, dot, scanner.consume()), allowComma);
					case _:
						throw "Invalid dot access expression: fieldName or @fieldName expected";
				}
			case TkDotDot:
				return parseExprNext(EXmlDescend(first, scanner.consume(), expectKind(TkIdent)), allowComma);
			case TkPlus:
				return parseBinop(first, OpAdd, allowComma);
			case TkPlusEquals:
				return parseBinop(first, t -> OpAssignOp(AOpAdd(t)), allowComma);
			case TkPlusPlus:
				return parseExprNext(EPostUnop(first, PostIncr(scanner.consume())), allowComma);
			case TkMinus:
				return parseBinop(first, OpSub, allowComma);
			case TkMinusEquals:
				return parseBinop(first, t -> OpAssignOp(AOpSub(t)), allowComma);
			case TkMinusMinus:
				return parseExprNext(EPostUnop(first, PostDecr(scanner.consume())), allowComma);
			case TkAsterisk:
				return parseBinop(first, OpMul, allowComma);
			case TkAsteriskEquals:
				return parseBinop(first, t -> OpAssignOp(AOpMul(t)), allowComma);
			case TkSlash:
				return parseBinop(first, OpDiv, allowComma);
			case TkSlashEquals:
				return parseBinop(first, t -> OpAssignOp(AOpDiv(t)), allowComma);
			case TkPercent:
				return parseBinop(first, OpMod, allowComma);
			case TkPercentEquals:
				return parseBinop(first, t -> OpAssignOp(AOpMod(t)), allowComma);
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
				return parseBinop(first, t -> OpAssignOp(AOpShl(t)), allowComma);
			case TkLtEquals:
				return parseBinop(first, OpLte, allowComma);
			case TkGt:
				return parseBinop(first, OpGt, allowComma);
			case TkGtGt:
				return parseBinop(first, OpShr, allowComma);
			case TkGtGtEquals:
				return parseBinop(first, t -> OpAssignOp(AOpShr(t)), allowComma);
			case TkGtGtGt:
				return parseBinop(first, OpUshr, allowComma);
			case TkGtGtGtEquals:
				return parseBinop(first, t -> OpAssignOp(AOpUshr(t)), allowComma);
			case TkGtEquals:
				return parseBinop(first, OpGte, allowComma);
			case TkAmpersand:
				return parseBinop(first, OpBitAnd, allowComma);
			case TkAmpersandAmpersand:
				return parseBinop(first, OpAnd, allowComma);
			case TkAmpersandAmpersandEquals:
				return parseBinop(first, t -> OpAssignOp(AOpAnd(t)), allowComma);
			case TkAmpersandEquals:
				return parseBinop(first, t -> OpAssignOp(AOpBitAnd(t)), allowComma);
			case TkPipe:
				return parseBinop(first, OpBitOr, allowComma);
			case TkPipePipe:
				return parseBinop(first, OpOr, allowComma);
			case TkPipePipeEquals:
				return parseBinop(first, t -> OpAssignOp(AOpOr(t)), allowComma);
			case TkPipeEquals:
				return parseBinop(first, t -> OpAssignOp(AOpBitOr(t)), allowComma);
			case TkCaret:
				return parseBinop(first, OpBitXor, allowComma);
			case TkCaretEquals:
				return parseBinop(first, t -> OpAssignOp(AOpBitXor(t)), allowComma);
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
						return parseBinop(first, OpIs, allowComma);
					case "as":
						return parseExprNext(EAs(first, scanner.consume(), parseSyntaxType(false)), allowComma);
					case _:
				}
			case TkComma if (allowComma):
				return parseBinop(first, OpComma, true);
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
		return makeBinop(a, ctor(scanner.consume()), parseExpr(allowComma));
	}

	function makeBinop(a:Expr, op:Binop, b:Expr):Expr {
		// TODO: handle comma (x?x:x,y)
		// TODO: move trivia to the correct place
		return switch (b) {
			case EBinop(a2, op2, b2) if (binopNeedsSwap(op, op2)):
				var a2 = makeBinop(a, op, a2);
				EBinop(a2, op2, b2);
			case ETernary(econd, question, ethen, colon, eelse) if (binopHigherThanTernary(op)):
				econd = makeBinop(a, op, econd);
				ETernary(econd, question, ethen, colon, eelse);
			case _:
				EBinop(a, op, b);
		}
	}

	function binopHigherThanTernary(op:Binop) {
		return switch (op) {
			case OpAssign(_) | OpAssignOp(_) | OpComma(_):
				false;
			case _:
				true;
		}
	}

	function binopNeedsSwap(op1:Binop, op2:Binop):Bool {
		var i1 = binopPrecedence(op1);
		var i2 = binopPrecedence(op2);
		return (i1.p < i2.p) || (i1.assoc == Left && i1.p == i2.p);
	}

	// https://help.adobe.com/en_US/as3/learn/WS5b3ccc516d4fbf351e63e3d118a9b90204-7fd1.html
	static function binopPrecedence(op:Binop):{p:Int, assoc:BinopAssoc} {
		return switch op {
			// Multiplicative
			case OpMul(_) | OpDiv(_) | OpMod(_):
				{p: 0, assoc: Left};

			// Additive
			case OpAdd(_) | OpSub(_):
				{p: 1, assoc: Left};

			// Bitwise shift
			case OpShl(_) | OpShr(_) | OpUshr(_):
				{p: 2, assoc: Left};

			// Relational
			case OpGt(_) | OpGte(_) | OpLt(_) | OpLte(_) | OpIn(_) | OpIs(_):
				{p: 3, assoc: Left};

			// Equality
			case OpEquals(_) | OpNotEquals(_) | OpStrictEquals(_) | OpNotStrictEquals(_):
				{p: 4, assoc: Left};

			// Bitwise AND
			case OpBitAnd(_):
				{p: 5, assoc: Left};

			// Bitwise XOR
			case OpBitXor(_):
				{p: 6, assoc: Left};

			// Bitwise OR
			case OpBitOr(_):
				{p: 7, assoc: Left};

			// Logical AND
			case OpAnd(_):
				{p: 8, assoc: Left};

			// Logical OR
			case OpOr(_):
				{p: 9, assoc: Left};

			// Assignment
			case OpAssign(_) | OpAssignOp(_):
				{p: 10, assoc: Right};

			case OpComma(_):
				{p: 11, assoc: Left};
		}
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

	function parseInterfaceNext(metadata:Array<Metadata>, modifiers:Array<DeclModifier>, keyword:Token):InterfaceDecl {
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

	function parseFunctionDeclNext(metadata:Array<Metadata>, modifiers:Array<DeclModifier>, keyword:Token):FunctionDecl {
		return {
			metadata: metadata,
			modifiers: modifiers,
			keyword: keyword,
			name: expectKind(TkIdent),
			fun: parseFunctionNext()
		};
	}

	function parseModuleVarDeclNext(metadata:Array<Metadata>, modifiers:Array<DeclModifier>, kind:VarDeclKind):ModuleVarDecl {
		return {
			metadata: metadata,
			modifiers: modifiers,
			kind: kind,
			vars: parseVarDecls(),
			semicolon: expectKind(TkSemicolon)
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
		var kind;
		var nameToken = expectKind(TkIdent);
		switch nameToken.text {
			case type = "get" | "set" if (scanner.advance().kind == TkIdent):
				var name = scanner.consume();
				var signature = parseFunctionSignature();
				kind =
					if (type == "get") IFGetter(keyword, nameToken, name, signature)
					else IFSetter(keyword, nameToken, name, signature);
			case _:
				kind = IFFun(keyword, nameToken, parseFunctionSignature());
		}

		var semicolon = expectKind(TkSemicolon);

		return {
			metadata: metadata,
			kind: kind,
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

private enum abstract BinopAssoc(Int) {
	var Left;
	var Right;
}
