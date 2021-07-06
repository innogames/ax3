package ax3.filters;

class RewriteIs extends AbstractFilter {
	static final tStdIs = TTFun([TTAny, TTAny], TTBoolean);
	static final tIsFunction = TTFun([TTAny], TTBoolean);

	override function processExpr(e:TExpr):TExpr {
		e = mapExpr(processExpr, e);
		return switch e.kind {
			case TEBinop(a, OpIs(isToken), b):
				switch b.kind {
					case TEBuiltin(_, "Function"):
						final isFunction = mkBuiltin("Reflect.isFunction", tIsFunction, removeLeadingTrivia(e));
						e.with(kind = TECall(isFunction, {
							openParen: mkOpenParen(),
							args: [{expr: a, comma: null}],
							closeParen: mkCloseParen(removeTrailingTrivia(e)),
						}));

					case TEBuiltin(objectToken, "Object"):
						// only `null` is failing the `is object` check, so we can convert this to `!= null`
						var neqToken = new Token(isToken.pos, TkExclamationEquals, "!=", isToken.leadTrivia, isToken.trailTrivia);
						var nullToken = new Token(objectToken.pos, TkIdent, "null", objectToken.leadTrivia, objectToken.trailTrivia);
						var nullExpr = mk(TELiteral(TLNull(nullToken)), TTAny, TTAny);
						e.with(kind = TEBinop(a, OpNotEquals(neqToken), nullExpr));

					case TEVector(_, elemType):
						var eIsVectorMethod = mkBuiltin("ASCompat.isVector", TTFunction, removeLeadingTrivia(e));
						e.with(kind = TECall(eIsVectorMethod, {
							openParen: mkOpenParen(),
							args: [
								{expr: a, comma: commaWithSpace},
								{expr: RewriteAs.mkVectorTypeCheckMacroArg(elemType), comma: null}
							],
							closeParen: mkCloseParen(removeTrailingTrivia(e))
						}));

					case _:
						final stdIs = mkBuiltin("Std.isOfType", tStdIs, removeLeadingTrivia(e));
						switch b.kind {
							case TEDeclRef(_, {name: 'ByteArray'}):
								b.kind = TEDeclRef(
									{rest: [], first: mkIdent('ByteArrayData')},
									{
										kind: TDClassOrInterface({
											syntax: null,
											kind: null,
											metadata: [],
											modifiers: [],
											parentModule: {
												isExtern: false,
												path: 'flash.utils.ByteArray',
												parentPack: new TPackage('flash.utils'),
												pack: null,
												name: 'flash.utils.ByteArray',
												privateDecls: [],
												eof: null
											},
											name: 'ByteArrayData',
											members: []
										}),
										name: 'ByteArrayData'
									}
								);
							case _:
						}
						e.with(kind = TECall(stdIs, {
							openParen: mkOpenParen(),
							args: [
								{expr: a, comma: commaWithSpace},
								{expr: b, comma: null},
							],
							closeParen: mkCloseParen(removeTrailingTrivia(e)),
						}));
				}
			case _:
				e;
		}
	}
}
