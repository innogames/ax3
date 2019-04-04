package ax3.filters;

private typedef Modifiers = {
	final isPublic:Bool;
	final isStatic:Bool;
	final isOverride:Bool;
}

class HaxeProperties extends AbstractFilter {
	var currentProperties:Null<Map<String,THaxePropDecl>>;

	override function processClass(c:TClassDecl) {
		super.processClass(c);
		c.properties = currentProperties;
		currentProperties = null;
	}

	function addProperty(name:String, set:Bool, type:TType, mods:Modifiers) {
		if (currentProperties == null) currentProperties = new Map();

		var prop = currentProperties[name];
		if (prop == null) {
			prop = {syntax: {leadTrivia: []}, name: name, get: false, set: false, type: type, isPublic: mods.isPublic, isStatic: mods.isStatic};
			currentProperties.set(name, prop);
		}

		if (set) prop.set = true else prop.get = true;
	}

	override function processClassField(f:TClassField) {
		switch (f.kind) {
			case TFVar(v): processVarFields(v.vars);
			case TFFun(field): processFunction(field.fun);
			case TFGetter(field): processGetter(field, getMods(f));
			case TFSetter(field): processSetter(field, getMods(f));
		}
	}

	function getMods(f:TClassField):Modifiers {
		var isPublic = false, isStatic = false, isOverride = false;
		for (m in f.modifiers) {
			switch m {
				case FMInternal(_) | FMPublic(_): isPublic = true;
				case FMOverride(_): isOverride = true;
				case FMStatic(_): isStatic = true;
				case FMPrivate(_) | FMProtected(_) | FMFinal(_):
			}
		}
		return {
			isPublic: isPublic,
			isStatic: isStatic,
			isOverride: isOverride
		};
	}

	function processGetter(field:TAccessorField, mods:Modifiers) {
		processFunction(field.fun);
		if (!mods.isOverride) {
			addProperty(field.name, false, field.fun.sig.ret.type, mods);
		}
	}

	function processSetter(field:TAccessorField, mods:Modifiers) {
		var sig = field.fun.sig;
		var arg = sig.args[0];
		var type = arg.type;
		sig.ret = {
			type: type,
			syntax: null
		};
		var argLocal = {
			var tok = mkIdent(arg.name);
			tok.leadTrivia.push(whitespace);
			mk(TELocal(tok, arg.v), arg.v.type, arg.v.type);
		}

		function rewriteReturns(e:TExpr):TExpr {
			return switch e.kind {
				case TELocalFunction(_): e;
				case TEReturn(keyword, null): e.with(kind = TEReturn(keyword, argLocal));
				case _: mapExpr(rewriteReturns, e);
			}
		}

		var finalReturnExpr = mk(TEReturn(mkIdent("return"), argLocal), TTVoid, TTVoid);
		field.fun.expr = concatExprs(rewriteReturns(field.fun.expr), finalReturnExpr);

		if (!mods.isOverride) {
			addProperty(field.name, true, type, mods);
		}
	}
}
