package ax3.filters;

import ax3.ParseTree.VarDeclKind;

class RewriteForIn extends AbstractFilter {
	static final tIteratorMethod = TTFun([], TTBuiltin);
	static inline final tempLoopVarName = "_tmp_";
	static inline final tempIterateeVarName = "_iter_";
	public static inline final checkNullIterateeBuiltin = "checkNullIteratee";

	final generateCheckNullIteratee:Bool;

	public function new(context:Context) {
		super(context);
		generateCheckNullIteratee = if (context.config.settings == null) false else context.config.settings.checkNullIteratee;
	}

	override function processExpr(e:TExpr):TExpr {
		return switch e.kind {
			case TEForIn(f):
				makeHaxeFor(getLoopVar(f.iter.eit), getForInData(f), processExpr(f.body));
			case TEForEach(f):
				makeHaxeFor(getLoopVar(f.iter.eit), getForEachData(f), processExpr(f.body));
			case _:
				mapExpr(processExpr, e);
		}
	}

	function makeHaxeFor(loopVar:LoopVarData, data:LoopData, body:TExpr):TExpr {
		var loopVarVar, loopVarToken;

		switch loopVar.kind {
			case LOwn(kind, decl):
				if (typeEq(loopVar.v.type, data.loopVarType)) {
					// types are exactly the same, we can use the haxe loop var directly
					loopVarVar = loopVar.v;
					loopVarToken = mkIdent(loopVar.v.name, [], [whitespace]);
				} else {
					// types differ, use temp loop var and introduce
					// a local var inside the loop body
					loopVarToken = mkIdent(tempLoopVarName, [], [whitespace]);
					loopVarVar = {name: tempLoopVarName, type: data.loopVarType};

					var eVarInit = mk(TEVars(kind, [
						decl.with(init = {
							equalsToken: mkTokenWithSpaces(TkEquals, "="),
							expr: mk(TELocal(mkIdent(tempLoopVarName), loopVarVar), data.loopVarType, loopVar.v.type)
						})
					]), TTVoid, TTVoid);

					body = concatExprs(eVarInit, body);
				}

			case LShared(eLocal):
				// always use temp loop var and assign it to the shared var
				loopVarToken = mkIdent(tempLoopVarName, [], [whitespace]);
				loopVarVar = {name: tempLoopVarName, type: data.loopVarType};

				var eAssign = mk(TEBinop(
					eLocal,
					OpAssign(mkTokenWithSpaces(TkEquals, "=")),
					mk(TELocal(mkIdent(tempLoopVarName), loopVarVar), data.loopVarType, loopVar.v.type)
				), TTVoid, TTVoid);

				body = concatExprs(eAssign, body);
		}

		var eFor = mk(TEHaxeFor({
			syntax: {
				forKeyword: data.syntax.forKeyword,
				openParen: data.syntax.openParen,
				itName: loopVarToken,
				inKeyword: data.syntax.inKeyword,
				closeParen: data.syntax.closeParen
			},
			vit: loopVarVar,
			iter: data.iterateeExpr,
			body: body
		}), TTVoid, TTVoid);


		var loopExpr;
		if (generateCheckNullIteratee) {
			var checkedExpr;
			if (data.iterateeTempVar == null) {
				checkedExpr = data.originalExpr;
			} else {
				checkedExpr = mk(TELocal(mkIdent(data.iterateeTempVar.name), data.iterateeTempVar), data.iterateeTempVar.type, data.iterateeTempVar.type);
			}

			loopExpr = mk(TEIf({
				syntax: {
					keyword: mkIdent("if", removeLeadingTrivia(eFor), [whitespace]),
					openParen: mkOpenParen(),
					closeParen: addTrailingWhitespace(mkCloseParen()),
				},
				econd: mkCheckNullIterateeExpr(checkedExpr),
				ethen: eFor,
				eelse: null
			}), TTVoid, TTVoid);
		} else {
			loopExpr = eFor;
		}

		if (data.iterateeTempVar == null) {
			return loopExpr;
		} else {
			var tempVarDecl = mk(TEVars(VConst(mkIdent("final", removeLeadingTrivia(loopExpr), [whitespace])), [{
				syntax: {
					name: mkIdent(data.iterateeTempVar.name),
					type: null
				},
				v: data.iterateeTempVar,
				init: {
					equalsToken: mkTokenWithSpaces(TkEquals, "="),
					expr: data.originalExpr,
				},
				comma: null
			}]), TTVoid, TTVoid);
			return mkMergedBlock([
				{expr: tempVarDecl, semicolon: semicolonWithSpace},
				{expr: loopExpr, semicolon: null},
			]);
		}
	}

	function getLoopVar(e:TExpr):LoopVarData {
		return switch e.kind {
			// for (var x in obj)
			case TEVars(kind, [varDecl]):
				{
					kind: LOwn(kind, varDecl),
					v: varDecl.v
				};

			// for (x in obj)
			case TELocal(_, v):
				{
					kind: LShared(e),
					v: v
				};

			case _:
				throwError(exprPos(e), "Unsupported `for...in` loop variable declaration");
		}
	}

	inline function maybeTempVarIteratee(e:TExpr):{expr:TExpr, tempVar:Null<TVar>} {
		return if (!generateCheckNullIteratee || skipParens(e).kind.match(TELocal(_)))
			{
				expr: e,
				tempVar: null,
			};
		else {
			var tempVar = {name: tempIterateeVarName, type: e.type};
			{
				tempVar: tempVar,
				expr: mk(TELocal(mkIdent(tempIterateeVarName), tempVar), e.type, e.type),
			};
		};
	}

	function getForInData(f:TForIn):LoopData {
		var eobj, iterTempVar;
		{
			var d = maybeTempVarIteratee(f.iter.eobj);
			eobj = d.expr;
			iterTempVar = d.tempVar;
		}

		var loopVarType;
		switch eobj.type {
			case TTDictionary(keyType, _):
				eobj = mkIteratorMethodCallExpr(eobj, "keys");
				loopVarType = keyType;

			case TTObject(valueType):
				// TTAny most probably means it's coming from an AS3 Object,
				// while any other type is surely coming from haxe.DynamicAccess
				var keysMethod = if (valueType == TTAny) "___keys" else "keys";
				eobj = mkIteratorMethodCallExpr(eobj, keysMethod);
				loopVarType = TTString;

			case TTAny:
				eobj = mkIteratorMethodCallExpr(eobj, "___keys");
				loopVarType = TTAny;

			case TTXMLList:
				eobj = mkIteratorMethodCallExpr(eobj, "keys");
				loopVarType = TTString;

			case TTArray(_) | TTVector(_):
				var pos = exprPos(eobj);
				var eZero = mk(TELiteral(TLInt(new Token(pos, TkDecimalInteger, "0", [], []))), TTInt, TTInt);
				var eLength = mk(TEField({kind: TOExplicit(mkDot(), eobj), type: eobj.type}, "length", mkIdent("length")), TTInt, TTInt);
				eobj = mk(TEHaxeIntIter(eZero, eLength), TTBuiltin, TTBuiltin);
				loopVarType = TTInt;

			case other:
				throwError(exprPos(f.iter.eobj), "Unsupported iteratee type: " + other);
		}
		return {
			originalExpr: f.iter.eobj,
			iterateeExpr: eobj,
			iterateeTempVar: iterTempVar,
			loopVarType: loopVarType,
			syntax: {
				forKeyword: f.syntax.forKeyword,
				openParen: f.syntax.openParen,
				inKeyword: f.iter.inKeyword,
				closeParen: f.syntax.closeParen
			}
		};
	}

	function getForEachData(f:TForEach):LoopData {
		var eobj, iterTempVar;
		{
			var d = maybeTempVarIteratee(f.iter.eobj);
			eobj = d.expr;
			iterTempVar = d.tempVar;
		}

		var loopVarType;
		switch eobj.type {
			case TTAny:
				loopVarType = TTAny;
			case TTArray(t) | TTVector(t) | TTDictionary(_, t) | TTObject(t):
				loopVarType = t;
			case TTXMLList:
				loopVarType = TTXML;
			case other:
				throwError(exprPos(f.iter.eobj), "Unsupported iteratee type: " + other);
		}
		return {
			originalExpr: f.iter.eobj,
			iterateeExpr: eobj,
			iterateeTempVar: iterTempVar,
			loopVarType: loopVarType,
			syntax: {
				forKeyword: f.syntax.forKeyword,
				openParen: f.syntax.openParen,
				inKeyword: f.iter.inKeyword,
				closeParen: f.syntax.closeParen
			}
		};
	}

	static inline function mkIteratorMethodCallExpr(eobj:TExpr, methodName:String):TExpr {
		var eMethod = mk(TEField({kind: TOExplicit(mkDot(), eobj), type: eobj.type}, methodName, mkIdent(methodName)), tIteratorMethod, tIteratorMethod);
		return mkCall(eMethod, []);
	}

	inline function mkCheckNullIterateeExpr(eobj:TExpr):TExpr {
		var eCheckBuiltin = mkBuiltin(checkNullIterateeBuiltin, TTBuiltin);
		context.addToplevelImport("ASCompat.checkNullIteratee", Import);
		return mkCall(eCheckBuiltin, [eobj], TTBoolean);
	}
}

typedef LoopData = {
	var syntax:ForSyntax;
	var originalExpr:TExpr;
	var iterateeTempVar:Null<TVar>;
	var iterateeExpr:TExpr;
	var loopVarType:TType;
}

private typedef LoopVarData = {
	var kind:LoopVarKind;
	var v:TVar;
}

private typedef ForSyntax = {
	var forKeyword:Token;
	var openParen:Token;
	var inKeyword:Token;
	var closeParen:Token;
}

private enum LoopVarKind {
	LOwn(kind:VarDeclKind, decl:TVarDecl);
	LShared(eLocal:TExpr);
}
