package ax3;

import ax3.Token.Trivia;

class ParseTree {
	public static function dotPathToString(d:DotPath):String {
		return dotPathToArray(d).join(".");
	}

	public static function dotPathToArray(d:DotPath):Array<String> {
		return foldSeparated(d, [], (part, acc) -> acc.push(part.text));
	}

	public static function syntaxTypePos(t:SyntaxType):Int {
		return switch (t) {
			case TAny(star): star.pos;
			case TPath(path): path.first.pos;
			case TVector(v): v.name.pos;
		}
	}

	public static function getDotPathLeadingTrivia(path:DotPath):Array<Trivia> {
		return path.first.leadTrivia;
	}

	public static function getDotPathTrailingTrivia(path:DotPath):Array<Trivia> {
		return if (path.rest.length == 0) path.first.trailTrivia
		       else path.rest[path.rest.length - 1].element.trailTrivia;
	}

	public static function getSyntaxTypeLeadingTrivia(t:SyntaxType):Array<Trivia> {
		return switch t {
			case TAny(star): star.leadTrivia;
			case TPath(path): getDotPathLeadingTrivia(path);
			case TVector(v): v.name.leadTrivia;
		}
	}

	public static function getSyntaxTypeTrailingTrivia(t:SyntaxType):Array<Trivia> {
		return switch t {
			case TAny(star): star.trailTrivia;
			case TPath(path): getDotPathTrailingTrivia(path);
			case TVector(v): v.t.gt.trailTrivia;
		}
	}

	public static function exprPos(e:Expr):Int {
		return switch (e) {
			case EIdent(t) | ELiteral(LString(t) | LDecInt(t) | LHexInt(t) | LFloat(t) | LRegExp(t)): t.pos;
			case ECall(e, _) | EArrayAccess(e, _, _, _) | EField(e, _, _)  | EXmlAttr(e, _, _, _) | EXmlAttrExpr(e, _, _, _, _, _) | EXmlDescend(e, _, _): exprPos(e);
			case ETry(keyword, _) | EFunction(keyword, _) | EIf(keyword, _, _, _, _, _) | ESwitch(keyword, _) | EReturn(keyword, _) | EThrow(keyword, _) | EDelete(keyword, _) | EBreak(keyword) | EContinue(keyword) | ENew(keyword, _, _) | ETypeof(keyword, _) | EVectorDecl(keyword, _, _): keyword.pos;
			case EParens(openParen, _, _): openParen.pos;
			case EArrayDecl(d): d.openBracket.pos;
			case EBlock(b): b.openBrace.pos;
			case EObjectDecl(openBrace, _, _): openBrace.pos;
			case ETernary(econd, _, _, _, _): exprPos(econd);
			case EWhile(w): w.keyword.pos;
			case EDoWhile(w): w.doKeyword.pos;
			case EFor(f): f.keyword.pos;
			case EForIn(f): f.forKeyword.pos;
			case EForEach(f): f.forKeyword.pos;
			case EBinop(a, _, _): exprPos(a);
			case EPreUnop(PreNot(t) | PreNeg(t) | PreIncr(t) | PreDecr(t) | PreBitNeg(t), e): t.pos;
			case EPostUnop(e, _): exprPos(e);
			case EVars(VVar(t) | VConst(t), _): t.pos;
			case EAs(e, _, _): exprPos(e);
			case EVector(v): v.name.pos;
			case ECondCompValue(v) | ECondCompBlock(v, _): v.name.pos;
			case EUseNamespace(n): n.useKeyword.pos;
		}
	}

	public static function exprToDotPath(e:Expr):Null<DotPath> {
		var acc = [];
		function loop(e:Expr) {
			switch e {
				case EIdent(i):
					acc.reverse();
					return {first: i, rest: acc};
				case EField(e, dot, fieldName):
					acc.push({sep: dot, element: fieldName});
					return loop(e);
				case _:
					return null;
			}
		}
		return loop(e);
	}

	public static function separatedToArray<T,S>(s:Separated<T>, f:(T,Null<Token>)->S):Array<S> {
		var r = [];
		var sep = if (s.rest.length > 0) s.rest[0].sep else null;
		r.push(f(s.first, sep));
		for (i in 0...s.rest.length) {
			var sep = if (i == s.rest.length - 1) null else s.rest[i + 1].sep;
			r.push(f(s.rest[i].element, sep));
		}
		return r;
	}

	public static function iterSeparated<T>(d:Separated<T>, f:T->Void) {
		f(d.first);
		for (p in d.rest) {
			f(p.element);
		}
	}

	public static function foldSeparated<T,S>(d:Separated<T>, acc:S, f:(T,S)->Void):S {
		f(d.first, acc);
		for (p in d.rest) {
			f(p.element, acc);
		}
		return acc;
	}

	public static function getNamespaceUses(pack:PackageDecl):Array<{n:UseNamespace, semicolon:Token}> {
		var r = [];
		for (d in pack.declarations) {
			switch d {
				case DUseNamespace(n, semicolon):
					r.push({n: n, semicolon: semicolon});
				case _:
			}
		}
		return r;
	}

	public static function getPackageDecl(file:File):PackageDecl {
		var pack = null;
		for (decl in file.declarations) {
			switch (decl) {
				case DPackage(p):
					if (pack != null) throw 'Duplicate package decl in ${file.name}';
					pack = p;
				case _:
			}
		}
		if (pack == null) throw "No package declaration in " + file.name;
		return pack;
	}

	public static function getPackageMainDecl(p:PackageDecl):Declaration {
		var decl = null;

		function loop(decls:Array<Declaration>) {
			for (d in decls) {
				switch (d) {
					case DPackage(p):
						throw "Package inside package is not allowed";

					case DClass(_) | DInterface(_) | DFunction(_) | DVar(_) | DNamespace(_):
						if (decl != null) throw "More than one declaration inside package";
						decl = d;

					case DCondComp(_, _, decls, _):
						loop(decls);

					// skip these for now
					case DImport(_):
					case DUseNamespace(_):
				}
			}
		}


		loop(p.declarations);

		if (decl == null) throw "No declaration inside package";

		return decl;
	}

	public static function getPrivateDecls(file:File):Array<Declaration> {
		var decls = [];

		function loop(declarations:Array<Declaration>) {
			for (d in declarations) {
				switch (d) {
					case DPackage(p): // in-package is the main one

					case DClass(_) | DInterface(_) | DFunction(_) | DVar(_):
						decls.push(d);

					case DCondComp(_, _, decls, _):
						loop(decls);

					case DNamespace(ns): throw "assert";
					case DImport(i):
					case DUseNamespace(n, semicolon):
				}
			}
		}

		loop(file.declarations);

		return decls;
	}

	public static function getImports(file:File) {
		var result = [];
		function loop(decls:Array<Declaration>) {
			for (d in decls) {
				switch (d) {
					case DPackage(p): loop(p.declarations);
					case DImport(i): result.push(i);
					case DCondComp(_, _, decls, _): loop(decls);
					case _:
				}
			}
		}
		loop(file.declarations);
		return result;
	}
}

typedef File = {
	var path:String;
	var name:String;
	var declarations:Array<Declaration>;
	var eof:Token;
}

typedef Separated<T> = {
	var first:T;
	var rest:Array<{sep:Token, element:T}>;
}

typedef DotPath = Separated<Token>;

enum Declaration {
	DPackage(p:PackageDecl);
	DImport(i:ImportDecl);
	DClass(c:ClassDecl);
	DInterface(i:InterfaceDecl);
	DFunction(f:FunctionDecl);
	DVar(v:ModuleVarDecl);
	DNamespace(ns:NamespaceDecl);
	DUseNamespace(n:UseNamespace, semicolon:Token);
	DCondComp(v:CondCompVar, openBrace:Token, decls:Array<Declaration>, closeBrace:Token);
}

typedef PackageDecl = {
	var keyword:Token;
	var name:Null<DotPath>;
	var openBrace:Token;
	var declarations:Array<Declaration>;
	var closeBrace:Token;
}

typedef NamespaceDecl = {
	var modifiers:Array<DeclModifier>;
	var keyword:Token;
	var name:Token;
	var semicolon:Token;
}

typedef ModuleVarDecl = {
	var metadata:Array<Metadata>;
	var modifiers:Array<DeclModifier>;
	var kind:VarDeclKind;
	var vars:Separated<VarDecl>;
	var semicolon:Token;
}

typedef ImportDecl = {
	var keyword:Token;
	var path:DotPath;
	var wildcard:Null<{dot:Token, asterisk:Token}>;
	var semicolon:Token;
}

typedef UseNamespace = {
	var useKeyword:Token;
	var namespaceKeyword:Token;
	var name:Token;
}

enum DeclModifier {
	DMPublic(t:Token);
	DMInternal(t:Token);
	DMFinal(t:Token);
	DMDynamic(t:Token);
}

typedef FunctionDecl = {
	var metadata:Array<Metadata>;
	var modifiers:Array<DeclModifier>;
	var keyword:Token;
	var name:Token;
	var fun:Function;
}

typedef ClassDecl = {
	var metadata:Array<Metadata>;
	var modifiers:Array<DeclModifier>;
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
	var modifiers:Array<DeclModifier>;
	var keyword:Token;
	var name:Token;
	var extend:Null<{keyword:Token, paths:Separated<DotPath>}>;
	var openBrace:Token;
	var members:Array<InterfaceMember>;
	var closeBrace:Token;
}

enum ClassMember {
	MCondComp(v:CondCompVar, openBrace:Token, members:Array<ClassMember>, closeBrace:Token);
	MUseNamespace(n:UseNamespace, semicolon:Token);
	MField(f:ClassField);
	MStaticInit(block:BracedExprBlock);
}

typedef ClassField = {
	var metadata:Array<Metadata>;
	var namespace:Null<Token>;
	var modifiers:Array<ClassFieldModifier>;
	var kind:ClassFieldKind;
}

enum ClassFieldModifier {
	FMPublic(t:Token);
	FMPrivate(t:Token);
	FMProtected(t:Token);
	FMInternal(t:Token);
	FMOverride(t:Token);
	FMStatic(t:Token);
	FMFinal(t:Token);
}

enum ClassFieldKind {
	FVar(kind:VarDeclKind, vars:Separated<VarDecl>, semicolon:Token);
	FFun(keyword:Token, name:Token, fun:Function);
	FGetter(keyword:Token, getKeyword:Token, name:Token, fun:Function);
	FSetter(keyword:Token, setKeyword:Token, name:Token, fun:Function);
}

typedef BracedExprBlock = {
	var openBrace:Token;
	var exprs:Array<BlockElement>;
	var closeBrace:Token;
}

typedef FunctionSignature = {
	var openParen:Token;
	var args:Null<Separated<FunctionArg>>;
	var closeParen:Token;
	var ret:Null<TypeHint>;
}

typedef Function = {
	var signature:FunctionSignature;
	var block:BracedExprBlock;
}

enum FunctionArg {
	ArgNormal(a:VarDecl);
	ArgRest(dots:Token, name:Token, typeHint:Null<TypeHint>);
}

enum InterfaceMember {
	MICondComp(v:CondCompVar, openBrace:Token, members:Array<InterfaceMember>, closeBrace:Token);
	MIField(f:InterfaceField);
}

typedef InterfaceField = {
	var metadata:Array<Metadata>;
	var kind:InterfaceFieldKind;
	var semicolon:Token;
}

enum InterfaceFieldKind {
	IFFun(keyword:Token, name:Token, fun:FunctionSignature);
	IFGetter(keyword:Token, getKeyword:Token, name:Token, fun:FunctionSignature);
	IFSetter(keyword:Token, setKeyword:Token, name:Token, fun:FunctionSignature);
}

typedef TypeHint = {
	var colon:Token;
	var type:SyntaxType;
}

typedef VarInit = {
	var equalsToken:Token;
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
	ETypeof(keyword:Token, e:Expr);
	EThrow(keyword:Token, e:Expr);
	EDelete(keyword:Token, e:Expr);
	EBreak(keyword:Token);
	EContinue(keyword:Token);
	ENew(keyword:Token, e:Expr, args:Null<CallArgs>);
	EVectorDecl(newKeyword:Token, t:TypeParam, d:ArrayDecl);
	EField(e:Expr, dot:Token, fieldName:Token);
	EXmlAttr(e:Expr, dot:Token, at:Token, attrName:Token);
	EXmlAttrExpr(e:Expr, dot:Token, at:Token, openBracket:Token, eattr:Expr, closeBracket:Token);
	EXmlDescend(e:Expr, dotDot:Token, childName:Token);
	EBlock(b:BracedExprBlock);
	EObjectDecl(openBrace:Token, fields:Separated<ObjectField>, closeBrace:Token);
	EIf(keyword:Token, openParen:Token, econd:Expr, closeParen:Token, ethen:Expr, eelse:Null<{keyword:Token, expr:Expr, semiliconBefore: Bool}>);
	ETernary(econd:Expr, question:Token, ethen:Expr, colon:Token, eelse:Expr);
	EWhile(w:While);
	EDoWhile(w:DoWhile);
	EFor(f:For);
	EForIn(f:ForIn);
	EForEach(f:ForEach);
	EBinop(a:Expr, op:Binop, b:Expr);
	EPreUnop(op:PreUnop, e:Expr);
	EPostUnop(e:Expr, op:PostUnop);
	EVars(kind:VarDeclKind, vars:Separated<VarDecl>);
	EAs(e:Expr, keyword:Token, t:SyntaxType);
	EVector(v:VectorSyntax);
	ESwitch(keyword:Token, openParen:Token, subj:Expr, closeParen:Token, openBrace:Token, cases:Array<SwitchCase>, closeBrace:Token);
	ECondCompValue(v:CondCompVar);
	ECondCompBlock(v:CondCompVar, b:BracedExprBlock);
	ETry(keyword:Token, block:BracedExprBlock, catches:Array<Catch>, finally_:Null<Finally>);
	EFunction(keyword:Token, name:Null<Token>, fun:Function);
	EUseNamespace(n:UseNamespace);
}

typedef While = {
	var keyword:Token;
	var openParen:Token;
	var cond:Expr;
	var closeParen:Token;
	var body:Expr;
}

typedef DoWhile = {
	var doKeyword:Token;
	var body:Expr;
	var whileKeyword:Token;
	var openParen:Token;
	var cond:Expr;
	var closeParen:Token;
}

typedef For = {keyword:Token, openParen:Token, einit:Null<Expr>, initSep:Token, econd:Null<Expr>, condSep:Token, eincr:Null<Expr>, closeParen:Token, body:Expr}
typedef ForIn = {forKeyword:Token, openParen:Token, iter:ForIter, closeParen:Token, body:Expr}
typedef ForEach = {forKeyword:Token, eachKeyword:Token, openParen:Token, iter:ForIter, closeParen:Token, body:Expr}

enum VarDeclKind {
	VVar(t:Token);
	VConst(t:Token);
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
	var nameKind:ObjectFieldNameKind;
	var colon:Token;
	var value:Expr;
}

enum ObjectFieldNameKind {
	FNIdent;
	FNStringSingle;
	FNStringDouble;
	FNInteger;
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
	OpAssignOp(op:AssignOp);
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
	OpIs(t:Token);
	OpComma(t:Token);
}

enum AssignOp {
	AOpAdd(t:Token);
	AOpSub(t:Token);
	AOpMul(t:Token);
	AOpDiv(t:Token);
	AOpMod(t:Token);
	AOpAnd(t:Token);
	AOpOr(t:Token);
	AOpBitAnd(t:Token);
	AOpBitOr(t:Token);
	AOpBitXor(t:Token);
	AOpShl(t:Token);
	AOpShr(t:Token);
	AOpUshr(t:Token);
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
	var args:Null<CallArgs>; // TODO: metadata probably only supports literals, not any exprs
	var closeBracket:Token;
}
