package ax3.filters;

class HaxeProperties extends AbstractFilter {
	var currentProperties:Null<Map<String,THaxePropDecl>>;

	override function processClass(c:TClassDecl) {
		super.processClass(c);
		c.properties = currentProperties;
		currentProperties = null;
	}

	function addProperty(name:String, set:Bool, type:TType, isPublic:Bool) {
		if (currentProperties == null) currentProperties = new Map();

		var prop = currentProperties[name];
		if (prop == null) {
			prop = {syntax: {leadTrivia: []}, name: name, get: false, set: false, type: type, isPublic: isPublic};
			currentProperties.set(name, prop);
		}

		if (set) prop.set = true else prop.get = true;
	}

	override function processClassField(f:TClassField) {
		switch (f.kind) {
			case TFVar(v): processVarFields(v.vars);
			case TFFun(field): processFunction(field.fun);
			case TFGetter(field): processGetter(field, isOverriden(f), isPublic(f));
			case TFSetter(field): processSetter(field, isOverriden(f), isPublic(f));
		}
	}

	// TODO: be smarter and check for property incompatibilities
	function isOverriden(f:TClassField):Bool {
		for (m in f.modifiers) {
			if (m.match(FMOverride(_))) {
				return true;
			}
		}
		return false;
	}

	function isPublic(f:TClassField):Bool {
		for (m in f.modifiers) {
			if (m.match(FMPublic(_))) {
				return true;
			}
		}
		return false;
	}

	function processGetter(field:TAccessorField, isOverriden:Bool, isPublic:Bool) {
		processFunction(field.fun);
		if (!isOverriden) {
			addProperty(field.name, false, field.fun.sig.ret.type, isPublic);
		}
	}

	function processSetter(field:TAccessorField, isOverriden:Bool, isPublic:Bool) {
		var sig = field.fun.sig;
		var arg = sig.args[0];
		var type = arg.type;
		sig.ret = {
			type: type,
			syntax: null
		};
		var returnKeyword = new Token(0, TkIdent, "return", [], [new Trivia(TrWhitespace, " ")]);
		var argLocal = mk(TELocal(mkIdent(arg.name), arg.v), arg.v.type, arg.v.type);
		var returnExpr = mk(TEReturn(returnKeyword, argLocal), TTVoid, TTVoid);
		field.fun.expr = concatExprs(field.fun.expr, returnExpr);

		if (!isOverriden) {
			addProperty(field.name, true, type, isPublic);
		}
	}
}
