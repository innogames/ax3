package ax3.filters;

private typedef Modifiers = {
	final isPublic:Bool;
	final isStatic:Bool;
	final isOverride:Bool;
}

class HaxeProperties extends AbstractFilter {
	var currentClass:TClassOrInterfaceDecl;
	var currentProperties:Null<Map<String,THaxePropDecl>>;

	override function processClass(c:TClassOrInterfaceDecl) {
		currentClass = c;
		super.processClass(c);
		currentClass = null;
		currentProperties = null;
	}

	override function processClassField(f:TClassField) {
		switch f.kind {
			case TFGetter(field): processGetter(f, field, getMods(f));
			case TFSetter(field): processSetter(f, field, getMods(f));
			case TFVar(_) | TFFun(_):
		}
	}

	function addProperty(name:String, set:Bool, type:TType, mods:Modifiers):Null<THaxePropDecl> {
		if (currentProperties == null) currentProperties = new Map();

		var prop = currentProperties[name];
		var isNewProperty = (prop == null);
		if (isNewProperty) {
			prop = {syntax: {leadTrivia: []}, name: name, get: false, set: false, type: type, isPublic: mods.isPublic, isStatic: mods.isStatic};
			currentProperties.set(name, prop);
		}

		if (set) prop.set = true else prop.get = true;

		return if (isNewProperty) prop else null;
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
			isPublic: isPublic || f.namespace != null, // TODO: generate @:access instead
			isStatic: isStatic,
			isOverride: isOverride
		};
	}

	function removePublicModifier(field:TClassField) {
		// TODO: handle trivia (if `public` or namespace is the first modifier we probably have an indent whitespace before it)
		field.modifiers = [for (m in field.modifiers) if (!m.match(FMPublic(_))) m];
		field.namespace = null;
	}

	function processGetter(field:TClassField, accessor:TAccessorField, mods:Modifiers) {
		removePublicModifier(field);
		if (!mods.isOverride) {
			var prop = addProperty(accessor.name, false, accessor.fun.sig.ret.type, mods);
			if (prop != null) {
				accessor.haxeProperty = prop;
			}
		}
	}

	function processSetter(field:TClassField, accessor:TAccessorField, mods:Modifiers) {
		var sig = accessor.fun.sig;
		var arg = sig.args[0];
		var type = arg.type;
		sig.ret = {
			type: type,
			syntax: null
		};

		removePublicModifier(field);

		if (accessor.fun.expr != null) {
			var argLocal = mk(TELocal(mkIdent(arg.name, [whitespace]), arg.v), arg.v.type, arg.v.type);
			function rewriteReturns(e:TExpr):TExpr {
				return switch e.kind {
					case TELocalFunction(_): e;
					case TEReturn(keyword, null): e.with(kind = TEReturn(keyword, argLocal));
					case _: mapExpr(rewriteReturns, e);
				}
			}

			var finalReturnExpr = mk(TEReturn(mkIdent("return"), argLocal), TTVoid, TTVoid);
			accessor.fun.expr = concatExprs(rewriteReturns(accessor.fun.expr), finalReturnExpr);
		}

		if (!mods.isOverride) {
			var prop = addProperty(accessor.name, true, type, mods);
			if (prop != null) {
				accessor.haxeProperty = prop;
			}
		}
	}
}
