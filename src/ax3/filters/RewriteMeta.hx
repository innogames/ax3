package ax3.filters;

class RewriteMeta extends AbstractFilter {
	var typeAwareInterface:Null<TClassOrInterfaceDecl>;
	var magicBaseClasses:Null<Array<TClassOrInterfaceDecl>>;
	var processedClasses:Null<Map<TClassOrInterfaceDecl,Bool>>;

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
		processedClasses = new Map();
		super.run(tree);
		processedClasses = null;
	}

	override function processClass(c:TClassOrInterfaceDecl) {
		if (processedClasses.exists(c)) {
			return;
		}

		processedClasses[c] = true;

		var classInfo = switch c.kind {
			case TClass(info): info;
			case TInterface(_): return; // don't process interfaces
		};

		if (classInfo.extend != null && !classInfo.extend.superClass.parentModule.isExtern) {
			processClass(classInfo.extend.superClass);
		}

		var rmList: Array<Int> = [];
		var needsTypeAwareInterface = false;
		var i: Int = 0;
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
									case "Inspectable":
										needsTypeAwareInterface = true;
										newMetadata.push(haxeMetaFromFlash(m, "@:inspectable"));
									case "Bindable":
										needsTypeAwareInterface = true;
										newMetadata.push(haxeMetaFromFlash(m, "@:bindable"));
									case "Event":
										needsTypeAwareInterface = true;
										newMetadata.push(haxeMetaFromFlash(m, "@:event"));
									case "HxOverride":
										needsTypeAwareInterface = true;
										field.modifiers.push(FMOverride(
											new Token(0, TokenKind.TkIdent, '', [], [new Trivia(TrWhitespace, ' ')])
										));
									case "HxCancelOverride":
										needsTypeAwareInterface = true;
										field.modifiers = field.modifiers.filter(m -> !m.match(FMOverride(_)));
									case "HxRemove":
										needsTypeAwareInterface = true;
										rmList.push(i);
									case "HxArrayArgType":
										switch [field.kind, m.args.args.first, m.args.args.rest[0].element] {
											case [TFFun(f), ELiteral(LString(_name)), ELiteral(LString(_type))]:
												needsTypeAwareInterface = true;
												final name: String = rmQuotesAndConvert(_name.text);
												final type: String = rmQuotesAndConvert(_type.text);
												for (arg in f.fun.sig.args) if (arg.name == name) arg.type = TTArray(TTInst({
													name: type,
													syntax: null,
													parentModule: null,
													modifiers: [],
													metadata: [],
													members: [],
													kind: null
												}));
											case _:
										}
									case 'ArrayElementType':
										switch [field.kind, m.args.args.first] {
											case [TFVar(v), ELiteral(LString(t))]:
												v.type = TTArray(TTInst({
													name: rmQuotesAndConvert(t.text),
													syntax: null,
													parentModule: null,
													modifiers: [],
													metadata: [],
													members: [],
													kind: null
												}));
											case [TFSetter(f), ELiteral(LString(t))]:
												f.fun.sig.args[0].type = TTArray(TTInst({
													name: rmQuotesAndConvert(t.text),
													syntax: null,
													parentModule: null,
													modifiers: [],
													metadata: [],
													members: [],
													kind: null
												}));
											case [TFGetter(f), ELiteral(LString(t))]:
												f.fun.sig.ret.type = TTArray(TTInst({
													name: rmQuotesAndConvert(t.text),
													syntax: null,
													parentModule: null,
													modifiers: [],
													metadata: [],
													members: [],
													kind: null
												}));
											case [TFFun(f), ELiteral(LString(t))]:
												if (f.fun.sig.ret.type.match(TTArray(_)))
													f.fun.sig.ret.type = TTArray(TTInst({
														name: rmQuotesAndConvert(t.text),
														syntax: null,
														parentModule: null,
														modifiers: [],
														metadata: [],
														members: [],
														kind: null
													}));
											case _:
												reportError(m.name.pos, "Metadata error: ArrayElementType");
										}
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
									case "Embed":
										var map: Map<String, String> = [for (a in m.args.args.rest.map(function(f) return f.element).concat([m.args.args.first])) {
											var kv: {k: String, v: String} = switch a {
												case EBinop(EIdent(n), OpAssign(_), ELiteral(LString(v))):
													{ k: n.text, v: StringTools.trim(v.text.substr(1, v.text.length - 2)) };
												case _:
													reportError(m.name.pos, "Unknown embed metadata format"); null;
											}
											if (kv != null) kv.k => kv.v;
										}];
										switch map['mimeType'] {
											case "application/x-font", "application/x-font-truetype":
												newMetadata.push(MetaHaxe(
													mkIdent('@:font', m.openBracket.leadTrivia, []),
													{
														openParen: mkOpenParen(),
														args: {
															first: ELiteral(LString(mkString(map['source']))),
															rest: []
														},
														closeParen: mkCloseParen()
													}
												));
											case "application/octet-stream":
												newMetadata.push(MetaHaxe(
													mkIdent('@:file', m.openBracket.leadTrivia, []),
													{
														openParen: mkOpenParen(),
														args: {
															first: ELiteral(LString(mkString(map['source']))),
															rest: []
														},
														closeParen: mkCloseParen()
													}
												));
											case null:
												newMetadata.push(MetaHaxe(
													mkIdent('@:bitmap', m.openBracket.leadTrivia, []),
													{
														openParen: mkOpenParen(),
														args: {
															first: ELiteral(LString(mkString(map['source']))),
															rest: []
														},
														closeParen: mkCloseParen()
													}
												));
											case t:
												reportError(m.name.pos, "Unknown mimeType: " + t);
										}
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
			i++;
		}

		c.members = [for (i in 0...c.members.length) if (rmList.indexOf(i) == -1) c.members[i]];

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

	inline static function rmQuotesAndConvert(s: String): String return convertAS3TypeToHaxeType(s.substr(1, s.length - 2));

	static function convertAS3TypeToHaxeType(s: String): String {
		return switch s {
			case "Number": "Float";
			case "int": "Int";
			case "uint": "UInt";
			case "Boolean": "Bool";
			case "Array": "Array<ASAny>";
			case v: v;
		};
	}
}
