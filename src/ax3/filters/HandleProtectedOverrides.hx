package ax3.filters;

/**
	There's no `protected` in Haxe (private is protected actually),
	but when overriding protected methods from an SWC, in order to generate
	the correct code, the overriden method must actually be generated as protected,
	Haxe provides the `@:protected` metadata for this and this filter adds it where required.

	See https://github.com/HaxeFoundation/haxe/issues/8289
**/
class HandleProtectedOverrides extends AbstractFilter {
	override function processDecl(decl:TDecl) {
		switch decl.kind {
			case TDClassOrInterface({members: members, kind: TClass(info)}):
				for (m in members) {
					switch m {
						case TMField(field):
							processField(field, info);
						case _:
					}
				}

			case _:
		}
	}

	function processField(field:TClassField, info:TClassDeclInfo) {
		var name = switch field.kind {
			case TFFun(f): f.name;
			case _: return; // we only care about methods
		}

		var isProtected = false;
		var isOverride = false;
		for (m in field.modifiers) {
			switch m {
				case FMProtected(_): isProtected = true;
				case FMOverride(_): isOverride = true;
				case _:
			}
		}
		if (isProtected && isOverride && isOriginallyDefinedInExtern(info, name)) {
			field.metadata.push(MetaHaxe(mkIdent("@:protected", [], [whitespace]), null));
		}
	}

	static function isOriginallyDefinedInExtern(info:TClassDeclInfo, name:String):Bool {
		switch info.extend {
			case null:
				return false;
			case {superClass: superClass}:
				var superField = superClass.findField(name, false);
				if (superField != null && superClass.parentModule.isExtern) {
					return true;
				} else {
					info = switch superClass.kind {
						case TClass(info): info;
						case TInterface(_): throw "assert";
					}
					return isOriginallyDefinedInExtern(info, name);
				}
		}
	}
}
