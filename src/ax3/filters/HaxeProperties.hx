package ax3.filters;

private typedef Modifiers = {
	final isPublic:Bool;
	final isStatic:Bool;
	final isOverride:Bool;
}

class HaxeProperties extends AbstractFilter {
	var currentClass:TClassOrInterfaceDecl;
	var currentProperties:Null<Map<String,THaxePropDecl>>;
	var flashPropertyOverrides:Null<Array<TClassField>>;

	override function processClass(c:TClassOrInterfaceDecl) {
		currentClass = c;
		super.processClass(c);
		currentClass = null;

		c.haxeProperties = currentProperties;
		currentProperties = null;

		if (flashPropertyOverrides != null) {
			for (f in flashPropertyOverrides) {
				c.members.push(TMField(f));
			}
			flashPropertyOverrides = null;
		}
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
			case TFGetter(field): processGetter(f, field, getMods(f));
			case TFSetter(field): processSetter(f, field, getMods(f));
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
			isPublic: isPublic || f.namespace != null, // TODO: generate @:access instead
			isStatic: isStatic,
			isOverride: isOverride
		};
	}

	function overridingExternProperty(cls:TClassOrInterfaceDecl, name:String, getter:Bool):Bool {
		function loop(cls:TClassOrInterfaceDecl) {
			switch cls.kind {
				case TClass({extend: {superClass: superClass}}):
					if (superClass.parentModule.isExtern) {
						return true;
					} else {
						for (member in superClass.members) {
							switch member {
								case TMField(classField):
									if (TypedTreeTools.isFieldStatic(classField)) {
										continue;
									}
									switch classField.kind {
										case TFGetter(a) if (getter && a.name == name): return false;
										case TFSetter(a) if (!getter && a.name == name): return false;
										case _:
									}
								case TMUseNamespace(_) | TMCondCompBegin(_) | TMCondCompEnd(_) | TMStaticInit(_):
							}
						}
						return loop(superClass);
					}
				case _:
					return false;
			}
		}
		return loop(cls);
	}

	// TODO: handle trivia (if `override` is the first modifier we probably have an indent whitespace before it)
	function removeOverrideModifier(field:TClassField) {
		field.modifiers = [for (m in field.modifiers) if (!m.match(FMOverride(_))) m];
	}

	// TODO: handle trivia (if `public` is the first modifier we probably have an indent whitespace before it)
	function removePublicModifier(field:TClassField) {
		field.modifiers = [for (m in field.modifiers) if (!m.match(FMPublic(_))) m];
	}

	inline function addFlashPropertyOverride(method:TClassField) {
		if (flashPropertyOverrides == null) flashPropertyOverrides = [];
		flashPropertyOverrides.push(method);
	}

	function processGetter(field:TClassField, accessor:TAccessorField, mods:Modifiers) {
		processFunction(accessor.fun);

		removePublicModifier(field);

		if (!mods.isOverride) {
			addProperty(accessor.name, false, accessor.fun.sig.ret.type, mods);
		} else if (overridingExternProperty(currentClass, accessor.name, true)) {
			// if we're overriding an accessor from swc, we gotta introduce an extra method with special meta,
			// so haxe generates an accessor field in the ABC bytecode.

			// first, remove the `override` modifier, since from Haxe standpoint, we're not overriding get_field method
			removeOverrideModifier(field);

			var haxeMethodName = "get_" + accessor.name;
			var specialMethodName = "_get_" + accessor.name;

			var tMethod = TTFun([], accessor.propertyType);
			var eMethod = mk(TEField({kind: TOImplicitThis(currentClass), type: TTInst(currentClass)}, haxeMethodName, mkIdent(haxeMethodName)), tMethod, tMethod);
			var eMethodCall = mkCall(eMethod, [], accessor.propertyType, [newline]);

			addFlashPropertyOverride({
				metadata: [MetaHaxe('@:getter(${accessor.name})')],
				namespace: null,
				modifiers: [],
				kind: TFFun({
					syntax: {
						keyword: addTrailingWhitespace(mkIdent("function")),
						name: mkIdent(specialMethodName)
					},
					name: specialMethodName,
					fun: {
						sig: accessor.fun.sig,
						expr: mk(TEReturn(mkTokenWithSpaces(TkIdent, "return"), eMethodCall), TTVoid, TTVoid)
					},
					semicolon: null
				})
			});
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
			addProperty(accessor.name, true, type, mods);
		} else if (overridingExternProperty(currentClass, accessor.name, false)) {
			// if we're overriding an accessor from swc, we gotta introduce an extra method with special meta,
			// so haxe generates an accessor field in the ABC bytecode.

			// first, remove the `override` modifier, since from Haxe standpoint, we're not overriding get_field method
			// TODO: handle trivia (if `override` is the first modifier we probably have an indent whitespace before it)
			removeOverrideModifier(field);

			var haxeMethodName = "set_" + accessor.name;
			var specialMethodName = "_set_" + accessor.name;

			var argLocal = mk(TELocal(mkIdent(arg.name), arg.v), arg.v.type, arg.v.type);
			var tMethod = TTFun([], accessor.propertyType);
			var eMethod = mk(TEField({kind: TOImplicitThis(currentClass), type: TTInst(currentClass)}, haxeMethodName, mkIdent(haxeMethodName, [whitespace])), tMethod, tMethod);
			var eMethodCall = mkCall(eMethod, [argLocal], accessor.propertyType, [newline]);

			addFlashPropertyOverride({
				metadata: [MetaHaxe('@:setter(${accessor.name})')],
				namespace: null,
				modifiers: [],
				kind: TFFun({
					syntax: {
						keyword: addTrailingWhitespace(mkIdent("function")),
						name: mkIdent(specialMethodName)
					},
					name: specialMethodName,
					fun: {
						sig: accessor.fun.sig.with(ret = {syntax: null, type: TTVoid}),
						expr: eMethodCall
					},
					semicolon: null
				})
			});
		}
	}
}
