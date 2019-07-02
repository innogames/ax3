#if macro
import haxe.macro.Context;
import haxe.macro.Expr;

// This macro is applied on Flash target to transform @:inject/@:postConstruct/@:preDestroy metadata
// into Flash-specific metadata that is picked up by the native SwiftSuspenders library, so for example
// `@:inject` becomes `@:meta(Inject())` which is equivalent to `[Inject]` in AS3 code
//
// We can get rid of this macro once we're using pure-Haxe SwiftSuspenders (and Robotlegs?) on both targets.
class TypeDescriptionAwareFlashMacro {
	static function build():Array<Field> {
		if (Context.defined("display")) // don't do anything in display-mode (completion, etc.)
			return null;

		var fields = Context.getBuildFields();
		for (field in fields) {
			var newMeta = [];
			for (i in 0...field.meta.length) { // iterating over length because we want to push more meta and not iterate over that :D
				var meta = field.meta[i];
				switch meta.name {
					case ":inject":
						field.meta.push(mkFlashMeta(meta, "Inject"));
					case ":postConstruct":
						field.meta.push(mkFlashMeta(meta, "PostConstruct"));
					case ":preDestroy":
						field.meta.push(mkFlashMeta(meta, "PreDestroy"));
				}
			}
		}
		return fields;
	}

	static function mkFlashMeta(originalMeta:MetadataEntry, flashMetaName:String):MetadataEntry {
		var ident = {pos: originalMeta.pos, expr: EConst(CIdent(flashMetaName))};
		var call = {pos: originalMeta.pos, expr: ECall(ident, originalMeta.params)};
		return {
			pos: originalMeta.pos,
			name: ":meta",
			params: [call]
		};
	}
}
#end
