package ax3.filters;

import ax3.ParseTree;
import ax3.Utils.capitalize;

class WrapModuleLevelDecls extends AbstractFilter {
	override function processModule(mod:TModule) {
		var mainDeclField = convertDeclToStaticField(mod.pack.decl);
		if (mainDeclField != null) {
			var capitalizedName = capitalize(mod.name);
			mod.parentPack.renameModule(mod, capitalizedName);
			mod.pack.decl = {
				name: capitalizedName,
				kind: TDClassOrInterface({
					syntax: {
						keyword: mkIdent("class", [], [whitespace]),
						name: mkIdent(capitalizedName, [], [whitespace]),
						openBrace: addTrailingNewline(mkOpenBrace()),
						closeBrace: addTrailingNewline(mkCloseBrace())
					},
					kind: TClass({extend: null, implement: null}),
					metadata: [],
					modifiers: [DMFinal(mkIdent("final", [], [whitespace]))],
					parentModule: mod,
					name: capitalizedName,
					members: [TMField(mainDeclField)]
				})
			};
		}
	}

	function convertDeclToStaticField(decl:TDecl):Null<TClassField> {
		switch decl.kind {
			case TDVar(v):
				return {
					metadata: v.metadata,
					namespace: null,
					modifiers: convertDeclModifiers(v.vars[0].syntax.name.pos, v.modifiers),
					kind: TFVar({
						kind: v.kind,
						isInline: v.isInline,
						vars: v.vars,
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
