package ax3.filters;

import haxe.ds.Option;

class HandleVisibilityModifiers extends AbstractFilter {
	override function processClass(c:TClassOrInterfaceDecl) {
		if (c.kind.match(TClass(_))) {
			for (m in c.members) {
				switch m {
					case TMField(field):
						processFieldModifiers(c, field);
					case _:
				}
			}
		}
	}

	function processFieldModifiers(cls:TClassOrInterfaceDecl, field:TClassField) {
		if (field.namespace != null) {
			// if it's namespaced, make it public and remove the namespace
			// TODO: generate @:access on `use namespace` instead
			var namespaceComment = new Trivia(TrBlockComment, '/*${field.namespace.text}*/');
			var leadTrivia = field.namespace.leadTrivia.concat([namespaceComment]).concat(field.namespace.trailTrivia);
			field.modifiers.unshift(FMPublic(mkIdent("public", leadTrivia, [whitespace])));
			field.namespace = null;
			return;
		}

		var isInternal = Some(null);
		for (i in 0...field.modifiers.length) {
			switch field.modifiers[i] {
				case FMPublic(_) | FMPrivate(_) | FMProtected(_):
					isInternal = None;
					break;
				case FMInternal(t):
					field.modifiers.splice(i, 1);
					isInternal = Some(t);
					break;
				case _:
			}
		}

		var packagePath = cls.parentModule.parentPack.name;

		function changeInternal(leadTrivia, trailTrivia) {
			if (packagePath == "") {
				// just make it `public`
				field.modifiers.unshift(FMPublic(mkIdent("public", leadTrivia, trailTrivia)));
			} else {
				field.metadata.push(MetaHaxe(mkIdent('@:allow($packagePath)', leadTrivia, trailTrivia)));
			}
		}

		switch isInternal {
			case Some(null): // implicitly `internal`
				changeInternal([], [whitespace]);
			case Some(token):
				changeInternal(token.leadTrivia, token.trailTrivia);
			case None:
		}
	}
}
