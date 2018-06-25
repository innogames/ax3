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
		var metadata = parseSequence(parseOptionalMetadata);
		while (true) {
			var token = stream.advance();
			switch [token.kind, token.text] {
				case [TkIdent, "import"]:
					if (modifiers.length > 0)
						throw "Import statements cannot have modifiers";
					if (metadata.length > 0)
						throw "Import statements cannot have metadata";
					return DImport(parseImportNext(stream.consume()));
				case [TkIdent, "public" | "internal" | "final" | "dynamic"]:
					modifiers.push(stream.consume());
				case [TkIdent, "class"]:
					return DClass(parseClassNext(metadata, modifiers, stream.consume()));
				case [TkIdent, "interface"]:
					return DInterface(parseInterfaceNext(metadata, modifiers, stream.consume()));
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
		return switch stream.advance().kind {
			case TkBracketOpen: parseMetadataNext(stream.consume());
			case _: null;
		}
	}

	function parseMetadataNext(openBracket:TokenInfo):Metadata {
		var name = expectKind(TkIdent);
		var args = switch stream.advance().kind {
			case TkParenOpen:
				parseCallArgsNext(stream.consume());
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

	function parseClassNext(metadata:Array<Metadata>, modifiers:Array<TokenInfo>, keyword:TokenInfo):ClassDecl {
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
		var metadata = parseSequence(parseOptionalMetadata);
		while (true) {
			var token = stream.advance();
			switch [token.kind, token.text] {
				case [TkIdent, "public" | "private" | "protected" | "internal" | "override" | "static"]:
					modifiers.push(stream.consume());
				case [TkIdent, "var" | "const"]:
					return parseClassVarNext(metadata, modifiers, stream.consume());
				case [TkIdent, "function"]:
					return parseClassFunNext(metadata, modifiers, stream.consume());
				case _:
					if (modifiers.length > 0)
						throw "Modifiers without declaration";
					if (metadata.length > 0)
						throw "Metadata without declaration";
					return null;
			}
		}
	}

	function parseClassVarNext(metadata:Array<Metadata>, modifiers:Array<TokenInfo>, keyword:TokenInfo):ClassField {
		var name = expectKind(TkIdent);
		var hint = parseOptionalTypeHint();
		var init = parseOptionalVarInit();
		var semicolon = expectKind(TkSemicolon);
		return {
			metadata: metadata,
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
		var token = stream.advance();
		if (token.kind == TkEquals) {
			var equals = stream.consume();
			var expr = parseExpr();
			return {equals: equals, expr: expr};
		} else {
			return null;
		}
	}

	function parseClassFunNext(metadata:Array<Metadata>, modifiers:Array<TokenInfo>, keyword:TokenInfo):ClassField {
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
			modifiers: modifiers,
			name: name,
			kind: if (propKind == null) FFun(fun) else FProp(propKind, fun)
		};
	}

	function parseBracedExprBlock(openBrace:TokenInfo):BracedExprBlock {
		return {
			openBrace: openBrace,
			exprs: parseSequence(parseOptionalBlockExpr),
			closeBrace: expectKind(TkBraceClose)
		}
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

	function parseSyntaxType(allowAny:Bool):SyntaxType {
		var token = stream.advance();
		switch token.kind {
			case TkAsterisk if (allowAny):
				return TAny(stream.consume());
			case TkIdent if (token.text == "Vector"): // vector is special and should contain type params
				return TVector(parseVectorSyntax(stream.consume()));
			case TkIdent:
				return TPath(parseDotPathNext(stream.consume()));
			case _:
				throw "Unexpected token for type hint";
		}
	}

	function parseVectorSyntax(name:TokenInfo):VectorSyntax {
		return {
			name: name,
			dot: expectKind(TkDot),
			t: parseTypeParam(expectKind(TkLt))
		};
	}

	function parseTypeParam(lt:TokenInfo):TypeParam {
		var type = parseSyntaxType(true);
		var gt = switch stream.advanceAndSplitGt().kind {
			case TkGt: stream.consume();
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
		var semicolon = if (expr != null && stream.lastConsumedToken.token.kind != TkBraceClose) expectKind(TkSemicolon) else null;
		return {expr: expr, semicolon: semicolon};
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
					case "new":
						return parseNewNext(stream.consume());
					case "return":
						return EReturn(stream.consume(), parseOptionalExpr());
					case "throw":
						return EThrow(stream.consume(), parseExpr());
					case "delete":
						return EDelete(stream.consume(), parseExpr());
					case "if":
						return parseIf(stream.consume());
					case "switch":
						return parseSwitch(stream.consume());
					case "while":
						return parseWhile(stream.consume());
					case "for":
						return parseFor(stream.consume());
					case "break":
						return EBreak(stream.consume());
					case "continue":
						return EContinue(stream.consume());
					case "var" | "const":
						return parseVars(stream.consume());
					case "try":
						return parseTry(stream.consume());
					case "Vector":
						return parseExprNext(EVector(parseVectorSyntax(stream.consume())));
					case "case" | "default": // not part of expression
						return null;
					case _:
						return parseIdent(stream.consume());
				}
			case TkStringSingle | TkStringDouble:
				return parseExprNext(ELiteral(LString(stream.consume())));
			case TkDecimalInteger:
				return parseExprNext(ELiteral(LDecInt(stream.consume())));
			case TkHexadecimalInteger:
				return parseExprNext(ELiteral(LHexInt(stream.consume())));
			case TkFloat:
				return parseExprNext(ELiteral(LFloat(stream.consume())));
			case TkParenOpen:
				return parseExprNext(EParens(stream.consume(), parseExpr(), expectKind(TkParenClose)));
			case TkBraceOpen:
				return parseBlockOrObject(stream.consume());
			case TkExclamation:
				return EPreUnop(PreNot(stream.consume()), parseExpr());
			case TkMinus:
				return EPreUnop(PreNeg(stream.consume()), parseExpr());
			case TkPlusPlus:
				return EPreUnop(PreIncr(stream.consume()), parseExpr());
			case TkMinusMinus:
				return EPreUnop(PreDecr(stream.consume()), parseExpr());
			case TkBracketOpen:
				return parseExprNext(EArrayDecl(parseArrayDecl(stream.consume())));
			case _:
				return null;
		}
	}

	function parseIdent(token:TokenInfo):Expr {
		switch stream.advance().kind {
			case TkColonColon:
				// conditional compilation
				var sep = stream.consume();
				var name = expectKind(TkIdent);
				var condComp = {ns: token, sep: sep, name: name};
				switch stream.advance().kind {
					case TkBraceOpen:
						return ECondCompBlock(condComp, parseBracedExprBlock(stream.consume()));
					case _:
						return ECondCompValue(condComp);
				}
			case _:
				// just an indentifier
				return parseExprNext(EIdent(token));
		}
	}

	function parseBlockOrObject(openBrace:TokenInfo):Expr {
		var token = stream.advance();
		switch token.kind {
			case TkBraceClose:
				return EBlock({openBrace: openBrace, exprs: [], closeBrace: stream.consume()});
			case TkIdent | TkStringSingle | TkStringDouble if (stream.peekAfter(token).kind == TkColon):
				return parseObjectNext(openBrace);
			case _:
				return EBlock(parseBracedExprBlock(openBrace));
		}
	}

	function parseObjectNext(openBrace:TokenInfo):Expr {
		var fields = parseSeparated(function() {
			return switch stream.advance().kind {
				case TkIdent | TkStringSingle | TkStringDouble:
					var name = stream.consume();
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

	function parseArrayDecl(openBracket:TokenInfo):ArrayDecl {
		return switch stream.advance().kind {
			case TkBracketClose:
				{openBracket: openBracket, elems: null, closeBracket: stream.consume()};
			case _:
				var elems = parseSeparated(parseExpr, t -> t.kind == TkComma);
				{openBracket: openBracket, elems: elems, closeBracket: expectKind(TkBracketClose)};
		};
	}

	function parseVars(keyword:TokenInfo):Expr {
		// TODO: disable comma expression parsing here
		var vars = parseSeparated(function() {
			var firstName = expectKind(TkIdent);
			var type = parseOptionalTypeHint();
			var init = parseOptionalVarInit();
			return {name: firstName, type: type, init: init};
		}, t -> t.kind == TkComma);
		return EVars(keyword, vars);
	}

	function parseTry(keyword:TokenInfo):Expr {
		var block = parseBracedExprBlock(expectKind(TkBraceOpen));
		var catches = parseSequence(function():Catch {
			return switch stream.advance() {
				case {kind: TkIdent, text: "catch"}:
					{
						keyword: stream.consume(),
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

		var finally = switch stream.advance() {
			case {kind: TkIdent, text: "finally"}:
				{keyword: stream.consume(), block: parseBracedExprBlock(expectKind(TkBraceOpen))};
			case _:
				null;
		}

		return ETry(keyword, block, catches, finally);
	}

	function parseIf(keyword:TokenInfo):Expr {
		var openParen = expectKind(TkParenOpen);
		var econd = parseExpr();
		var closeParen = expectKind(TkParenClose);
		var ethen = parseExpr();
		var eelse = switch stream.advance() {
			case {kind: TkIdent, text: "else"}:
				{keyword: stream.consume(), expr: parseExpr()};
			case _:
				null;
		}
		return EIf(keyword, openParen, econd, closeParen, ethen, eelse);
	}

	function parseSwitch(keyword:TokenInfo):Expr {
		var openParen = expectKind(TkParenOpen);
		var esubj = parseExpr();
		var closeParen = expectKind(TkParenClose);
		var openBrace = expectKind(TkBraceOpen);
		var cases = parseSequence(function() {
			var token = stream.advance();
			return switch [token.kind, token.text] {
				case [TkIdent, "case"]:
					var keyword = stream.consume();
					var v = parseExpr();
					var colon = expectKind(TkColon);
					var exprs = parseSequence(parseOptionalBlockExpr);
					CCase(keyword, v, colon, exprs);

				case [TkIdent, "default"]:
					var keyword = stream.consume();
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

	function parseWhile(keyword:TokenInfo):Expr {
		var openParen = expectKind(TkParenOpen);
		var econd = parseExpr();
		var closeParen = expectKind(TkParenClose);
		var ebody = parseExpr();
		return EWhile(keyword, openParen, econd, closeParen, ebody);
	}

	function parseFor(keyword:TokenInfo):Expr {
		return switch stream.advance() {
			case {kind: TkIdent, text: "each"}:
				parseForEach(keyword, stream.consume());
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
				switch stream.advance() {
					case {kind: TkIdent, text: "in"}:
						{eit: expr, inKeyword: stream.consume(), eobj: parseExpr()}
					case _:
						null;
				}
		}
	}

	function parseForEach(forKeyword:TokenInfo, eachKeyword:TokenInfo):Expr {
		var openParen = expectKind(TkParenOpen);
		var iter = parseOptionalForIter(parseExpr());
		if (iter == null)
			throw "`a in b` expression expected for the `for each` loop";
		var closeParen = expectKind(TkParenClose);
		var body = parseExpr();
		return EForEach(forKeyword, eachKeyword, openParen, iter, closeParen, body);
	}

	function parseCFor(forKeyword:TokenInfo, openParen:TokenInfo, einit:Expr):Expr {
		var einitSep = expectKind(TkSemicolon);
		var econd = parseOptionalExpr();
		var econdSep = expectKind(TkSemicolon);
		var eincr = parseOptionalExpr();
		var closeParen = expectKind(TkParenClose);
		var ebody = parseExpr();
		return EFor(forKeyword, openParen, einit, einitSep, econd, econdSep, eincr, closeParen, ebody);
	}

	function parseNewNext(keyword:TokenInfo):Expr {
		return switch stream.advance().kind {
			case TkLt:
				var t = parseTypeParam(stream.consume());
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
		var token = stream.advance();
		switch token.kind {
			case TkParenOpen:
				return parseExprNext(ECall(first, parseCallArgsNext(stream.consume())));
			case TkDot:
				var dot = stream.consume();
				var fieldName = expectKind(TkIdent);
				return parseExprNext(EField(first, dot, fieldName));
			case TkPlus:
				return parseBinop(first, OpAdd);
			case TkPlusEquals:
				return parseBinop(first, OpAssignAdd);
			case TkPlusPlus:
				return parseExprNext(EPostUnop(first, PostIncr(stream.consume())));
			case TkMinus:
				return parseBinop(first, OpSub);
			case TkMinusEquals:
				return parseBinop(first, OpAssignSub);
			case TkMinusMinus:
				return parseExprNext(EPostUnop(first, PostDecr(stream.consume())));
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
			case TkPipe:
				return parseBinop(first, OpBitOr);
			case TkPipePipe:
				return parseBinop(first, OpOr);
			case TkCaret:
				return parseBinop(first, OpBitXor);
			case TkBracketOpen:
				var openBracket = stream.consume();
				var eindex = parseExpr();
				var closeBracket = expectKind(TkBracketClose);
				return parseExprNext(EArrayAccess(first, openBracket, eindex, closeBracket));
			case TkQuestion:
				return parseTernary(first, stream.consume());
			case TkIdent:
				switch token.text {
					case "in":
						return parseBinop(first, OpIn);
					case "is":
						return parseExprNext(EIs(first, stream.consume(), parseSyntaxType(false)));
					case "as":
						return parseExprNext(EAs(first, stream.consume(), parseSyntaxType(false)));
					case _:
				}
			case _:
		}
		return first;
	}

	function parseTernary(econd:Expr, question:TokenInfo):Expr {
		var ethen = parseExpr();
		var colon = expectKind(TkColon);
		var eelse = parseExpr();
		return ETernary(econd, question, ethen, colon, eelse);
	}

	function parseBinop(a:Expr, ctor:TokenInfo->Binop):Expr {
		// TODO: handle precedence here (swap expressions when needed)
		var token = stream.consume();
		var second = parseExpr();
		return parseExprNext(EBinop(a, ctor(token), second));
	}

	function parseCallArgsNext(openParen:TokenInfo):CallArgs {
		var token = stream.advance();
		switch token.kind {
			case TkParenClose:
				return {openParen: openParen, args: null, closeParen: stream.consume()};
			case _:
				var args = parseSeparated(parseExpr, t -> t.kind == TkComma);
				return {openParen: openParen, args: args, closeParen: expectKind(TkParenClose)};
		}
	}

	function parseInterfaceNext(metadata:Array<Metadata>, modifiers:Array<TokenInfo>, keyword:TokenInfo):InterfaceDecl {
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
			metadata: metadata,
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
