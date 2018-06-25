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
	var metadata:Array<Metadata>;
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
	var metadata:Array<Metadata>;
	var modifiers:Array<TokenInfo>;
	var keyword:TokenInfo;
	var name:TokenInfo;
	var extend:Null<{keyword:TokenInfo, paths:Separated<DotPath>}>;
	var openBrace:TokenInfo;
	var closeBrace:TokenInfo;
}

typedef ClassField = {
	var metadata:Array<Metadata>;
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
	var exprs:Array<BlockElement>;
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
	TVector(v:VectorSyntax);
}

enum Expr {
	EIdent(i:TokenInfo);
	ELiteral(l:Literal);
	ECall(e:Expr, args:CallArgs);
	EParens(openParen:TokenInfo, e:Expr, closeParen:TokenInfo);
	EArrayAccess(e:Expr, openBracket:TokenInfo, eindex:Expr, closeBracket:TokenInfo);
	EArrayDecl(d:ArrayDecl);
	EReturn(keyword:TokenInfo, e:Null<Expr>);
	EThrow(keyword:TokenInfo, e:Expr);
	ENew(keyword:TokenInfo, e:Expr, args:Null<CallArgs>);
	EVectorDecl(newKeyword:TokenInfo, t:TypeParam, d:ArrayDecl);
	EField(e:Expr, dot:TokenInfo, fieldName:TokenInfo);
	EBlock(openBrace:TokenInfo, exprs:Array<BlockElement>, closeBrace:TokenInfo);
	EIf(keyword:TokenInfo, openParen:TokenInfo, econd:Expr, closeParen:TokenInfo, ethen:Expr, eelse:Null<{keyword:TokenInfo, expr:Expr}>);
	ETernary(econd:Expr, question:TokenInfo, ethen:Expr, colon:TokenInfo, eelse:Expr);
	EWhile(keyword:TokenInfo, openParen:TokenInfo, cond:Expr, closeParen:TokenInfo, body:Expr);
	EFor(keyword:TokenInfo, openParen:TokenInfo, einit:Null<Expr>, initSep:TokenInfo, econd:Null<Expr>, condSep:TokenInfo, eincr:Null<Expr>, closeParen:TokenInfo, body:Expr);
	EBinop(a:Expr, op:Binop, b:Expr);
	EPreUnop(op:PreUnop, e:Expr);
	EPostUnop(e:Expr, op:PostUnop);
	EVars(keyword:TokenInfo, vars:Separated<VarDecl>);
	EAs(e:Expr, keyword:TokenInfo, t:SyntaxType);
	EIs(e:Expr, keyword:TokenInfo, t:SyntaxType);
	EVector(v:VectorSyntax);
	ESwitch(keyword:TokenInfo, openParen:TokenInfo, subj:Expr, closeParen:TokenInfo, openBrace:TokenInfo, cases:Array<SwitchCase>, closeBrace:TokenInfo);
}

enum SwitchCase {
	CCase(keyword:TokenInfo, v:Expr, colon:TokenInfo, body:Array<BlockElement>);
	CDefault(keyword:TokenInfo, colon:TokenInfo, body:Array<BlockElement>);
}

typedef VectorSyntax = {
	var name:TokenInfo;
	var dot:TokenInfo;
	var t:TypeParam;
}

typedef TypeParam = {
	var lt:TokenInfo;
	var type:SyntaxType;
	var gt:TokenInfo;
}

typedef ArrayDecl = {
	var openBracket:TokenInfo;
	var elems:Null<Separated<Expr>>;
	var closeBracket:TokenInfo;
}

enum PreUnop {
	PreNot(t:TokenInfo);
	PreNeg(t:TokenInfo);
	PreIncr(t:TokenInfo);
	PreDecr(t:TokenInfo);
}

enum PostUnop {
	PostIncr(t:TokenInfo);
	PostDecr(t:TokenInfo);
}

typedef VarDecl = {
	var name:TokenInfo;
	var type:Null<TypeHint>;
	var init:Null<VarInit>;
}

enum Binop {
	OpAdd(t:TokenInfo);
	OpSub(t:TokenInfo);
	OpDiv(t:TokenInfo);
	OpMul(t:TokenInfo);
	OpMod(t:TokenInfo);
	OpAssign(t:TokenInfo);
	OpAssignAdd(t:TokenInfo);
	OpAssignSub(t:TokenInfo);
	OpAssignMul(t:TokenInfo);
	OpAssignDiv(t:TokenInfo);
	OpAssignMod(t:TokenInfo);
	OpEquals(t:TokenInfo);
	OpNotEquals(t:TokenInfo);
	OpStrictEquals(t:TokenInfo);
	OpNotStrictEquals(t:TokenInfo);
	OpGt(t:TokenInfo);
	OpGte(t:TokenInfo);
	OpLt(t:TokenInfo);
	OpLte(t:TokenInfo);
	OpIn(t:TokenInfo);
	OpAnd(t:TokenInfo);
	OpOr(t:TokenInfo);
}

typedef BlockElement = {
	var expr:Expr;
	var semicolon:Null<TokenInfo>;
}

typedef CallArgs = {
	var openParen:TokenInfo;
	var args:Null<Separated<Expr>>;
	var closeParen:TokenInfo;
}

enum Literal {
	LString(t:TokenInfo);
	LDecInt(t:TokenInfo);
	LHexInt(t:TokenInfo);
	LFloat(t:TokenInfo);
}

typedef Metadata = {
	var openBracket:TokenInfo;
	var name:TokenInfo;
	var args:Null<CallArgs>;
	var closeBracket:TokenInfo;
}