package ax3.filters;

// add `public` to all fields that are namespaced
class NamespacedToPublic extends AbstractFilter {
	override function processClassField(field:TClassField) {
		if (field.namespace != null && !Lambda.exists(field.modifiers, m -> m.match(FMPublic(_)))) {
			field.modifiers.push(FMPublic(new Token(0, TkIdent, "public", [], [whitespace])));
		}
	}
}
