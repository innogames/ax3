package ax3;

import ax3.ParseTree;
import ax3.Structure;

typedef TModule = {
	var path:String;
	var pack:TPackageDecl;
	var name:String;
	var privateDecls:Array<TDecl>;
	var eof:Token;
}

typedef TPackageDecl = {
	var syntax:{
		var keyword:Token;
		var name:Null<DotPath>;
		var openBrace:Token;
		var closeBrace:Token;
	};
	var imports:Array<TImport>;
	var namespaceUses:Array<{n:UseNamespace, semicolon:Token}>;
	var name:String;
	var decl:TDecl;
}

typedef TImport = {
	var syntax:{
		var condCompBegin:Null<TCondCompBegin>;
		var keyword:Token;
		var path:DotPath;
		var semicolon:Token;
		var condCompEnd:Null<TCondCompEnd>;
	}
	var kind:TImportKind;
}

enum TImportKind {
	TIDecl(d:SDecl);
	TIPack(p:SPackage, dot:Token, asterisk:Token);
}

typedef TCondCompBegin = {
	var v:TCondCompVar;
	var openBrace:Token;
}

typedef TCondCompEnd = {closeBrace:Token}

enum TDecl {
	TDClass(c:TClassDecl);
	TDInterface(c:TInterfaceDecl);
	TDVar(v:TModuleVarDecl);
	TDFunction(v:TFunctionDecl);
	TDNamespace(n:NamespaceDecl);
}

typedef TFunctionDecl = {
	var metadata:Array<Metadata>;
	var modifiers:Array<DeclModifier>;
	var syntax:{keyword:Token, name:Token};
	var name:String;
	var fun:TFunction;
}

typedef TModuleVarDecl = TVarField & {
	var metadata:Array<Metadata>;
	var modifiers:Array<DeclModifier>;
}

typedef TInterfaceDecl = {
	var syntax:{
		var keyword:Token;
		var name:Token;
		var openBrace:Token;
		var closeBrace:Token;
	};
	var metadata:Array<Metadata>;
	var modifiers:Array<DeclModifier>;
	var name:String;
	var extend:Null<TClassImplement>;
	var members:Array<TInterfaceMember>;
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
	var metadata:Array<Metadata>;
	var modifiers:Array<DeclModifier>;
	var name:String;
	var extend:Null<TClassExtend>;
	var implement:Null<TClassImplement>;
	var members:Array<TClassMember>;
}

enum TInterfaceMember {
	TIMField(f:TInterfaceField);
	TIMCondCompBegin(b:TCondCompBegin);
	TIMCondCompEnd(b:TCondCompEnd);
}

typedef TInterfaceField = {
	var metadata:Array<Metadata>;
	var kind:TInterfaceFieldKind;
	var semicolon:Token;
}

enum TInterfaceFieldKind {
	TIFFun(f:TIFunctionField);
	TIFGetter(f:TIAccessorField);
	TIFSetter(f:TIAccessorField);
}

typedef TIFunctionField = {
	var syntax:{
		var keyword:Token;
		var name:Token;
	};
	var name:String;
	var sig:TFunctionSignature;
}

typedef TIAccessorField = {
	var syntax:{
		var functionKeyword:Token;
		var accessorKeyword:Token;
		var name:Token;
	}
	var name:String;
	var sig:TFunctionSignature;
}

typedef TClassExtend = {
	var syntax:{
		var keyword:Token;
		var path:DotPath;
	};
}

typedef TClassImplement = {
	var syntax:{keyword:Token};
	var interfaces:Array<{syntax: DotPath, comma:Null<Token>}>;
}

enum TClassMember {
	TMUseNamespace(n:UseNamespace, semicolon:Token);
	TMCondCompBegin(b:TCondCompBegin);
	TMCondCompEnd(b:TCondCompEnd);
	TMField(f:TClassField);
	TMStaticInit(i:{expr:TExpr});
}

typedef TClassField = {
	var metadata:Array<Metadata>;
	var namespace:Null<Token>;
	var modifiers:Array<ClassFieldModifier>;
	var kind:TClassFieldKind;
}

enum TClassFieldKind {
	TFVar(f:TVarField);
	TFFun(f:TFunctionField);
	TFGetter(f:TAccessorField);
	TFSetter(f:TAccessorField);
}

typedef TFunctionField = {
	var syntax:{
		var keyword:Token;
		var name:Token;
	};
	var name:String;
	var fun:TFunction;
}

typedef TAccessorField = {
	var syntax:{
		var functionKeyword:Token;
		var accessorKeyword:Token;
		var name:Token;
	}
	var name:String;
	var fun:TFunction;
}

typedef TVarField = {
	var kind:VarDeclKind;
	var vars:Array<TVarFieldDecl>;
	var semicolon:Token;
}

typedef TVarFieldDecl = {
	var syntax:{
		var name:Token;
		var type:Null<TypeHint>;
	}
	var name:String;
	var type:TType;
	var init:Null<TVarInit>;
	var comma:Null<Token>;
}

typedef TExpr = {
	var kind:TExprKind;
	var type:TType;
	var expectedType:TType;
}

enum TExprKind {
	TEParens(openParen:Token, e:TExpr, closeParen:Token);
	TELocalFunction(f:TLocalFunction);
	TELiteral(l:TLiteral);
	TELocal(syntax:Token, v:TVar);
	TEField(obj:TFieldObject, fieldName:String, fieldToken:Token);
	TEBuiltin(syntax:Token, name:String);
	TEDeclRef(path:DotPath, c:SDecl);
	TECall(eobj:TExpr, args:TCallArgs);
	TECast(c:TCast);
	TEArrayDecl(a:TArrayDecl);
	TEVectorDecl(v:TVectorDecl);
	TEReturn(keyword:Token, e:Null<TExpr>);
	TEThrow(keyword:Token, e:TExpr);
	TEDelete(keyword:Token, e:TExpr);
	TEBreak(keyword:Token);
	TEContinue(keyword:Token);
	TEVars(kind:VarDeclKind, vars:Array<TVarDecl>);
	TEObjectDecl(o:TObjectDecl);
	TEArrayAccess(a:TArrayAccess);
	TEBlock(block:TBlock);
	TETry(t:TTry);
	TEVector(syntax:VectorSyntax, type:TType);
	TETernary(t:TTernary);
	TEIf(i:TIf);
	TEWhile(w:TWhile);
	TEDoWhile(w:TDoWhile);
	TEFor(f:TFor);
	TEForIn(f:TForIn);
	TEForEach(f:TForEach);
	TEBinop(a:TExpr, op:Binop, b:TExpr);
	TEPreUnop(op:PreUnop, e:TExpr);
	TEPostUnop(e:TExpr, op:PostUnop);
	TEAs(e:TExpr, keyword:Token, type:TTypeRef);
	TESwitch(s:TSwitch);
	TENew(keyword:Token, eclass:TExpr, args:Null<TCallArgs>);
	TECondCompValue(v:TCondCompVar);
	TECondCompBlock(v:TCondCompVar, expr:TExpr);
	TEXmlChild(x:TXmlChild);
	TEXmlAttr(x:TXmlAttr);
	TEXmlAttrExpr(x:TXmlAttrExpr);
	TEXmlDescend(x:TXmlDescend);
	TEUseNamespace(ns:UseNamespace);
}

typedef TCast = {
	var syntax:{
		var openParen:Token;
		var closeParen:Token;
		var path:DotPath;
	};
	var expr:TExpr;
	var type:TType;
}

typedef TLocalFunction = {
	var syntax:{keyword:Token};
	var name:Null<{syntax:Token, name:String}>;
	var fun:TFunction;
}

typedef TXmlDescend = {
	var syntax:{
		var dotDot:Token;
		var name:Token;
	};
	var eobj:TExpr;
	var name:String;
}

typedef TXmlChild = {
	var syntax:{
		var dot:Token;
		var name:Token;
	};
	var eobj:TExpr;
	var name:String;
}
typedef TXmlAttr = {
	var syntax:{
		var dot:Token;
		var at:Token;
		var name:Token;
	};
	var eobj:TExpr;
	var name:String;
}

typedef TXmlAttrExpr = {
	var syntax:{
		var dot:Token;
		var at:Token;
		var openBracket:Token;
		var closeBracket:Token;
	};
	var eobj:TExpr;
	var eattr:TExpr;
}
typedef TVectorDecl = {
	var syntax:{
		var newKeyword:Token;
		var typeParam:TypeParam;
	}
	var elements:TArrayDecl;
	var type:TType;
}

typedef TCondCompVar = {
	var syntax:CondCompVar;
	var ns:String;
	var name:String;
}

typedef TArrayDecl = {
	var syntax:{
		var openBracket:Token;
		var closeBracket:Token;
	};
	var elements:Array<{expr:TExpr, comma:Null<Token>}>;
}

typedef TWhile = {
	var syntax:{
		var keyword:Token;
		var openParen:Token;
		var closeParen:Token;
	};
	var cond:TExpr;
	var body:TExpr;
}

typedef TDoWhile = {
	var syntax:{
		var doKeyword:Token;
		var whileKeyword:Token;
		var openParen:Token;
		var closeParen:Token;
	};
	var body:TExpr;
	var cond:TExpr;
}

typedef TFor = {
	var syntax:{
		var keyword:Token;
		var openParen:Token;
		var initSep:Token;
		var condSep:Token;
		var closeParen:Token;
	}
	var einit:Null<TExpr>;
	var econd:Null<TExpr>;
	var eincr:Null<TExpr>;
	var body:TExpr;
}

typedef TForIn = {
	var syntax:{
		var forKeyword:Token;
		var openParen:Token;
		var closeParen:Token;
	}
	var iter:TForInIter;
	var body:TExpr;
}

typedef TForEach = {
	var syntax:{
		var forKeyword:Token;
		var eachKeyword:Token;
		var openParen:Token;
		var closeParen:Token;
	}
	var iter:TForInIter;
	var body:TExpr;
}

typedef TForInIter = {
	var eit:TExpr;
	var inKeyword:Token;
	var eobj:TExpr;
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
	var expr:TExpr;
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

typedef TTypeRef = {
	var type:TType;
	var syntax:SyntaxType;
}

typedef TFunctionArg = {
	var syntax:{
		var name:Token;
	}
	var name:String;
	var type:TType;
	var kind:TFunctionArgKind;
	var comma:Null<Token>;
}

enum TFunctionArgKind {
	TArgNormal(typeHint:Null<TypeHint>, init:Null<TVarInit>);
	TArgRest(dots:Token);
}

typedef TSwitch = {
	var syntax:{
		var keyword:Token;
		var openParen:Token;
		var closeParen:Token;
		var openBrace:Token;
		var closeBrace:Token;
	}
	var subj:TExpr;
	var cases:Array<TSwitchCase>;
	var def:Null<TSwitchDefault>;
}

typedef TSwitchCase = {
	var syntax:{
		var keyword:Token;
		var colon:Token;
	}
	var value:TExpr;
	var body:Array<TBlockExpr>;
}

typedef TSwitchDefault = {
	var syntax:{
		var keyword:Token;
		var colon:Token;
	}
	var body:Array<TBlockExpr>;
}

typedef TTry = {
	var keyword:Token;
	var expr:TExpr;
	var catches:Array<TCatch>;
}

typedef TCatch = {
	var syntax:{
		var keyword:Token;
		var openParen:Token;
		var name:Token;
		var type:TypeHint;
		var closeParen:Token;
	};
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

	TTFun(args:Array<TType>, ret:TType, ?rest:Null<TRestKind>); // method and local function refs
	TTInst(cls:SClassDecl); // class instance access (`obj` in `obj.some`)
	TTStatic(cls:SClassDecl); // class statics access (`Cls` in `Cls.some`)
}

enum TRestKind {
	TRestSwc;
	TRestAs3;
}
