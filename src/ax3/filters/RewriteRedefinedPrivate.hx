package ax3.filters;

typedef FieldRedefinitions = Map<TClassOrInterfaceDecl, Map<String, String>>;

class DetectFieldRedefinitions extends AbstractFilter {
	public final redefinitions = new FieldRedefinitions();

	override function processClass(c:TClassOrInterfaceDecl) {
		switch c.kind {
			case TInterface(_) | TClass({extend: null}):
				// nothing to do for interfaces and parent-less classes
			case TClass(info):
				for (m in c.members) {
					switch m {
						case TMField(field):
							switch (field.kind) {
								case TFVar({name: name}) | TFFun({name: name}) | TFGetter({name: name}) | TFSetter({name: name}):
									markRedefinition(info.extend.superClass, name);
							}
						case _:
					}
				}
		}
	}

	function markRedefinition(superClass:TClassOrInterfaceDecl, name:String) {
		var parentDefinition = superClass.findFieldInHierarchy(name, false);
		if (parentDefinition == null) {
			// no redefinition
			return;
		}

		var c = parentDefinition.declaringClass;

		var field = parentDefinition.field;
		var isPrivate = Lambda.exists(field.modifiers, m -> m.match(FMPrivate(_)));

		if (!isPrivate) {
			// not a problem
			return;
		}

		// register
		var fields = redefinitions[c];
		if (fields == null) {
			fields = redefinitions[c] = new Map();
		}
		if (fields.exists(name)) {
			// already mangled
			return;
		}
		var qualifier = if (c.parentModule.parentPack.name == "") c.name else StringTools.replace(c.parentModule.parentPack.name, ".", "_") + "_" + c.name;
		var mangledName = name + "__" + qualifier; // should be pretty unique
		fields[name] = mangledName;
	}
}

class RenameRedefinedFields extends AbstractFilter {
	public final redefinitions:FieldRedefinitions;
	var redefinedFields:Null<Map<String,String>>;
	var thisClass:Null<TClassOrInterfaceDecl>;

	public function new(context, detector:DetectFieldRedefinitions) {
		super(context);
		this.redefinitions = detector.redefinitions;
	}

	override function processClass(c:TClassOrInterfaceDecl) {
		redefinedFields = redefinitions[c];
		if (redefinedFields != null) {
			// only process classes that have redefinitions
			thisClass = c;
			super.processClass(c);
			redefinedFields = null;
			thisClass = null;
		}
	}

	inline function maybeMangle(name:String, f:(mangledName:String)->Void) {
		var mangledName = redefinedFields[name];
		if (mangledName != null) f(mangledName);
	}

	static inline function changeToken(t:Token, name:String):Token {
		return new Token(t.pos, TkIdent, name, t.leadTrivia, [new Trivia(TrBlockComment, "/*redefined private*/")].concat(t.trailTrivia));
	}

	override function processClassField(field:TClassField) {
		switch (field.kind) {
			case TFVar(v):
				maybeMangle(v.name, mangledName -> {
					v.name = mangledName;
					v.syntax.name = changeToken(v.syntax.name, mangledName);
				});
			case TFFun(field):
				maybeMangle(field.name, mangledName -> {
					field.name = mangledName;
					field.syntax.name = changeToken(field.syntax.name, mangledName);
				});

			case TFGetter(field) | TFSetter(field):
				maybeMangle(field.name, mangledName -> {
					field.name = mangledName;
					field.syntax.name = changeToken(field.syntax.name, mangledName);
				});
		}

		super.processClassField(field); // recurse into expressions
	}

	override function processExpr(e:TExpr):TExpr {
		e = mapExpr(processExpr, e);
		return switch e.kind {
			case TEField(obj = {type: TTInst(c)}, fieldName, fieldToken) if (c == thisClass && redefinedFields.exists(fieldName)):
				var mangledName = redefinedFields[fieldName];
				e.with(kind = TEField(obj, mangledName, fieldToken.with(TkIdent, mangledName)));
			case _:
				e;
		}
	}
}