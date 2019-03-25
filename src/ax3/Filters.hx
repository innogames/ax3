package ax3;

import ax3.TypedTree;
import ax3.Structure;
import ax3.filters.*;

class Filters {
	public static function run(context:Context, structure:Structure, modules:Array<TModule>) {
		var externImports = new ExternModuleLevelImports(context);
		for (f in [
			externImports,
			new InlineStaticConsts(context),
			new RewriteE4X(context),
			new RewriteArraySplice(context),
			new RewriteArraySetLength(context),
			new RestArgs(context),
			new RewriteRegexLiterals(context),
			new HandleNew(context),
			new RewriteArrayAccess(context),
			new RewriteIs(context),
			new RewriteCFor(context),
			new RewriteForEach(context),
			new RewriteForIn(context),
			new RewriteDelete(context),
			new CoerceToBool(context),
			new NumberToInt(context),
			new InvertNegatedEquality(context),
			new HaxeProperties(context),
			// new AddParens(context),
			new AddRequiredParens(context),
			// new CheckExpectedTypes(context)
		]) {
			f.run(modules);
		}

		sys.io.File.saveContent("OUT/Globals.hx", externImports.printGlobalsClass());
	}
}
