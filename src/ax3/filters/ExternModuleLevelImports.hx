package ax3.filters;

class ExternModuleLevelImports extends AbstractFilter {
	final globals = new Map<String,String>();

	override function processImport(i:TImport) {
		switch i.kind {
			case TIDecl(decl):
				switch (decl.kind) {
					case SClass(_): // ok
					case SNamespace: // ignored
					case SVar(_) | SFun(_): // need to be replaced
						var path = if (i.pack.name == "") decl.name else i.pack.name + "." + decl.name;
						globals[path] = StringTools.replace(path, ".", "_"); // TODO: possible name clashes
				}

			case TIAll(_):
		}
	}

	public function makeGlobalsModule():TModule {
		var members = new Array<TClassMember>();
		for (dotPath => name in globals) {

			var expr = mk(TEBuiltin(mkIdent("__global__"), "__global__"), TTFunction, TTFunction);
			expr = mkCall(expr, [mk(TELiteral(TLString(new Token(0, TkStringDouble, '"$dotPath"', [], []))), TTString, TTString)]);

			members.push(TMField({
				metadata: [],
				modifiers: [],
				namespace: null,
				kind: TFGetter({
					syntax: {
						functionKeyword: mkTokenWithSpaces(TkIdent, "function"),
						accessorKeyword: mkTokenWithSpaces(TkIdent, "get"),
						name: mkTokenWithSpaces(TkIdent, name),
					},
					name: name,
					fun: {
						sig: {
							syntax: {
								openParen: mkOpenParen(),
								closeParen: mkCloseParen()
							},
							args: [],
							ret: {
								type: TTFunction,
								syntax: null
							}
						},
						expr: {
							kind: TEBlock({
								syntax: {
									openBrace: mkOpenBrace(),
									closeBrace: mkCloseBrace()
								},
								exprs: [{expr: expr, semicolon: mkSemicolon()}]
							}),
							type: TTVoid,
							expectedType: TTVoid
						}
					}
				})
			}));
		}
		return {
			path: "",
			pack: {
				syntax: {
					keyword: mkIdent("package"),
					name: null,
					openBrace: mkOpenBrace(),
					closeBrace: mkCloseBrace(),
				},
				imports: [],
				namespaceUses: [],
				name: "",
				decl: TDClass({
					syntax: {
						keyword: mkIdent("class"),
						name: mkTokenWithSpaces(TkIdent, "Globals"),
						extend: null,
						implement: null,
						openBrace: mkOpenBrace(),
						closeBrace: mkCloseBrace()
					},
					metadata: [],
					modifiers: [],
					name: "Globals",
					extend: null,
					implement: null,
					members: members,
				})
			},
			name: "Globals",
			privateDecls: [],
			eof: new Token(0, TkEof, "", [], [])
		}
	}
}
