package ax3;

import ax3.ParseTree;
import ax3.ParseTree.*;
import ax3.TypedTree;
import ax3.TypedTreeTools.mk;
import ax3.TypedTreeTools.tUntypedArray;
import ax3.TypedTreeTools.tUntypedObject;

typedef Locals = Map<String, TVar>;

class ExprTyper {
	final context:Context;
	final resolveType:SyntaxType->TType;
	final localsStack:Array<Locals>;
	var locals:Locals;
	var currentReturnType:TType;

	public function new(context, resolveType) {
		this.context = context;
		this.resolveType = resolveType;
		locals = new Map();
		localsStack = [locals];
	}

	inline function err(msg, pos) context.reportError("TODO", pos, msg);

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
			addLocal(arg.name, arg.type);
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
		return mk(TEBreak(new Token(0, TkIdent, "break", [], [])), TTAny, TTAny);
		// return switch (e) {
		// 	case EIdent(i):
		// 		typeIdent(i, e, expectedType);

		// 	case ELiteral(l):
		// 		typeLiteral(l, expectedType);

		// 	case ECall(e, args):
		// 		typeCall(e, args, expectedType);

		// 	case EParens(openParen, e, closeParen):
		// 		var e = typeExpr(e, expectedType);
		// 		mk(TEParens(openParen, e, closeParen), e.type, expectedType);

		// 	case EArrayAccess(e, openBracket, eindex, closeBracket):
		// 		typeArrayAccess(e, openBracket, eindex, closeBracket, expectedType);

		// 	case EArrayDecl(d):
		// 		typeArrayDecl(d, expectedType);

		// 	case EVectorDecl(newKeyword, t, d):
		// 		typeVectorDecl(newKeyword, t, d, expectedType);

		// 	case EReturn(keyword, eReturned):
		// 		if (expectedType != TTVoid) throw "assert";
		// 		mk(TEReturn(keyword, if (eReturned != null) typeExpr(eReturned, currentReturnType) else null), TTVoid, TTVoid);

		// 	case EThrow(keyword, e):
		// 		if (expectedType != TTVoid) throw "assert";
		// 		mk(TEThrow(keyword, typeExpr(e, TTAny)), TTVoid, TTVoid);

		// 	case EBreak(keyword):
		// 		if (expectedType != TTVoid) throw "assert";
		// 		mk(TEBreak(keyword), TTVoid, TTVoid);

		// 	case EContinue(keyword):
		// 		if (expectedType != TTVoid) throw "assert";
		// 		mk(TEContinue(keyword), TTVoid, TTVoid);

		// 	case EDelete(keyword, e):
		// 		mk(TEDelete(keyword, typeExpr(e, TTAny)), TTBoolean, expectedType);

		// 	case ENew(keyword, e, args): typeNew(keyword, e, args, expectedType);
		// 	case EField(eobj, dot, fieldName): typeField(eobj, dot, fieldName, expectedType);
		// 	case EBlock(b): mk(TEBlock(typeBlock(b)), TTVoid, TTVoid);
		// 	case EObjectDecl(openBrace, fields, closeBrace): typeObjectDecl(openBrace, fields, closeBrace, expectedType);
		// 	case EIf(keyword, openParen, econd, closeParen, ethen, eelse): typeIf(keyword, openParen, econd, closeParen, ethen, eelse, expectedType);
		// 	case ETernary(econd, question, ethen, colon, eelse): typeTernary(econd, question, ethen, colon, eelse, expectedType);
		// 	case EWhile(w): typeWhile(w, expectedType);
		// 	case EDoWhile(w): typeDoWhile(w, expectedType);
		// 	case EFor(f): typeFor(f, expectedType);
		// 	case EForIn(f): typeForIn(f, expectedType);
		// 	case EForEach(f): typeForEach(f, expectedType);
		// 	case EBinop(a, op, b): typeBinop(a, op, b, expectedType);
		// 	case EPreUnop(op, e): typePreUnop(op, e, expectedType);
		// 	case EPostUnop(e, op): typePostUnop(e, op, expectedType);
		// 	case EVars(kind, vars): typeVars(kind, vars, expectedType);
		// 	case EAs(e, keyword, t): typeAs(e, keyword, t, expectedType);
		// 	case EVector(v): typeVector(v, expectedType);
		// 	case ESwitch(keyword, openParen, subj, closeParen, openBrace, cases, closeBrace): typeSwitch(keyword, openParen, subj, closeParen, openBrace, cases, closeBrace, expectedType);
		// 	case ETry(keyword, block, catches, finally_): typeTry(keyword, block, catches, finally_, expectedType);
		// 	case EFunction(keyword, name, fun): typeLocalFunction(keyword, name, fun, expectedType);

		// 	case EXmlAttr(e, dot, at, attrName): typeXmlAttr(e, dot, at, attrName, expectedType);
		// 	case EXmlAttrExpr(e, dot, at, openBracket, eattr, closeBracket): typeXmlAttrExpr(e, dot, at, openBracket, eattr, closeBracket, expectedType);
		// 	case EXmlDescend(e, dotDot, childName): typeXmlDescend(e, dotDot, childName, expectedType);
		// 	case ECondCompValue(v): mk(TECondCompValue(typeCondCompVar(v)), TTAny, expectedType);
		// 	case ECondCompBlock(v, b): typeCondCompBlock(v, b, expectedType);
		// 	case EUseNamespace(ns): mk(TEUseNamespace(ns), TTVoid, expectedType);
		// }
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
			return {
				syntax: {name: f.name, colon: f.colon, comma: comma},
				name: f.name.text,
				expr: typeExpr(f.value, TTAny)
			};
		});
		return mk(TEObjectDecl({
			syntax: {openBrace: openBrace, closeBrace: closeBrace},
			fields: fields
		}), tUntypedObject, expectedType);
	}

	static function getConstructor(cls:TClassOrInterfaceDecl):Null<TFunction> {
		var extend;
		switch (cls.kind) {
			case TInterface(_): return null;
			case TClass(info): extend = info.extend;
		}

		for (m in cls.members) {
			switch m {
				case TMField({kind: TFFun(f)}) if (f.name == cls.name):
					return f.fun;
				case _:
			}
		}
		if (extend != null) {
			return getConstructor(extend.superClass);
		}
		return null;
	}

	function getConstructorType(cls:TClassOrInterfaceDecl):TType {
		var ctor = getConstructor(cls);
		return if (ctor != null) getFunctionTypeFromSignature(ctor.sig) else TTFun([], TTVoid, null);
	}

	function getFunctionTypeFromSignature(f:TFunctionSignature):TType {
		var args = [], rest:Null<TRestKind> = null;
		for (a in f.args) {
			switch a.kind {
				case TArgNormal(_): args.push(a.type);
				case TArgRest(_, kind): rest = kind;
			}
		}
		return TTFun(args, f.ret.type, rest);
	}

	function typeNew(keyword:Token, e:Expr, args:Null<CallArgs>, expectedType:TType):TExpr {
		var e = typeExpr(e, TTAny);

		var type, ctorType;
		switch (e.type) {
			case TTStatic(cls):
				ctorType = getConstructorType(cls);
				type = TTInst(cls);
			case _:
				ctorType = TTFunction;
				type = tUntypedObject; // TODO: is this correct?
		};

		var args = if (args != null) typeCallArgs(args, ctorType) else null;
		return mk(TENew(keyword, e, args), type, expectedType);
	}

	function typeCallArgs(args:CallArgs, callableType:TType):TCallArgs {
		var getExpectedType = switch (callableType) {
			case TTVoid | TTBoolean | TTNumber | TTInt | TTUint | TTString | TTArray(_) | TTObject(_) | TTXML | TTXMLList | TTRegExp | TTVector(_) | TTInst(_) | TTDictionary(_):
				throw "assert";
			case TTClass:
				throw "assert??";
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
		var type = resolveType(v.t.type);
		return mk(TEVector(v, type), TTFun([tUntypedObject], TTVector(type)), expectedType);
	}

	function typeBinop(a:Expr, op:Binop, b:Expr, expectedType:TType):TExpr {
		switch (op) {
			case OpAnd(_) | OpOr(_):
				var a = typeExpr(a, expectedType);
				var b = typeExpr(b, expectedType);
				var type = if (Type.enumEq(a.type, b.type)) a.type else TTAny;
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
				var b = typeExpr(b, a.type);
				return mk(TEBinop(a, op, b), a.type, expectedType);

			case OpShl(_) | OpShr(_) | OpUshr(_) | OpBitAnd(_) | OpBitOr(_) | OpBitXor(_):
				var a = typeExpr(a, TTInt);
				var b = typeExpr(b, TTInt);
				return mk(TEBinop(a, op, b), TTInt, expectedType);

			case OpAdd(_):
				var a = typeExpr(a, TTAny);
				var b = typeExpr(b, TTAny);

				var type =
					if (a.type == TTString || b.type == TTString) TTString // string concat
					else if (a.type == TTNumber || b.type == TTNumber) TTNumber // always number
					else a.type; // probably int/uint

				return mk(TEBinop(a, op, b), type, expectedType);

			case OpMul(_) | OpSub(_) | OpMod(_):
				var a = typeExpr(a, TTNumber);
				var b = typeExpr(b, TTNumber);

				var type =
					if (a.type == TTNumber || b.type == TTNumber) TTNumber // always number
					else a.type; // probably int/uint

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

		if (finally_ != null) throw "finally is unsupported";
		var body = typeExpr(EBlock(block), TTVoid);
		var tCatches = new Array<TCatch>();
		for (c in catches) {
			pushLocals();
			var v = addLocal(c.name.text, resolveType(c.type.type));
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
					if (def != null) throw "`case` after `default` in switch";
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
		var type = resolveType(t);
		return mk(TEAs(e, keyword, {syntax: t, type: type}), type, expectedType);
	}

	function typeForIn(f:ForIn, expectedType:TType):TExpr {
		if (expectedType != TTVoid) throw "assert";

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

	function typeIf(keyword:Token, openParen:Token, econd:Expr, closeParen:Token, ethen:Expr, eelse:Null<{keyword:Token, expr:Expr}>, expectedType:TType):TExpr {
		if (expectedType != TTVoid) throw "assert";

		var econd = typeExpr(econd, TTBoolean);
		var ethen = typeExpr(ethen, TTVoid);
		var eelse = if (eelse != null) {keyword: eelse.keyword, expr: typeExpr(eelse.expr, TTVoid)} else null;
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
		return mk(TETernary({
			syntax: {question: question, colon: colon},
			econd: econd,
			ethen: ethen,
			eelse: eelse
		}), ethen.type, expectedType);
	}

	function typeArrayAccess(e:Expr, openBracket:Token, eindex:Expr, closeBracket:Token, expectedType:TType):TExpr {
		var e = typeExpr(e, TTAny);
		var eindex = typeExpr(eindex, TTAny);
		var type = switch (e.type) {
			case TTVector(t):
				t;
			case TTArray(t):
				switch (eindex.type) {
					case TTNumber | TTInt | TTUint:
					case _:
						// err("Array access with non-numeric index", openBracket.pos);
				}
				t;
			case TTObject(t):
				t; // TODO: set expectedType for eindex to TTString?
			case TTDictionary(k, v):
				v; // TODO: set expectedType for eindex to k?
			case _:
				// err("Untyped array access", openBracket.pos);
				TTAny;
		};
		return mk(TEArrayAccess({
			syntax: {openBracket: openBracket, closeBracket: closeBracket},
			eobj: e,
			eindex: eindex
		}), type, expectedType);
	}

	function typeArrayDeclElements(d:ArrayDecl, elemExpectedType:TType) {
		var elems = if (d.elems == null) [] else separatedToArray(d.elems, (e, comma) -> {expr: typeExpr(e, elemExpectedType), comma: comma});
		return {
			syntax: {openBracket: d.openBracket, closeBracket: d.closeBracket},
			elements: elems
		};
	}

	function typeArrayDecl(d:ArrayDecl, expectedType:TType):TExpr {
		return mk(TEArrayDecl(typeArrayDeclElements(d, TTAny)), tUntypedArray, expectedType);
	}

	function typeVectorDecl(newKeyword:Token, t:TypeParam, d:ArrayDecl, expectedType:TType):TExpr {
		var type = resolveType(t.type);
		var elems = typeArrayDeclElements(d, type);
		return mk(TEVectorDecl({
			syntax: {newKeyword: newKeyword, typeParam: t},
			elements: elems,
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
		if (outType == TTNumber && e.type == TTInt || e.type == TTUint) {
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
