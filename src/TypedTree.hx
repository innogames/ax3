import ParseTree;
import Structure;

typedef TExpr = {
	var kind:TExprKind;
	var type:TType;
}

enum TExprKind {
	TELiteral(l:TLiteral);
	TELocal(syntax:Token, v:TVar);
	TEField(syntax:Expr, obj:TExpr, fieldName:String);
	TEThis(syntax:Null<Expr>);
	TESuper(syntax:Expr);
	TEBuiltin(syntax:Token, name:String);
	TEDeclRef(c:SDecl);
	TECall(syntax:{eobj:Expr, args:CallArgs}, eobj:TExpr, args:Array<TExpr>);
	TEArrayDecl(syntax:ArrayDecl, elems:Array<TExpr>);
	TEReturn(keyword:Token, e:Null<TExpr>);
	TEThrow(keyword:Token, e:TExpr);
	TEDelete(keyword:Token, e:TExpr);
	TEBreak(keyword:Token);
	TEContinue(keyword:Token);
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
