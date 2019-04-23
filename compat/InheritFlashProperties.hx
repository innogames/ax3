#if macro
import haxe.macro.Expr;
import haxe.macro.Context;
import haxe.macro.Type;
using haxe.macro.Tools;

class InheritFlashProperties {
	static function build() {
		if (!Context.defined("flash")) return null;

		var properties = new Map();
		function loop(cl:ClassType) {
			for (iface in cl.interfaces) {
				var iface = iface.t.get();

				loop(iface); // loop over inherited interfaces

				if (!iface.isExtern) {
					continue;
				}

				for (f in iface.fields.get()) {
					switch f.kind {
						case FVar(readAcc, writeAcc):
							properties[f.name] = {
								get: readAcc == AccNormal,
								set: writeAcc == AccNormal,
							};
						case FMethod(_):
					}
				}
			}
		}
		loop(Context.getLocalClass().get());

		var fields = Context.getBuildFields();
		var addedFields = new Array<Field>();
		for (field in fields) {
			var propInfo = properties[field.name];
			if (propInfo == null) continue;

			switch field.kind {
				case FProp(get, set, type, expr):
					if (get == "get") {
						if (!propInfo.get) throw new Error("something is wrong here", field.pos);
						get = "default";

						var getterName = "get_" + field.name;
						addedFields.push({
							pos: field.pos,
							name: "___get_" + field.name,
							meta: [{pos: field.pos, name: ":getter", params: [macro $i{field.name}]}],
							kind: FFun({
								args: [],
								ret: type,
								expr: macro return this.$getterName()
							})
						});
					}
					if (set == "set") {
						if (!propInfo.set) throw new Error("something is wrong here", field.pos);
						set = "default";

						var setterName = "set_" + field.name;
						addedFields.push({
							pos: field.pos,
							name: "___set_" + field.name,
							meta: [{pos: field.pos, name: ":setter", params: [macro $i{field.name}]}],
							kind: FFun({
								args: [{name: "value", type: type}],
								ret: macro : Void,
								expr: macro this.$setterName(value)
							})
						});
					}
					field.kind = FProp(get, set, type, expr);
					field.meta.push({pos: field.pos, name: ":native", params: [macro $v{"___stub_" + field.name}]});

				case _:
					throw new Error("Expected a property", field.pos);
			}
		}

		return fields.concat(addedFields);
	}
}
#end
