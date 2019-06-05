package ax3.filters;

class RewriteMeta extends AbstractFilter {
	override function processClassField(field:TClassField) {
		var newMetadata = [];
		for (m in field.metadata) {

			// TODO remove Flash metadata and only retain Haxe one, and handle flash-related stuff
			// in a macro (translate @inject into @:meta(Inject) for SWC swiftsuspenders)
			// to do this though, we gotta handle the trivia, so we're not losing comments and whitespace

			newMetadata.push(m);

			switch m {
				case MetaFlash(m):
					switch m.name.text {
						case "Inject":
							newMetadata.push(MetaHaxe("@inject"));
						case "PostConstruct":
							newMetadata.push(MetaHaxe("@PostConstruct"));
						case "PreDestroy":
							newMetadata.push(MetaHaxe("@PreDestroy"));
						case "Inline":
							switch field.kind {
								case TFFun(f): f.isInline = true;
								case TFGetter(f) | TFSetter(f): f.isInline = true;
								case TFVar(_): throwError(m.name.pos, "Inline meta on a var?");
							}
						case other:
							reportError(m.name.pos, "Unknown metadata: " + other);
					}
				case MetaHaxe(_):
			}
		}
		field.metadata = newMetadata;
	}
}
