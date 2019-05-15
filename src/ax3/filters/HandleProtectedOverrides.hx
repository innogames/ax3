package ax3.filters;

/**
	There's no `protected` in Haxe (private is protected actually),
	but when overriding protected methods from an SWC, in order to generate
	the correct code, the overriden method must actually be generated as protected,
	Haxe provides the `@:protected` metadata for this and this filter adds it where required.

	See https://github.com/HaxeFoundation/haxe/issues/8289
**/
class HandleProtectedOverrides extends AbstractFilter {
	override function processClassField(field:TClassField) {
		var isProtected = false;
		var isOverride = false;
		for (m in field.modifiers) {
			switch m {
				case FMProtected(_): isProtected = true;
				case FMOverride(_): isOverride = true;
				case _:
			}
		}
		if (isProtected && isOverride) {
			field.metadata.push(MetaHaxe("@:protected"));
		}
	}
}
