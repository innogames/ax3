package ax3.filters;

class InlineStaticConsts extends AbstractFilter {
	override function processClassField(field:TClassField) {
		switch field.kind {
			case TFVar(v):
				var isConstantLiteral = switch v {
					case {kind: VConst(_), init: {expr: {kind: TELiteral(l)}}} if (!l.match(TLRegExp(_))): true;
					case _: false;
				}

				if (isConstantLiteral) {
					var isStatic = Lambda.exists(field.modifiers, m -> m.match(FMStatic(_)));
					// TODO: deal with leading trivia here
					// TODO: static is disabled because we also need to change field access expressions
					if (!isStatic) {
						field.modifiers.push(FMStatic(new Token(0, TkIdent, "static", [], [whitespace])));
						isStatic = true;
					}
					if (isStatic) {
						v.isInline = true;
					}
				}

			case _:
		}
	}
}

class FixInlineStaticConstAccess extends AbstractFilter {
	override function processExpr(e:TExpr):TExpr {
		e = mapExpr(processExpr, e);
		return switch e.kind {
			case TEField({kind: TOImplicitThis(c)}, fieldName, fieldToken):
				switch c.findFieldInHierarchy(fieldName, true) {
					case {field: {kind: TFVar({isInline: true})}, declaringClass: c}:
						e.with(kind = TEField(
							{kind: TOImplicitClass(c), type: TTStatic(c)},
							fieldName,
							fieldToken
						));
					case _:
						e;
				}
			case _:
				e;
		}
	}
}
