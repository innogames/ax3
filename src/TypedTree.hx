typedef TModule = {
	var pack:Array<String>;
	var name:String;
	var packDecl:ParseTree.PackageDecl;
	var syntax:ParseTree.File;
	var mainType:TDecl;
}

enum TDecl {
	TDClass(c:TClass);
	TDInterface(i:TInterface);
}

typedef TClass = {
	var syntax:ParseTree.ClassDecl;
	var fields:Array<TClassField>;
	var fieldMap:Map<String,TClassField>;
}

typedef TInterface = {
	var syntax:ParseTree.InterfaceDecl;
}

typedef TClassField = {
	var name:Token;
	var kind:TClassFieldKind;
}

enum TClassFieldKind {
	TFVar(v:TFVarDecl);
	TFFun(f:TFFunDecl);
}

typedef TFFunDecl = {
	var keyword:Token;
	var fun:TFunction;
}

typedef TFunction = {
	var signature:TFunctionSignature;
	var expr:TExpr;
}

typedef TFunctionSignature = {
	var syntax:ParseTree.FunctionSignature;
	var args:Array<TFunctionArg>;
}

typedef TFunctionArg = {
	var syntax:ParseTree.VarDecl;
	var comma:Null<Token>;
}

typedef TBracedExprBlock = {
	var syntax:ParseTree.BracedExprBlock;
}

typedef TFVarDecl = {
	var syntax:ParseTree.VarDecl;
	var kind:ParseTree.VarDeclKind;
	var init:Null<TVarInit>;
	var endToken:Token; // comma or semicolon
}

typedef TVarInit = {
	var syntax:ParseTree.VarInit;
	var expr:TExpr;
}

typedef TExpr = {
	var kind:TExprKind;
	var type:TType;
}

enum TExprKind {
	TELocal(token:Token, v:TVar);
	TEArrayAccess(e:TExpr, openBracket:Token, eindex:TExpr, closeBracket:Token);
	TECall(e:TExpr, args:TCallArgs);
	TENew(keyword:Token, e:TExpr, args:Null<TCallArgs>);
	TELiteral(l:ParseTree.Literal);
	TEBinop(a:TExpr, op:ParseTree.Binop, b:TExpr);
	TEBlock(openBrace:Token, exprs:Array<TBlockElement>, closeBrace:Token);
	TEContinue(syntax:Token);
	TEBreak(syntax:Token);
	TEThrow(keyword:Token, e:TExpr);
	TEReturn(keyword:Token, e:Null<TExpr>);
	TEDelete(keyword:Token, e:TExpr);
	TEIf(keyword:Token, openParen:Token, econd:TExpr, closeParen:Token, ethen:TExpr, eelse:Null<{keyword:Token, expr:TExpr}>);
	TETernary(econd:TExpr, question:Token, ethen:TExpr, colon:Token, eelse:TExpr);
	TThis(t:Token);
	TSuper(t:Token);
	TNull(t:Token);
	TEPreUnop(op:ParseTree.PreUnop, e:TExpr);
	TEPostUnop(e:TExpr, op:ParseTree.PostUnop);
	TETry(keyword:Token, expr:TExpr, catches:Array<TCatch>);
	TEComma(a:TExpr, comma:Token, b:TExpr);
	TEParens(openParen:Token, e:TExpr, closeParen:Token);
	TEVars(kind:ParseTree.VarDeclKind, vars:Array<{decl:TVarDecl, comma:Null<Token>}>);
	TEWhile(keyword:Token, openParen:Token, cond:TExpr, closeParen:Token, body:TExpr);
	TEDoWhile(doKeyword:Token, body:TExpr, whileKeyword:Token, openParen:Token, cond:TExpr, closeParen:Token);
	TEObjectDecl(openBrace:Token, fields:Array<{field:TObjectField, comma:Token}>, closeBrace:Token);
	TEField(e:TExpr, dot:Token, fieldName:Token);
	TEArrayDecl(d:TArrayDecl);
}

typedef TVar = {
	
}

typedef TArrayDecl = {
	var openBracket:Token;
	var elems:Array<{expr:TExpr, comma:Null<Token>}>;
	var closeBracket:Token;
}

typedef TObjectField = {
	var name:Token;
	var colon:Token;
	var value:TExpr;
}

typedef TVarDecl = {
	var syntax:ParseTree.VarDecl;
	var init:Null<TVarInit>;
}

typedef TCatch = {
	var syntax:ParseTree.Catch;
	var expr:TExpr;
}

typedef TCallArgs = {
	var openParen:Token;
	var args:Array<{expr:TExpr, comma:Null<Token>}>;
	var closeParen:Token;
}

typedef TBlockElement = {
	var expr:TExpr;
	var semicolon:Null<Token>;
}

enum TType {
	TString;
	TNumber;
	TInt;
	TUint;
	TBoolean;
	TAny;
	TObject;
	TArray;
	TVoid;
	TUnresolved(path:String);
}
