package ax3;

import ax3.TypedTree;
import ax3.filters.*;

class Filters {
	public static function run(context:Context, tree:TypedTree) {
		var externImports = new ExternModuleLevelImports(context);
		var coerceToBool = new CoerceToBool(context);
		var detectFieldRedefinitions = new RewriteRedefinedPrivate.DetectFieldRedefinitions(context);

		for (f in [
			detectFieldRedefinitions,
			new RewriteRedefinedPrivate.RenameRedefinedFields(context, detectFieldRedefinitions),
			new RewriteAssignOps(context),
			new WrapModuleLevelDecls(context),
			new HandleVisibilityModifiers(context),
			new RewriteMeta(context),
			new MathApi(context),
			new RewriteJSON(context),
			new UtilFunctions(context),
			externImports,
			new InlineStaticConsts(context),
			new InlineStaticConsts.FixInlineStaticConstAccess(context),
			new RewriteE4X(context),
			new RewriteSwitch(context),
			new RestArgs(context),
			new RewriteRegexLiterals(context),
			new HandleNew(context),
			new RewriteVectorDecl(context),
			new AddSuperCtorCall(context),
			new RewriteBlockBinops(context),
			new RewriteNewArray(context),
			new RewriteTypesWithComment(context),
			new RewriteDelete(context),
			new RewriteArrayAccess(context),
			new RewriteAs(context),
			new RewriteIs(context),
			new RewriteCFor(context),
			new RewriteForIn(context),
			new RewriteHasOwnProperty(context),
			new NumberToInt(context),
			new RewriteCasts(context),
			new HandleBasicValueDictionaryLookups(context),
			coerceToBool,
			new RewriteNonBoolOr(context, coerceToBool),
			new InvertNegatedEquality(context),
			new HaxeProperties(context),
			new UnqualifiedSuperStatics(context),
			new FixNonInlineableDefaultArgs(context),
			// new AddParens(context),
			new AddRequiredParens(context),
			// new CheckExpectedTypes(context)
			new DateApi(context),
			new ArrayApi(context),
			new StringApi(context),
			new NumberApi(context),
			new FunctionApply(context),
			new ToString(context),
			new NamespacedToPublic(context),
			new VarInits(context),
			new UintComparison(context),
			new HandleProtectedOverrides(context),
			new CheckUntypedMethodCalls(context),
			new RemoveRedundantParenthesis(context),
			new FixImports(context)
		]) {
			f.run(tree);
		}

		externImports.addGlobalsModule(tree);
	}
}
