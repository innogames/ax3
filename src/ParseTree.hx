typedef File = {
	var pack:Package;
	var declarations:Array<Declaration>;
}

typedef Package = {
	var keyword:TokenInfo;
	var name:Null<DotPath>;
	var openBrace:TokenInfo;
	var closeBrace:TokenInfo;
	var declarations:Array<Declaration>;
}

typedef Separated<T> = {
	var first:T;
	var rest:Array<{sep:TokenInfo, element:T}>;
}

typedef DotPath = Separated<TokenInfo>;

enum Declaration {
	DImport(d:ImportDecl);
	DClass(c:ClassDecl);
	DInterface(i:InterfaceDecl);
}

typedef ImportDecl = {
	var keyword:TokenInfo;
	var path:DotPath;
	var wildcard:Null<TokenInfo>;
	var semicolon:TokenInfo;
}

typedef ClassDecl = {
	var modifiers:Array<TokenInfo>;
	var keyword:TokenInfo;
	var name:TokenInfo;
	var extend:Null<{keyword:TokenInfo, path:DotPath}>;
	var implement:Null<{keyword:TokenInfo, paths:Separated<DotPath>}>;
	var openBrace:TokenInfo;
	var fields:Array<ClassField>;
	var closeBrace:TokenInfo;
}

typedef InterfaceDecl = {
	var modifiers:Array<TokenInfo>;
	var keyword:TokenInfo;
	var name:TokenInfo;
	var extend:Null<{keyword:TokenInfo, paths:Separated<DotPath>}>;
	var openBrace:TokenInfo;
	var closeBrace:TokenInfo;
}

typedef ClassField = {
	var modifiers:Array<TokenInfo>;
	var name:TokenInfo;
	var kind:ClassFieldKind;
}

enum ClassFieldKind {
	FVar(v:ClassVar);
	FFun(f:ClassFun);
	FProp(kind:PropKind, f:ClassFun);
}

enum PropKind {
	PGet(keyword:TokenInfo);
	PSet(keyword:TokenInfo);
}

typedef ClassVar = {
	var keyword:TokenInfo;
	var hint:Null<TypeHint>;
	var init:Null<VarInit>;
	var semicolon:TokenInfo;
}

typedef ClassFun = {
	var keyword:TokenInfo;
	var openParen:TokenInfo;
	var args:Separated<FunctionArg>;
	var closeParen:TokenInfo;
	var ret:Null<TypeHint>;
	var openBrace:TokenInfo;
	var exprs:Array<Expr>;
	var closeBrace:TokenInfo;
}

typedef FunctionArg = {
	var name:TokenInfo;
	var hint:Null<TypeHint>;
	var init:Null<VarInit>;
}

typedef TypeHint = {
	var colon:TokenInfo;
	var type:SyntaxType;
}

typedef VarInit = {
	var equals:TokenInfo;
	var expr:Expr;
}

enum SyntaxType {
	TAny(star:TokenInfo);
	TPath(path:DotPath);
}

enum Expr {
	EIdent(i:TokenInfo);
	ELiteral(l:Literal);
	ECall(e:Expr, openParen:TokenInfo, args:Null<Separated<Expr>>, closeParen:TokenInfo);
	EReturn(keyword:TokenInfo, e:Null<Expr>);
}

enum Literal {
	LString(t:TokenInfo);
}
