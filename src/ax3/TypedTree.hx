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
	var modifiers:Array<ClassFieldModifier>;
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
	TEParens(openParen:Token, e:TExpr, closeParen:Token);
	TEFunction(f:TFunction);
	TELiteral(l:TLiteral);
	TELocal(syntax:Token, v:TVar);
	TEField(obj:TFieldObject, fieldName:String, fieldToken:Token);
	TEBuiltin(syntax:Token, name:String);
	TEDeclRef(path:DotPath, c:SDecl);
	TECall(eobj:TExpr, args:TCallArgs);
	TEArrayDecl(syntax:ArrayDecl, elems:Array<TExpr>);
	TEVectorDecl(type:TType, elems:Array<TExpr>);
	TEReturn(keyword:Token, e:Null<TExpr>);
	TEThrow(keyword:Token, e:TExpr);
	TEDelete(keyword:Token, e:TExpr);
	TEBreak(keyword:Token);
	TEContinue(keyword:Token);
	TEVars(kind:VarDeclKind, v:Array<TVarDecl>);
	TEObjectDecl(o:TObjectDecl);
	TEArrayAccess(a:TArrayAccess);
	TEBlock(block:TBlock);
	TETry(expr:TExpr, catches:Array<TCatch>);
	TEVector(type:TType);
	TETernary(e:TTernary);
	TEIf(e:TIf);
	TEWhile(econd:TExpr, ebody:TExpr);
	TEDoWhile(ebody:TExpr, econd:TExpr);
	TEFor(einit:Null<TExpr>, econd:Null<TExpr>, eincr:Null<TExpr>, ebody:TExpr);
	TEForIn(eit:TExpr, eobj:TExpr, ebody:TExpr);
	TEBinop(a:TExpr, op:Binop, b:TExpr);
	TEComma(a:TExpr, comma:Token, b:TExpr);
	TEIs(e:TExpr, etype:TExpr);
	TEAs(e:TExpr, type:TType);
	TESwitch(esubj:TExpr, cases:Array<TSwitchCase>, def:Null<Array<TExpr>>);
	TENew(keyword:Token, eclass:TExpr, args:Null<TCallArgs>);
	TECondCompBlock(ns:String, name:String, expr:TExpr);
	TEXmlAttr(e:TExpr, name:String);
	TEXmlAttrExpr(e:TExpr, eattr:TExpr);
	TEXmlDescend(e:TExpr, name:String);
	TENothing;
}

typedef TTernary = {
	var syntax:{
		question:Token,
		colon:Token,
	};
	var econd:TExpr;
	var ethen:TExpr;
	var eelse:TExpr;
}


typedef TIf = {
	var syntax:{
		keyword:Token,
		openParen:Token,
		closeParen:Token,
	};
	var econd:TExpr;
	var ethen:TExpr;
	var eelse:Null<{keyword:Token, expr:TExpr}>;
}

typedef TCallArgs = {
	var openParen:Token;
	var args:Array<{expr:TExpr, comma:Null<Token>}>;
	var closeParen:Token;
}

typedef TArrayAccess = {
	var syntax:{openBracket:Token, closeBracket:Token};
	var eobj:TExpr;
	var eindex:TExpr;
}

typedef TObjectDecl = {
	var syntax:{openBrace:Token, closeBrace:Token};
	var fields:Array<TObjectField>;
}

typedef TFieldObject = {
	var type:TType;
	var kind:TFieldObjectKind;
}

enum TFieldObjectKind {
	TOImplicitThis(c:SClassDecl);
	TOImplicitClass(c:SClassDecl);
	TOExplicit(dot:Token, e:TExpr);
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
	var syntax:{name:Token, colon:Token, comma:Null<Token>};
	var name:String;
	var expr:TExpr;
}

typedef TVarDecl = {
	var syntax:{
		var name:Token;
		var type:Null<TypeHint>;
	}
	var v:TVar;
	var init:Null<TVarInit>;
	var comma:Null<Token>;
}

typedef TVarInit = {
	var equals:Token;
	var expr:TExpr;
}

enum TLiteral {
	TLThis(syntax:Token);
	TLSuper(syntax:Token);
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
