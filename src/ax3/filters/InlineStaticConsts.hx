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
	var thisClass:Null<TClassOrInterfaceDecl>;
	override function processClass(c:TClassOrInterfaceDecl) {
		thisClass = c;
		super.processClass(c);
		thisClass = null;
	}

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

			case TEField({kind: TOExplicit(dot, expr), type: TTInst(c)}, fieldName, fieldToken):
				switch c.findFieldInHierarchy(fieldName, true) {
					case {field: {kind: TFVar({isInline: true})}, declaringClass: c}:
						if (!canBeRepeated(expr)) { // TODO: this is not really about repeating, but side-effects, so we can omit the expr without changing behaviour
							throwError(dot.pos, "Const field that was made static is accessed through an instance expression that cannot be safely rewritten into a class reference");
						}
						expr = UnqualifiedSuperStatics.mkDeclRef(thisClass, c, removeLeadingTrivia(expr));
						e.with(kind = TEField(
							{kind: TOExplicit(dot, expr), type: expr.type},
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
