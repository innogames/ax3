import ParseTree;
import Token;

class Parser {
	var scanner:Scanner;

	public function new(scanner) {
		this.scanner = scanner;
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

	function parseDeclaration():Declaration {
		var modifiers = [];
		var metadata = parseSequence(parseOptionalMetadata);
		while (true) {
			var token = scanner.advance();
			switch [token.kind, token.text] {
				case [TkIdent, "import"]:
					if (modifiers.length > 0)
						throw "Import statements cannot have modifiers";
					if (metadata.length > 0)
						throw "Import statements cannot have metadata";
					return DImport(parseImportNext(scanner.consume()));
				case [TkIdent, "public" | "internal" | "final" | "dynamic"]:
					modifiers.push(scanner.consume());
				case [TkIdent, "class"]:
					return DClass(parseClassNext(metadata, modifiers, scanner.consume()));
				case [TkIdent, "interface"]:
					return DInterface(parseInterfaceNext(metadata, modifiers, scanner.consume()));
				case _:
					if (modifiers.length > 0)
						throw "Modifiers without declaration";
					if (metadata.length > 0)
						throw "Metadata without declaration";
					return null;
			}
		}
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

		var fields = parseSequence(parseClassField);

		var closeBrace = expectKind(TkBraceClose);

		return {
			metadata: metadata,
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
		var namespace = null;
		var metadata = parseSequence(parseOptionalMetadata);
		while (true) {
			var token = scanner.advance();
			switch [token.kind, token.text] {
				case [TkIdent, "public" | "private" | "protected" | "internal" | "override" | "static"]:
					modifiers.push(scanner.consume());
				case [TkIdent, "var" | "const"]:
					return parseClassVarNext(metadata, namespace, modifiers, scanner.consume());
				case [TkIdent, "function"]:
					return parseClassFunNext(metadata, namespace, modifiers, scanner.consume());
				case [TkIdent, _]:
					if (namespace != null)
						throw "Namespace already defined";
					else
						namespace = scanner.consume();
				case _:
					if (modifiers.length > 0)
						throw "Modifiers without declaration";
					if (metadata.length > 0)
						throw "Metadata without declaration";
					if (namespace != null)
						throw "Namespace without declaration";
					return null;
			}
		}
	}

	function parseClassVarNext(metadata:Array<Metadata>, namespace:Null<Token>, modifiers:Array<Token>, keyword:Token):ClassField {
		var name = expectKind(TkIdent);
		var hint = parseOptionalTypeHint();
		var init = parseOptionalVarInit();
		var semicolon = expectKind(TkSemicolon);
		return {
			metadata: metadata,
			namespace: namespace,
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
			var expr = parseExpr();
			return {equals: equals, expr: expr};
		} else {
			return null;
		}
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

		var openParen = expectKind(TkParenOpen);
		var args = parseFunctionArgs();
		var closeParen = expectKind(TkParenClose);
		var ret = parseOptionalTypeHint();
		var block = parseBracedExprBlock(expectKind(TkBraceOpen));

		var fun:ClassFun = {
			keyword: keyword,
			openParen: openParen,
			args: args,
			closeParen: closeParen,
			ret: ret,
			block: block,
		};

		return {
			metadata: metadata,
			namespace: namespace,
			modifiers: modifiers,
			name: name,
			kind: if (propKind == null) FFun(fun) else FProp(propKind, fun)
		};
	}

	function parseBracedExprBlock(openBrace:Token):BracedExprBlock {
		return {
			openBrace: openBrace,
			exprs: parseSequence(parseOptionalBlockExpr),
			closeBrace: expectKind(TkBraceClose)
		}
	}

	function parseFunctionArgs():Null<Separated<FunctionArg>> {
		var token = scanner.advance();
		if (token.kind == TkIdent) {
			var first = parseFunctionArgNext(scanner.consume());
			return parseSeparatedNext(first, parseFunctionArg, t -> t.kind == TkComma);
		} else {
			return null;
		}
	}

	function parseFunctionArg():FunctionArg {
		var name = expectKind(TkIdent);
		return parseFunctionArgNext(name);
	}

	function parseFunctionArgNext(name:Token):FunctionArg {
		var hint = parseOptionalTypeHint();
		var init = parseOptionalVarInit();
		return {name: name, hint: hint, init: init};
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
		var expr = parseOptionalExpr();
		if (expr == null)
			return null;
		return parseBlockExprNext(expr);
	}

	function parseBlockExprNext(expr:Expr):BlockElement {
		var semicolon = if (scanner.lastConsumedToken.kind != TkBraceClose) expectKind(TkSemicolon) else null;
		return {expr: expr, semicolon: semicolon};
	}

	function parseExpr():Expr {
		var expr = parseOptionalExpr();
		if (expr == null)
			throw "Expression expected";
		return expr;
	}

	function parseOptionalExpr():Null<Expr> {
		var token = scanner.advanceExprStart();
		switch token.kind {
			case TkIdent:
				if (token.text ==  "case" || token.text == "default") // not part of expression, so don't even consume the token
					return null;
				else
					return parseIdent(scanner.consume());
			case TkStringSingle | TkStringDouble:
				return parseExprNext(ELiteral(LString(scanner.consume())));
			case TkRegExp:
				return parseExprNext(ELiteral(LRegExp(scanner.consume())));
			case TkDecimalInteger:
				return parseExprNext(ELiteral(LDecInt(scanner.consume())));
			case TkHexadecimalInteger:
				return parseExprNext(ELiteral(LHexInt(scanner.consume())));
			case TkFloat:
				return parseExprNext(ELiteral(LFloat(scanner.consume())));
			case TkParenOpen:
				return parseExprNext(EParens(scanner.consume(), parseExpr(), expectKind(TkParenClose)));
			case TkBraceOpen:
				return parseBlockOrObject(scanner.consume());
			case TkExclamation:
				return EPreUnop(PreNot(scanner.consume()), parseExpr());
			case TkTilde:
				return EPreUnop(PreBitNeg(scanner.consume()), parseExpr());
			case TkMinus:
				return EPreUnop(PreNeg(scanner.consume()), parseExpr());
			case TkPlusPlus:
				return EPreUnop(PreIncr(scanner.consume()), parseExpr());
			case TkMinusMinus:
				return EPreUnop(PreDecr(scanner.consume()), parseExpr());
			case TkBracketOpen:
				return parseExprNext(EArrayDecl(parseArrayDecl(scanner.consume())));
			case _:
				return null;
		}
	}

	function parseIdent(consumedToken:Token):Expr {
		switch consumedToken.text {
			case "new":
				return parseNewNext(consumedToken);
			case "return":
				return EReturn(consumedToken, parseOptionalExpr());
			case "throw":
				return EThrow(consumedToken, parseExpr());
			case "delete":
				return EDelete(consumedToken, parseExpr());
			case "if":
				return parseIf(consumedToken);
			case "switch":
				return parseSwitch(consumedToken);
			case "while":
				return parseWhile(consumedToken);
			case "for":
				return parseFor(consumedToken);
			case "break":
				return EBreak(consumedToken);
			case "continue":
				return EContinue(consumedToken);
			case "var" | "const":
				return parseVars(consumedToken);
			case "try":
				return parseTry(consumedToken);
			case "Vector":
				return parseExprNext(EVector(parseVectorSyntax(consumedToken)));
			case _:
				return parseActualIdent(consumedToken);
		}
	}

	function parseActualIdent(token:Token):Expr {
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
				return parseExprNext(EIdent(token));
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
							case TkIdent: parseIdent(stringOrIdent);
							case TkStringSingle | TkStringDouble: return parseExprNext(ELiteral(LString(stringOrIdent)));
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
		var first = {name: firstIdent, colon: firstColon, value: parseExpr()};
		var fields = parseSeparatedNext(first, function() {
			return switch scanner.advance().kind {
				case TkIdent | TkStringSingle | TkStringDouble:
					var name = scanner.consume();
					var colon = expectKind(TkColon);
					var expr = parseExpr();
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
				var elems = parseSeparated(parseExpr, t -> t.kind == TkComma);
				{openBracket: openBracket, elems: elems, closeBracket: expectKind(TkBracketClose)};
		};
	}

	function parseVars(keyword:Token):Expr {
		// TODO: disable comma expression parsing here
		var vars = parseSeparated(function() {
			var firstName = expectKind(TkIdent);
			var type = parseOptionalTypeHint();
			var init = parseOptionalVarInit();
			return {name: firstName, type: type, init: init};
		}, t -> t.kind == TkComma);
		return EVars(keyword, vars);
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
		var econd = parseExpr();
		var closeParen = expectKind(TkParenClose);
		var ethen = parseExpr();
		var eelse = switch scanner.advance() {
			case {kind: TkIdent, text: "else"}:
				{keyword: scanner.consume(), expr: parseExpr()};
			case _:
				null;
		}
		return EIf(keyword, openParen, econd, closeParen, ethen, eelse);
	}

	function parseSwitch(keyword:Token):Expr {
		var openParen = expectKind(TkParenOpen);
		var esubj = parseExpr();
		var closeParen = expectKind(TkParenClose);
		var openBrace = expectKind(TkBraceOpen);
		var cases = parseSequence(function() {
			var token = scanner.advance();
			return switch [token.kind, token.text] {
				case [TkIdent, "case"]:
					var keyword = scanner.consume();
					var v = parseExpr();
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
		var econd = parseExpr();
		var closeParen = expectKind(TkParenClose);
		var ebody = parseExpr();
		return EWhile(keyword, openParen, econd, closeParen, ebody);
	}

	function parseFor(keyword:Token):Expr {
		return switch scanner.advance() {
			case {kind: TkIdent, text: "each"}:
				parseForEach(keyword, scanner.consume());
			case _:
				var openParen = expectKind(TkParenOpen);
				var einit = parseOptionalExpr();
				if (einit == null) {
					parseCFor(keyword, openParen, null);
				} else {
					var forIter = parseOptionalForIter(einit);
					if (forIter == null) {
						parseCFor(keyword, openParen, einit);
 					} else {
						var closeParen = expectKind(TkParenClose);
						var ebody = parseExpr();
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
						{eit: expr, inKeyword: scanner.consume(), eobj: parseExpr()}
					case _:
						null;
				}
		}
	}

	function parseForEach(forKeyword:Token, eachKeyword:Token):Expr {
		var openParen = expectKind(TkParenOpen);
		var iter = parseOptionalForIter(parseExpr());
		if (iter == null)
			throw "`a in b` expression expected for the `for each` loop";
		var closeParen = expectKind(TkParenClose);
		var body = parseExpr();
		return EForEach(forKeyword, eachKeyword, openParen, iter, closeParen, body);
	}

	function parseCFor(forKeyword:Token, openParen:Token, einit:Expr):Expr {
		var einitSep = expectKind(TkSemicolon);
		var econd = parseOptionalExpr();
		var econdSep = expectKind(TkSemicolon);
		var eincr = parseOptionalExpr();
		var closeParen = expectKind(TkParenClose);
		var ebody = parseExpr();
		return EFor(forKeyword, openParen, einit, einitSep, econd, econdSep, eincr, closeParen, ebody);
	}

	function parseNewNext(keyword:Token):Expr {
		return switch scanner.advance().kind {
			case TkLt:
				var t = parseTypeParam(scanner.consume());
				var decl = parseArrayDecl(expectKind(TkBracketOpen));
				EVectorDecl(keyword, t, decl);
			case _:
				switch parseExpr() {
					case ECall(e, args): ENew(keyword, e, args);
					case e: ENew(keyword, e, null);
				}
		}
	}

	function parseExprNext(first:Expr) {
		var token = scanner.advance();
		switch token.kind {
			case TkParenOpen:
				return parseExprNext(ECall(first, parseCallArgsNext(scanner.consume())));
			case TkDot:
				var dot = scanner.consume();
				var fieldName = expectKind(TkIdent);
				return parseExprNext(EField(first, dot, fieldName));
			case TkPlus:
				return parseBinop(first, OpAdd);
			case TkPlusEquals:
				return parseBinop(first, OpAssignAdd);
			case TkPlusPlus:
				return parseExprNext(EPostUnop(first, PostIncr(scanner.consume())));
			case TkMinus:
				return parseBinop(first, OpSub);
			case TkMinusEquals:
				return parseBinop(first, OpAssignSub);
			case TkMinusMinus:
				return parseExprNext(EPostUnop(first, PostDecr(scanner.consume())));
			case TkAsterisk:
				return parseBinop(first, OpMul);
			case TkAsteriskEquals:
				return parseBinop(first, OpAssignMul);
			case TkSlash:
				return parseBinop(first, OpDiv);
			case TkSlashEquals:
				return parseBinop(first, OpAssignDiv);
			case TkPercent:
				return parseBinop(first, OpMod);
			case TkPercentEquals:
				return parseBinop(first, OpAssignMod);
			case TkEquals:
				return parseBinop(first, OpAssign);
			case TkEqualsEquals:
				return parseBinop(first, OpEquals);
			case TkEqualsEqualsEquals:
				return parseBinop(first, OpStrictEquals);
			case TkExclamationEquals:
				return parseBinop(first, OpNotEquals);
			case TkExclamationEqualsEquals:
				return parseBinop(first, OpNotStrictEquals);
			case TkLt:
				return parseBinop(first, OpLt);
			case TkLtLt:
				return parseBinop(first, OpShl);
			case TkLtEquals:
				return parseBinop(first, OpLte);
			case TkGt:
				return parseBinop(first, OpGt);
			case TkGtGt:
				return parseBinop(first, OpShr);
			case TkGtGtGt:
				return parseBinop(first, OpUshr);
			case TkGtEquals:
				return parseBinop(first, OpGte);
			case TkAmpersand:
				return parseBinop(first, OpBitAnd);
			case TkAmpersandAmpersand:
				return parseBinop(first, OpAnd);
			case TkAmpersandEquals:
				return parseBinop(first, OpAssignBitAnd);
			case TkPipe:
				return parseBinop(first, OpBitOr);
			case TkPipePipe:
				return parseBinop(first, OpOr);
			case TkPipeEquals:
				return parseBinop(first, OpAssignBitOr);
			case TkCaret:
				return parseBinop(first, OpBitXor);
			case TkCaretEquals:
				return parseBinop(first, OpAssignBitXor);
			case TkBracketOpen:
				var openBracket = scanner.consume();
				var eindex = parseExpr();
				var closeBracket = expectKind(TkBracketClose);
				return parseExprNext(EArrayAccess(first, openBracket, eindex, closeBracket));
			case TkQuestion:
				return parseTernary(first, scanner.consume());
			case TkIdent:
				switch token.text {
					case "in":
						return parseBinop(first, OpIn);
					case "is":
						return parseExprNext(EIs(first, scanner.consume(), parseSyntaxType(false)));
					case "as":
						return parseExprNext(EAs(first, scanner.consume(), parseSyntaxType(false)));
					case _:
				}
			case _:
		}
		return first;
	}

	function parseTernary(econd:Expr, question:Token):Expr {
		var ethen = parseExpr();
		var colon = expectKind(TkColon);
		var eelse = parseExpr();
		return ETernary(econd, question, ethen, colon, eelse);
	}

	function parseBinop(a:Expr, ctor:Token->Binop):Expr {
		// TODO: handle precedence here (swap expressions when needed)
		var token = scanner.consume();
		var second = parseExpr();
		return parseExprNext(EBinop(a, ctor(token), second));
	}

	function parseCallArgsNext(openParen:Token):CallArgs {
		var token = scanner.advance();
		switch token.kind {
			case TkParenClose:
				return {openParen: openParen, args: null, closeParen: scanner.consume()};
			case _:
				var args = parseSeparated(parseExpr, t -> t.kind == TkComma);
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
		var fields = parseSequence(parseInterfaceField);
		var closeBrace = expectKind(TkBraceClose);
		return {
			metadata: metadata,
			modifiers: modifiers,
			keyword: keyword,
			name: name,
			extend: extend,
			openBrace: openBrace,
			fields: fields,
			closeBrace: closeBrace
		};
	}

	function parseInterfaceField():Null<InterfaceField> {
		var metadata = parseSequence(parseOptionalMetadata);
		var token = scanner.advance();
		if (token.kind == TkIdent && token.text == "function") {
			return parseInterfaceFunNext(metadata, scanner.consume());
		} else {
			return null;
		}
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

		var openParen = expectKind(TkParenOpen);
		var args = parseFunctionArgs();
		var closeParen = expectKind(TkParenClose);
		var ret = parseTypeHint();
		var semicolon = expectKind(TkSemicolon);

		var fun:InterfaceFun = {
			keyword: keyword,
			openParen: openParen,
			args: args,
			closeParen: closeParen,
			ret: ret,
		};

		return {
			metadata: metadata,
			name: name,
			kind: if (propKind == null) IFFun(fun) else IFProp(propKind, fun),
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
