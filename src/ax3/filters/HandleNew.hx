package ax3.filters;

import ax3.TypedTreeTools.getConstructor;

class HandleNew extends AbstractFilter {
	final instantiated = new Map<TClassOrInterfaceDecl,Bool>();

	override function processExpr(e:TExpr):TExpr {
		e = mapExpr(processExpr, e);
		return switch e.kind {
			case TENew(keyword, obj, args):
				switch obj {
					case TNType({type: TTInst(c)}): // just a class instantiation, nothing to rewrite, but mark the class for constructor injection
						instantiated[c] = true;
						e;

					case TNType(_): // other kinds of typed `new` - nothing to do
						e;

					case TNExpr(eclass): // anything else - rewrite to Type.createInstance
						var leadTrivia = keyword.leadTrivia;
						var trailTrivia = removeTrailingTrivia(e);

						var eCreateInstance = mk(TEBuiltin(new Token(0, TkIdent, "Type.createInstance", leadTrivia, []), "Type.createInstance"), TTBuiltin, TTBuiltin);
						var ctorArgs = if (args != null) args.args else [];

						e.with(kind = TECall(eCreateInstance, {
							openParen: mkOpenParen(),
							args: [
								{expr: eclass, comma: commaWithSpace},
								{
									expr: mk(TEArrayDecl({
										syntax: {
											openBracket: mkOpenBracket(),
											closeBracket: mkCloseBracket()
										},
										elements: ctorArgs
									}), tUntypedArray, tUntypedArray),
									comma: null
								}
							],
							closeParen: mkCloseParen(trailTrivia)
						}));
				}
			case _:
				e;
		}
	}

	override function run(tree:TypedTree) {
		super.run(tree);
		processInstatiated();
	}

	function processInstatiated() {
		for (cls in instantiated.keys()) {

			// if there is a parent class that was also instantiated, use it instead
			{
				var c = cls;
				while (c != null) {
					switch c.kind {
						case TClass(info):
							if (info.extend != null) {
								c = info.extend.superClass;
								if (instantiated.exists(c)) {
									cls = c;
								}
							}
							break;

						case TInterface(_): throw "assert";
					}
				}
			}

			// if there's no ctor, we gotta add one
			if (getConstructor(cls) == null) {
				cls.members.push(TMField({
					metadata: [],
					namespace: null,
					modifiers: [FMPublic(new Token(0, TkIdent, "public", [], [whitespace]))],
					kind: TFFun({
						syntax: {
							keyword: new Token(0, TkIdent, "function", [], [whitespace]),
							name: new Token(0, TkIdent, cls.name, [], []),
						},
						name: cls.name,
						fun: {
							sig: {
								syntax: {
									openParen: mkOpenParen(),
									closeParen: mkCloseParen()
								},
								args: [],
								ret: {
									syntax: null,
									type: TTVoid
								}
							},
							expr: mk(TEBlock({
								syntax: {
									openBrace: mkOpenBrace(),
									closeBrace: addTrailingNewline(mkCloseBrace())
								},
								exprs: []
							}), TTVoid, TTVoid)
						},
						type: TTFun([], TTVoid),
						isInline: false,
						semicolon: null
					})
				}));
			}
		}
	}
}
