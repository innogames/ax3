package ax3;

import ax3.ParseTree;
import ax3.TypedTree;
import ax3.TypedTreeTools.mk;

typedef Locals = Map<String, TVar>;

class ExprTyper {
	final context:Context;
	final localsStack:Array<Locals>;
	var locals:Locals;
	var currentReturnType:TType;

	public function new(context) {
		this.context = context;
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
		return mk(TEBreak(TokenTools.mkIdent("lel")), expectedType, expectedType);
	// 	return switch (e) {
	// 		case EIdent(i):
	// 			typeIdent(i, e, expectedType);

	// 		case ELiteral(l):
	// 			typeLiteral(l, expectedType);

	// 		case ECall(e, args):
	// 			typeCall(e, args, expectedType);

	// 		case EParens(openParen, e, closeParen):
	// 			var e = typeExpr(e, expectedType);
	// 			mk(TEParens(openParen, e, closeParen), e.type, expectedType);

	// 		case EArrayAccess(e, openBracket, eindex, closeBracket):
	// 			typeArrayAccess(e, openBracket, eindex, closeBracket, expectedType);

	// 		case EArrayDecl(d):
	// 			typeArrayDecl(d, expectedType);

	// 		case EVectorDecl(newKeyword, t, d):
	// 			typeVectorDecl(newKeyword, t, d, expectedType);

	// 		case EReturn(keyword, eReturned):
	// 			if (expectedType != TTVoid) throw "assert";
	// 			mk(TEReturn(keyword, if (eReturned != null) typeExpr(eReturned, currentReturnType) else null), TTVoid, TTVoid);

	// 		case EThrow(keyword, e):
	// 			if (expectedType != TTVoid) throw "assert";
	// 			mk(TEThrow(keyword, typeExpr(e, TTAny)), TTVoid, TTVoid);

	// 		case EBreak(keyword):
	// 			if (expectedType != TTVoid) throw "assert";
	// 			mk(TEBreak(keyword), TTVoid, TTVoid);

	// 		case EContinue(keyword):
	// 			if (expectedType != TTVoid) throw "assert";
	// 			mk(TEContinue(keyword), TTVoid, TTVoid);

	// 		case EDelete(keyword, e):
	// 			mk(TEDelete(keyword, typeExpr(e, TTAny)), TTBoolean, expectedType);

	// 		case ENew(keyword, e, args): typeNew(keyword, e, args, expectedType);
	// 		case EField(eobj, dot, fieldName): typeField(eobj, dot, fieldName, expectedType);
	// 		case EBlock(b): mk(TEBlock(typeBlock(b)), TTVoid, TTVoid);
	// 		case EObjectDecl(openBrace, fields, closeBrace): typeObjectDecl(openBrace, fields, closeBrace, expectedType);
	// 		case EIf(keyword, openParen, econd, closeParen, ethen, eelse): typeIf(keyword, openParen, econd, closeParen, ethen, eelse, expectedType);
	// 		case ETernary(econd, question, ethen, colon, eelse): typeTernary(econd, question, ethen, colon, eelse, expectedType);
	// 		case EWhile(w): typeWhile(w, expectedType);
	// 		case EDoWhile(w): typeDoWhile(w, expectedType);
	// 		case EFor(f): typeFor(f, expectedType);
	// 		case EForIn(f): typeForIn(f, expectedType);
	// 		case EForEach(f): typeForEach(f, expectedType);
	// 		case EBinop(a, op, b): typeBinop(a, op, b, expectedType);
	// 		case EPreUnop(op, e): typePreUnop(op, e, expectedType);
	// 		case EPostUnop(e, op): typePostUnop(e, op, expectedType);
	// 		case EVars(kind, vars): typeVars(kind, vars, expectedType);
	// 		case EAs(e, keyword, t): typeAs(e, keyword, t, expectedType);
	// 		case EVector(v): typeVector(v, expectedType);
	// 		case ESwitch(keyword, openParen, subj, closeParen, openBrace, cases, closeBrace): typeSwitch(keyword, openParen, subj, closeParen, openBrace, cases, closeBrace, expectedType);
	// 		case ETry(keyword, block, catches, finally_): typeTry(keyword, block, catches, finally_, expectedType);
	// 		case EFunction(keyword, name, fun): typeLocalFunction(keyword, name, fun, expectedType);

	// 		case EXmlAttr(e, dot, at, attrName): typeXmlAttr(e, dot, at, attrName, expectedType);
	// 		case EXmlAttrExpr(e, dot, at, openBracket, eattr, closeBracket): typeXmlAttrExpr(e, dot, at, openBracket, eattr, closeBracket, expectedType);
	// 		case EXmlDescend(e, dotDot, childName): typeXmlDescend(e, dotDot, childName, expectedType);
	// 		case ECondCompValue(v): mk(TECondCompValue(typeCondCompVar(v)), TTAny, expectedType);
	// 		case ECondCompBlock(v, b): typeCondCompBlock(v, b, expectedType);
	// 		case EUseNamespace(ns): mk(TEUseNamespace(ns), TTVoid, expectedType);
	// 	}
	// }

	// function typeLiteral(l:Literal, expectedType:TType):TExpr {
	// 	return switch (l) {
	// 		case LString(t): mk(TELiteral(TLString(t)), TTString, expectedType);
	// 		case LDecInt(t) | LHexInt(t): mk(TELiteral(TLInt(t)), TTInt, expectedType);
	// 		case LFloat(t): mk(TELiteral(TLNumber(t)), TTNumber, expectedType);
	// 		case LRegExp(t): mk(TELiteral(TLRegExp(t)), TTRegExp, expectedType);
	// 	}
	// }

	// function typeArrayDeclElements(d:ArrayDecl, elemExpectedType:TType) {
	// 	var elems = if (d.elems == null) [] else separatedToArray(d.elems, (e, comma) -> {expr: typeExpr(e, elemExpectedType), comma: comma});
	// 	return {
	// 		syntax: {openBracket: d.openBracket, closeBracket: d.closeBracket},
	// 		elements: elems
	// 	};
	// }

	// function typeArrayDecl(d:ArrayDecl, expectedType:TType):TExpr {
	// 	return mk(TEArrayDecl(typeArrayDeclElements(d, TTAny)), tUntypedArray, expectedType);
	// }

	// function typeVectorDecl(newKeyword:Token, t:TypeParam, d:ArrayDecl, expectedType:TType):TExpr {
	// 	var type = resolveType(t.type);
	// 	var elems = typeArrayDeclElements(d, type);
	// 	return mk(TEVectorDecl({
	// 		syntax: {newKeyword: newKeyword, typeParam: t},
	// 		elements: elems,
	// 		type: type
	// 	}), TTVector(type), expectedType);
	}
}
