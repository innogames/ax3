package ax3.filters;

class InlineStaticConsts extends AbstractFilter {
	override function processClassField(field:TClassField) {
		switch field.kind {
			case TFVar(v):
				@:nullSafety(Off)
				var isConstantLiteral = switch v {
					case {kind: VConst(_), vars: [{init: {expr: {kind: TELiteral(_)}}}]}: true;
					case _: false;
				}

				if (isConstantLiteral) {
					var isStatic = Lambda.exists(field.modifiers, m -> m.match(FMStatic(_)));
					// TODO: deal with leading trivia here
					// TODO: static is disabled because we also need to change field access expressions
					// if (!isStatic) {
					// 	field.modifiers.push(FMStatic(new Token(0, TkIdent, "static", [], [whitespace])));
					// 	isStatic = true;
					// }
					if (isStatic) {
						v.isInline = true;
					}
				}

			case _:
		}
	}
}
