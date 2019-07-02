package ax3.filters;

class RewriteMeta extends AbstractFilter {
	override function processClassField(field:TClassField) {
		var newMetadata = [];
		for (m in field.metadata) {

			// TODO remove Flash metadata and only retain Haxe one, and handle flash-related stuff
			// in a macro (translate @inject into @:meta(Inject) for SWC swiftsuspenders)
			newMetadata.push(m);

			switch m {
				case MetaFlash(m):
					switch m.name.text {
						case "Inject":
							newMetadata.push(haxeMetaFromFlash(m, "@inject"));
						case "PostConstruct":
							newMetadata.push(haxeMetaFromFlash(m, "@PostConstruct"));
						case "PreDestroy":
							newMetadata.push(haxeMetaFromFlash(m, "@PreDestroy"));
						case "Inline":
							// TODO: Haxe `inline` generation is disabled, because Haxe cannot always
							// statically inline methods and emits `Cannot inline a not final return` error
							// we can still detect this by checking the method body and only generate `inline`
							// when possible, but that will require some work that we can do later :-P

							// switch field.kind {
							// 	case TFFun(f): f.isInline = true;
							// 	case TFGetter(f) | TFSetter(f): f.isInline = true;
							// 	case TFVar(_): throwError(m.name.pos, "Inline meta on a var?");
							// }
						case other:
							reportError(m.name.pos, "Unknown metadata: " + other);
					}
				case MetaHaxe(_):
			}
		}
		field.metadata = newMetadata;
	}

	inline static function haxeMetaFromFlash(flashMeta:ParseTree.Metadata, metaString:String):TMetadata {
		return MetaHaxe(mkIdent(metaString, flashMeta.openBracket.leadTrivia, flashMeta.closeBracket.trailTrivia));
	}
}
