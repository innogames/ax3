import ParseTree.Expr;
import ParseTree.Literal;
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
	TEBuiltin(syntax:Token, name:String);
	TEDeclRef(c:SDecl);
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
