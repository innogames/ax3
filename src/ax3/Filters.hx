package ax3;

import ax3.TypedTree;
import ax3.Structure;
import ax3.filters.*;

class Filters {
	public static function run(context:Context, structure:Structure, modules:Array<TModule>) {
		// var externImports = new ExternModuleLevelImports(context);
		for (f in [
			// externImports,
			new RestArgs(context),
			new RewriteArrayAccess(context),
			new RewriteIs(context),
			new RewriteCFor(context),
			new RewriteForIn(context),
			new RewriteDelete(context),
			new CoerceToBool(context),
			new InvertNegatedEquality(context),
			// new AddParens(context),
			new AddRequiredParens(context),
			// new CheckExpectedTypes(context)
		]) {
			f.run(modules);
		}

		// modules.push(externImports.makeGlobalsModule());
	}
}
