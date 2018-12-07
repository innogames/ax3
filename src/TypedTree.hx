typedef TModule = {
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
}

typedef TFVarDecl = {
	var kind:ParseTree.VarDeclKind;
	var endToken:Token; // comma or semicolon
}
