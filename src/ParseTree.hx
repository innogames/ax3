typedef File = {
	var pack:Package;
	var declarations:Array<Declaration>;
}

typedef Package = {
	var keyword:Token;
	var name:Null<DotPath>;
	var openBrace:Token;
	var closeBrace:Token;
	var declarations:Array<Declaration>;
}

typedef Separated<T> = {
	var first:T;
	var rest:Array<{sep:Token, element:T}>;
}

typedef DotPath = Separated<Token>;

enum Declaration {
	DImport(d:ImportDecl);
	DClass(c:ClassDecl);
	DInterface(i:InterfaceDecl);
	DUseNamespace(n:UseNamespace, semicolon:Token);
	DCondComp(v:CondCompVar, openBrace:Token, decls:Array<Declaration>, closeBrace:Token);
}

typedef ImportDecl = {
	var keyword:Token;
	var path:DotPath;
	var wildcard:Null<Token>;
	var semicolon:Token;
}

typedef UseNamespace = {
	var useKeyword:Token;
	var namespaceKeyword:Token;
	var name:Token;
}

typedef ClassDecl = {
	var metadata:Array<Metadata>;
	var modifiers:Array<Token>;
	var keyword:Token;
	var name:Token;
	var extend:Null<{keyword:Token, path:DotPath}>;
	var implement:Null<{keyword:Token, paths:Separated<DotPath>}>;
	var openBrace:Token;
	var members:Array<ClassMember>;
	var closeBrace:Token;
}

typedef InterfaceDecl = {
	var metadata:Array<Metadata>;
	var modifiers:Array<Token>;
	var keyword:Token;
	var name:Token;
	var extend:Null<{keyword:Token, paths:Separated<DotPath>}>;
	var openBrace:Token;
	var fields:Array<InterfaceField>;
	var closeBrace:Token;
}

enum ClassMember {
	MUseNamespace(n:UseNamespace, semicolon:Token);
	MField(f:ClassField);
}

typedef ClassField = {
	var metadata:Array<Metadata>;
	var namespace:Null<Token>;
	var modifiers:Array<Token>;
	var kind:ClassFieldKind;
}

enum ClassFieldKind {
	FVar(keyword:Token, vars:Separated<VarDecl>, semicolon:Token);
	FFun(keyword:Token, name:Token, fun:Function);
	FProp(keyword:Token, kind:PropKind, name:Token, fun:Function);
}

enum PropKind {
	PGet(keyword:Token);
	PSet(keyword:Token);
}

typedef BracedExprBlock = {
	var openBrace:Token;
	var exprs:Array<BlockElement>;
	var closeBrace:Token;
}

typedef FunctionSignature = {
	var openParen:Token;
	var args:Separated<FunctionArg>;
	var closeParen:Token;
	var ret:Null<TypeHint>;
}

typedef Function = {
	var signature:FunctionSignature;
	var block:BracedExprBlock;
}

enum FunctionArg {
	ArgNormal(a:FunctionArgNormal);
	ArgRest(dots:Token, name:Token);
}

typedef FunctionArgNormal = {
	var name:Token;
	var hint:Null<TypeHint>;
	var init:Null<VarInit>;
}

typedef InterfaceField = {
	var metadata:Array<Metadata>;
	var kind:InterfaceFieldKind;
	var semicolon:Token;
}

enum InterfaceFieldKind {
	IFFun(keyword:Token, name:Token, fun:FunctionSignature);
	IFProp(keyword:Token, kind:PropKind, name:Token, fun:FunctionSignature);
}

typedef TypeHint = {
	var colon:Token;
	var type:SyntaxType;
}

typedef VarInit = {
	var equals:Token;
	var expr:Expr;
}

enum SyntaxType {
	TAny(star:Token);
	TPath(path:DotPath);
	TVector(v:VectorSyntax);
}

enum Expr {
	EIdent(i:Token);
	ELiteral(l:Literal);
	ECall(e:Expr, args:CallArgs);
	EParens(openParen:Token, e:Expr, closeParen:Token);
	EArrayAccess(e:Expr, openBracket:Token, eindex:Expr, closeBracket:Token);
	EArrayDecl(d:ArrayDecl);
	EReturn(keyword:Token, e:Null<Expr>);
	EThrow(keyword:Token, e:Expr);
	EDelete(keyword:Token, e:Expr);
	EBreak(keyword:Token);
	EContinue(keyword:Token);
	ENew(keyword:Token, e:Expr, args:Null<CallArgs>);
	EVectorDecl(newKeyword:Token, t:TypeParam, d:ArrayDecl);
	EField(e:Expr, dot:Token, fieldName:Token);
	EBlock(b:BracedExprBlock);
	EObjectDecl(openBrace:Token, fields:Separated<ObjectField>, closeBrace:Token);
	EIf(keyword:Token, openParen:Token, econd:Expr, closeParen:Token, ethen:Expr, eelse:Null<{keyword:Token, expr:Expr}>);
	ETernary(econd:Expr, question:Token, ethen:Expr, colon:Token, eelse:Expr);
	EWhile(keyword:Token, openParen:Token, cond:Expr, closeParen:Token, body:Expr);
	EDoWhile(doKeyword:Token, body:Expr, whileKeyword:Token, openParen:Token, cond:Expr, closeParen:Token);
	EFor(keyword:Token, openParen:Token, einit:Null<Expr>, initSep:Token, econd:Null<Expr>, condSep:Token, eincr:Null<Expr>, closeParen:Token, body:Expr);
	EForIn(forKeyword:Token, openParen:Token, iter:ForIter, closeParen:Token, body:Expr);
	EForEach(forKeyword:Token, eachKeyword:Token, openParen:Token, iter:ForIter, closeParen:Token, body:Expr);
	EBinop(a:Expr, op:Binop, b:Expr);
	EPreUnop(op:PreUnop, e:Expr);
	EPostUnop(e:Expr, op:PostUnop);
	EVars(keyword:Token, vars:Separated<VarDecl>);
	EAs(e:Expr, keyword:Token, t:SyntaxType);
	EIs(e:Expr, keyword:Token, t:SyntaxType);
	EComma(a:Expr, comma:Token, b:Expr);
	EVector(v:VectorSyntax);
	ESwitch(keyword:Token, openParen:Token, subj:Expr, closeParen:Token, openBrace:Token, cases:Array<SwitchCase>, closeBrace:Token);
	ECondCompValue(v:CondCompVar);
	ECondCompBlock(v:CondCompVar, b:BracedExprBlock);
	ETry(keyword:Token, block:BracedExprBlock, catches:Array<Catch>, finally_:Null<Finally>);
	EFunction(keyword:Token, name:Null<Token>, fun:Function);
	EUseNamespace(n:UseNamespace);
}

typedef Catch = {
	var keyword:Token;
	var openParen:Token;
	var name:Token;
	var type:TypeHint;
	var closeParen:Token;
	var block:BracedExprBlock;
}

typedef Finally = {
	var keyword:Token;
	var block:BracedExprBlock;
}

typedef CondCompVar = {
	var ns:Token;
	var sep:Token;
	var name:Token;
}

typedef ForIter = {
	var eit:Expr;
	var inKeyword:Token;
	var eobj:Expr;
}

typedef ObjectField = {
	var name:Token;
	var colon:Token;
	var value:Expr;
}

enum SwitchCase {
	CCase(keyword:Token, v:Expr, colon:Token, body:Array<BlockElement>);
	CDefault(keyword:Token, colon:Token, body:Array<BlockElement>);
}

typedef VectorSyntax = {
	var name:Token;
	var dot:Token;
	var t:TypeParam;
}

typedef TypeParam = {
	var lt:Token;
	var type:SyntaxType;
	var gt:Token;
}

typedef ArrayDecl = {
	var openBracket:Token;
	var elems:Null<Separated<Expr>>;
	var closeBracket:Token;
}

enum PreUnop {
	PreNot(t:Token);
	PreNeg(t:Token);
	PreIncr(t:Token);
	PreDecr(t:Token);
	PreBitNeg(t:Token);
}

enum PostUnop {
	PostIncr(t:Token);
	PostDecr(t:Token);
}

typedef VarDecl = {
	var name:Token;
	var type:Null<TypeHint>;
	var init:Null<VarInit>;
}

enum Binop {
	OpAdd(t:Token);
	OpSub(t:Token);
	OpDiv(t:Token);
	OpMul(t:Token);
	OpMod(t:Token);
	OpAssign(t:Token);
	OpAssignAdd(t:Token);
	OpAssignSub(t:Token);
	OpAssignMul(t:Token);
	OpAssignDiv(t:Token);
	OpAssignMod(t:Token);
	OpAssignAnd(t:Token);
	OpAssignOr(t:Token);
	OpAssignBitAnd(t:Token);
	OpAssignBitOr(t:Token);
	OpAssignBitXor(t:Token);
	OpAssignShl(t:Token);
	OpAssignShr(t:Token);
	OpAssignUshr(t:Token);
	OpEquals(t:Token);
	OpNotEquals(t:Token);
	OpStrictEquals(t:Token);
	OpNotStrictEquals(t:Token);
	OpGt(t:Token);
	OpGte(t:Token);
	OpLt(t:Token);
	OpLte(t:Token);
	OpIn(t:Token);
	OpAnd(t:Token);
	OpOr(t:Token);
	OpShl(t:Token);
	OpShr(t:Token);
	OpUshr(t:Token);
	OpBitAnd(t:Token);
	OpBitOr(t:Token);
	OpBitXor(t:Token);
}

typedef BlockElement = {
	var expr:Expr;
	var semicolon:Null<Token>;
}

typedef CallArgs = {
	var openParen:Token;
	var args:Null<Separated<Expr>>;
	var closeParen:Token;
}

enum Literal {
	LString(t:Token);
	LDecInt(t:Token);
	LHexInt(t:Token);
	LFloat(t:Token);
	LRegExp(t:Token);
}

typedef Metadata = {
	var openBracket:Token;
	var name:Token;
	var args:Null<CallArgs>;
	var closeBracket:Token;
}