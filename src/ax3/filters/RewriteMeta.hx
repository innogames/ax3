package ax3.filters;

class RewriteMeta extends AbstractFilter {
	var typeAwareInterface:Null<TClassOrInterfaceDecl>;
	var magicBaseClasses:Null<Array<TClassOrInterfaceDecl>>;

	static function getPackName(path:String) {
		var pack = path.split(".");
		var name = pack.pop();
		return {pack: pack.join("."), name: name};
	}

	override function run(tree:TypedTree) {
		if (context.config.injection != null) {
			magicBaseClasses = [];

			var p = getPackName(context.config.injection.magicInterface);
			typeAwareInterface = tree.getInterface(p.pack, p.name);
			magicBaseClasses.push(typeAwareInterface);

			for (p in context.config.injection.magicBaseClasses) {
				var p = getPackName(p);
				magicBaseClasses.push(tree.getClassOrInterface(p.pack, p.name));
			}
		}
		super.run(tree);
	}

	override function processClass(c:TClassOrInterfaceDecl) {
		var classInfo = switch c.kind {
			case TClass(info): info;
			case TInterface(_): return; // don't process interfaces
		};

		var needsTypeAwareInterface = false;
		for (m in c.members) {
			switch m {
				case TMField(field):
					var newMetadata = [];
					for (meta in field.metadata) {
						switch meta {
							case MetaFlash(m):
								switch m.name.text {
									case "Inject":
										needsTypeAwareInterface = true;
										newMetadata.push(haxeMetaFromFlash(m, "@:inject"));
									case "PostConstruct":
										needsTypeAwareInterface = true;
										newMetadata.push(haxeMetaFromFlash(m, "@:postConstruct"));
									case "PreDestroy":
										needsTypeAwareInterface = true;
										newMetadata.push(haxeMetaFromFlash(m, "@:preDestroy"));
									case "Inline":
										newMetadata.push(meta);
									// 	// TODO: Haxe `inline` generation is disabled, because Haxe cannot always
									// 	// statically inline methods and emits `Cannot inline a not final return` error
									// 	// we can still detect this by checking the method body and only generate `inline`
									// 	// when possible, but that will require some work that we can do later :-P

									// 	switch field.kind {
									// 		case TFFun(f): f.isInline = true;
									// 		case TFGetter(f) | TFSetter(f): f.isInline = true;
									// 		case TFVar(_): throwError(m.name.pos, "Inline meta on a var?");
									// 	}
									case other:
										reportError(m.name.pos, "Unknown metadata: " + other);
										newMetadata.push(meta);
								}
							case MetaHaxe(_):
								newMetadata.push(meta);
						}
					}
					field.metadata = newMetadata;
				case _:
			}
		}

		if (needsTypeAwareInterface && typeAwareInterface != null && !extendsMagicBaseClass(c)) {
			final heritage = {
				iface: {
					syntax: mkDeclDotPath(c, typeAwareInterface, []),
					decl: typeAwareInterface
				},
				comma: null
			};

			if (classInfo.implement == null) {
				classInfo.implement = {
					keyword: mkIdent("implements", [whitespace], [whitespace]),
					interfaces: [heritage]
				};
			} else {
				classInfo.implement.interfaces[classInfo.implement.interfaces.length - 1].comma = commaWithSpace;
				classInfo.implement.interfaces.push(heritage);
			}
		}
	}

	function extendsMagicBaseClass(c:TClassOrInterfaceDecl):Bool {
		for (base in magicBaseClasses) {
			if (determineClassCastKind(c, base) == CKUpcast) {
				return true;
			}
		}
		return false;
	}

	inline static function haxeMetaFromFlash(flashMeta:ParseTree.Metadata, metaString:String):TMetadata {
		var trailTrivia;
		if (flashMeta.args != null) {
			trailTrivia = [];
			flashMeta.args.closeParen.trailTrivia = flashMeta.args.closeParen.trailTrivia.concat(flashMeta.closeBracket.trailTrivia);
		} else {
			trailTrivia = flashMeta.closeBracket.trailTrivia;
		}
		return MetaHaxe(mkIdent(metaString, flashMeta.openBracket.leadTrivia, trailTrivia), flashMeta.args);
	}
}
