package ax3;

import ax3.ParseTree;
import ax3.Structure;

typedef TModule = {
	var pack:TPackageDecl;
	var name:String;
	var eof:Token;
}

typedef TPackageDecl = {
	var syntax:{
		var keyword:Token;
		var name:Null<DotPath>;
		var openBrace:Token;
		var closeBrace:Token;
	};
	var name:String;
	var decl:TDecl;
}

enum TDecl {
	TDClass(c:TClassDecl);
}

typedef TClassDecl = {
	var syntax:{
		var keyword:Token;
		var name:Token;
		var extend:Null<{keyword:Token, path:DotPath}>;
		var implement:Null<{keyword:Token, paths:Separated<DotPath>}>;
		var openBrace:Token;
		var closeBrace:Token;
	};
	var modifiers:Array<DeclModifier>;
	var name:String;
	var members:Array<TClassMember>;
}

enum TClassMember {
	TMField(f:TClassField);
}

typedef TClassField = {
	var kind:TClassFieldKind;
}

enum TClassFieldKind {
	TFVar;
	TFFun(f:TFunctionField);
	TFProp;
}

typedef TFunctionField = {
	var syntax:{
		var keyword:Token;
		var name:Token;
	};
	var name:String;
	var fun:TFunction;
}

typedef TExpr = {
	var kind:TExprKind;
	var type:TType;
}

enum TExprKind {
	TEFunction(f:TFunction);
	TELiteral(l:TLiteral);
	TELocal(syntax:Token, v:TVar);
	TEField(syntax:Expr, obj:TExpr, fieldName:String);
	TEThis(syntax:Null<Expr>);
	TEStaticThis;
	TESuper(syntax:Expr);
	TEBuiltin(syntax:Token, name:String);
	TEDeclRef(c:SDecl);
	TECall(syntax:{eobj:Expr, args:CallArgs}, eobj:TExpr, args:Array<TExpr>);
	TEArrayDecl(syntax:ArrayDecl, elems:Array<TExpr>);
	TEVectorDecl(type:TType, elems:Array<TExpr>);
	TEReturn(keyword:Token, e:Null<TExpr>);
	TEThrow(keyword:Token, e:TExpr);
	TEDelete(keyword:Token, e:TExpr);
	TEBreak(keyword:Token);
	TEContinue(keyword:Token);
	TEVars(v:Array<TVarDecl>);
	TEObjectDecl(syntax:Expr, fields:Array<TObjectField>);
	TEArrayAccess(eobj:TExpr, eindex:TExpr);
	TEBlock(block:TBlock);
	TETry(expr:TExpr, catches:Array<TCatch>);
	TEVector(type:TType);
	TETernary(econd:TExpr, ethen:TExpr, eelse:TExpr);
	TEIf(econd:TExpr, ethen:TExpr, eelse:Null<TExpr>);
	TEWhile(econd:TExpr, ebody:TExpr);
	TEDoWhile(ebody:TExpr, econd:TExpr);
	TEFor(einit:Null<TExpr>, econd:Null<TExpr>, eincr:Null<TExpr>, ebody:TExpr);
	TEForIn(eit:TExpr, eobj:TExpr, ebody:TExpr);
	TEBinop(a:TExpr, op:Binop, b:TExpr);
	TEComma(a:TExpr, b:TExpr);
	TEIs(e:TExpr, etype:TExpr);
	TEAs(e:TExpr, type:TType);
	TESwitch(esubj:TExpr, cases:Array<TSwitchCase>, def:Null<Array<TExpr>>);
	TENew(eclass:TExpr, args:Array<TExpr>);
	TECondCompBlock(ns:String, name:String, expr:TExpr);
	TEXmlAttr(e:TExpr, name:String);
	TEXmlAttrExpr(e:TExpr, eattr:TExpr);
	TEXmlDescend(e:TExpr, name:String);
	TENothing;
}

typedef TBlock = {
	var syntax:{openBrace:Token, closeBrace:Token};
	var exprs:Array<TBlockExpr>;
}

typedef TBlockExpr = {
	var expr:TExpr;
	var semicolon:Null<Token>;
}

typedef TFunction = {
	var sig:TFunctionSignature;
	var block:TBlock;
}

typedef TFunctionSignature = {
	var syntax:{
		var openParen:Token;
		var closeParen:Token;
	};
	var args:Array<TFunctionArg>;
	var ret:TTypeHint;
}

typedef TTypeHint = {
	var type:TType;
	var syntax:Null<TypeHint>;
}

typedef TFunctionArg = {
	var name:String;
	var type:TType;
	var kind:TFunctionArgKind;
}

enum TFunctionArgKind {
	TArgNormal;
	TArgRest;
}

typedef TSwitchCase = {
	var value:TExpr;
	var body:Array<TExpr>;
}

typedef TCatch = {
	var v:TVar;
	var expr:TExpr;
}

typedef TObjectField = {
	var syntax:ObjectField;
	var name:String;
	var expr:TExpr;
}

typedef TVarDecl = {
	var syntax:VarDecl;
	var v:TVar;
	var init:Null<TExpr>;
}

enum TLiteral {
	TLBool(syntax:Token);
	TLNull(syntax:Token);
	TLUndefined(syntax:Token);
	TLInt(syntax:Token);
	TLNumber(syntax:Token);
	TLString(syntax:Token);
	TLRegExp(syntax:Token);
}

typedef TVar = {
	var name:String;
	var type:TType;
}

enum TType {
	TTVoid;
	TTAny; // *
	TTBoolean;
	TTNumber;
	TTInt;
	TTUint;
	TTString;
	TTArray;
	TTFunction;
	TTClass;
	TTObject;
	TTXML;
	TTXMLList;
	TTRegExp;
	TTVector(t:TType);

	TTBuiltin; // TODO: temporary

	TTFun(args:Array<TType>, ret:TType); // method and local function refs
	TTInst(cls:SClassDecl); // class instance access (`obj` in `obj.some`)
	TTStatic(cls:SClassDecl); // class statics access (`Cls` in `Cls.some`)
}
