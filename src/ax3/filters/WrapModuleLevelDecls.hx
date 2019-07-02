package ax3.filters;

import ax3.ParseTree;

// TODO: add static import to this package's `import.hx`
// TODO: rewrite imports to a static field import (have to also change TEDeclRefs)
// TODO: also collect private module declarations in a class and change access to them
class WrapModuleLevelDecls extends AbstractFilter {
	override function processModule(mod:TModule) {
		var mainDeclField = convertDeclToStaticField(mod.pack.decl);
		if (mainDeclField != null) {
			var moduleName = makeHaxeModuleName(mod.name);
			mod.parentPack.renameModule(mod, moduleName);
			mod.pack.decl = {
				name: moduleName,
				kind: TDClassOrInterface({
					syntax: {
						keyword: mkIdent("class", [], [whitespace]),
						name: mkIdent(moduleName, [], [whitespace]),
						openBrace: addTrailingNewline(mkOpenBrace()),
						closeBrace: addTrailingNewline(mkCloseBrace())
					},
					kind: TClass({extend: null, implement: null}),
					metadata: [],
					modifiers: [DMFinal(mkIdent("final", [], [whitespace]))],
					parentModule: mod,
					name: moduleName,
					members: [TMField(mainDeclField)]
				})
			};
		}
	}

	static function makeHaxeModuleName(s:String):String {
		var firstChar = s.charAt(0);
		return
			if (firstChar == "_")
				"Underscore" + s.substring(1)
			else
				firstChar.toUpperCase() + s.substring(1);
	}

	function convertDeclToStaticField(decl:TDecl):Null<TClassField> {
		switch decl.kind {
			case TDVar(v):
				return {
					metadata: v.metadata,
					namespace: null,
					modifiers: convertDeclModifiers(v.syntax.name.pos, v.modifiers),
					kind: TFVar({
						kind: v.kind,
						syntax: v.syntax,
						name: v.name,
						type: v.type,
						init: v.init,
						isInline: v.isInline,
						semicolon: v.semicolon
					})
				};

			case TDFunction(f):
				return {
					metadata: f.metadata,
					namespace: null,
					modifiers: convertDeclModifiers(f.syntax.keyword.pos, f.modifiers),
					kind: TFFun({
						syntax: f.syntax,
						name: f.name,
						fun: f.fun,
						type: getFunctionTypeFromSignature(f.fun.sig),
						isInline: false,
						semicolon: null
					})
				};

			case TDClassOrInterface(_) | TDNamespace(_):
				return null;
		}
	}

	function convertDeclModifiers(pos:Int, mods:Array<DeclModifier>):Array<ClassFieldModifier> {
		var result = [];
		switch mods {
			case [DMPublic(t)]: result.push(FMPublic(t));
			case [DMInternal(t)]: result.push(FMInternal(t));
			case _: reportError(pos, "Unknown module-level function/var modifiers");
		}
		result.push(FMStatic(mkIdent("static", [], [whitespace])));
		return result;
	}
}
