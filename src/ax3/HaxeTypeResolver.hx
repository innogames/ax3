package ax3;

import ax3.HaxeTypeAnnotation;
import ax3.TypedTree;
import ax3.TypedTreeTools.tUntypedObject;

typedef DotPathResolver = (dotPath:String) -> TDecl;

typedef ErrorReporter = {
	/** report error and continue **/
	function error(message:String, pos:Int):Void;
	/** report fatal error and halt the conversion **/
	function fatal(message:String, pos:Int):Dynamic; // the return type is Dynamic so we can use it as a value, but this function never returns, so it's really a bottom type
}

class HaxeTypeResolver {
	final errorReporter:ErrorReporter;
	final resolveDotPath:DotPathResolver;

	public function new(errorReporter, resolveDotPath) {
		this.errorReporter = errorReporter;
		this.resolveDotPath = resolveDotPath;
	}

	public function resolveHaxeTypeHint(a:Null<HaxeTypeAnnotation>, p:Int):Null<TType> {
		if (a == null) return null;
		var hint = try a.parseTypeHint() catch (e:Any) errorReporter.fatal(Std.string(e), p);
		return resolveHaxeType(hint, p);
	}

	public function resolveHaxeSignature(a:Null<HaxeTypeAnnotation>, p:Int):Null<{args:Map<String,TType>, ret:Null<TType>}> {
		if (a == null) {
			return null;
		}
		var sig = try a.parseSignature() catch (e:Any) errorReporter.fatal(Std.string(e), p);
		return {
			args: [for (name => type in sig.args) name => resolveHaxeType(type, p)],
			ret: if (sig.ret == null) null else resolveHaxeType(sig.ret, p)
		};
	}

	function resolveHaxeType(t:HaxeType, pos:Int):TType {
		return switch t {
			case HTPath("Array", [elemT]): TTArray(resolveHaxeType(elemT, pos));
			case HTPath("Int", []): TTInt;
			case HTPath("UInt", []): TTUint;
			case HTPath("Float", []): TTNumber;
			case HTPath("Bool", []): TTBoolean;
			case HTPath("String", []): TTString;
			case HTPath("Dynamic", []): TTAny;
			case HTPath("Void", []): TTVoid;
			case HTPath("FastXML", []): TTXMLList;
			case HTPath("RegExp", []): TTRegExp;
			case HTPath("haxe.DynamicAccess", [elemT]): TTObject(resolveHaxeType(elemT, pos));
			case HTPath("flash.utils.Object", []): tUntypedObject;
			case HTPath("Vector" | "flash.Vector" | "openfl.Vector", [t]): TTVector(resolveHaxeType(t, pos));
			case HTPath("GenericDictionary", [k, v]): TTDictionary(resolveHaxeType(k, pos), resolveHaxeType(v, pos));

			// TODO: hacks begin
			case HTPath("StateDescription" | "TransitionDescription", []): TTObject(TTAny);
			case HTPath("Class", [HTPath("org.robotlegs.core.ICommand", [])]): TTClass;
			case HTPath("GenericPool", [_]): resolveHaxeType(HTPath("GenericPool", []), pos);
			// hacks end

			case HTPath("Class", [HTPath("Dynamic", [])]): TTClass;
			case HTPath("Class", [HTPath(path, [])]): TypedTree.declToStatic(resolveDotPath(path));
			case HTPath("Null", [t]): resolveHaxeType(t, pos); // TODO: keep nullability?
			case HTPath("Function" | "haxe.Constraints.Function", []): TTFunction;
			case HTPath(path, []): TypedTree.declToInst(resolveDotPath(path));
			case HTPath(path, _): trace("TODO: " + path); TTAny;
			case HTFun(args, ret): TTFun([for (a in args) resolveHaxeType(a, pos)], resolveHaxeType(ret, pos));
		};
	}
}
