package ax3;

import ax3.TypedTree;
import ax3.HaxeTypeAnnotation;
import ax3.TypedTreeTools.tUntypedObject;

class HaxeTypeResolver {
	final throwError:(message:String, pos:Int)->Dynamic;
	final resolveDotPath:(dotPath:String)->TDecl;

	public function new(resolveDotPath, throwError) {
		this.resolveDotPath = resolveDotPath;
		this.throwError = throwError;
	}

	public function resolveTypeHint(a:Null<HaxeTypeAnnotation>, p:Int):Null<TType> {
		if (a == null) return null;
		var hint = try a.parseTypeHint() catch (e:Any) throwError(Std.string(e), p);
		return resolveHaxeType(hint, p);
	}

	public function resolveSignature(a:Null<HaxeTypeAnnotation>, p:Int):Null<{args:Map<String,TType>, ret:Null<TType>}> {
		if (a == null) return null;
		var sig = try a.parseSignature() catch (e:Any) throwError(Std.string(e), p);
		return {
			args: [for (name => type in sig.args) name => resolveHaxeType(type, p)],
			ret: if (sig.ret == null) null else resolveHaxeType(sig.ret, p)
		};
	}

	function resolveHaxeType(t:HaxeType, pos:Int):TType {
		inline function resolveDotPath(p) return try this.resolveDotPath(p) catch (e:Any) throwError(Std.string(e), pos);

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
			case HTPath("Object" | "flash.utils.Object", []): tUntypedObject;
			case HTPath("Vector" | "flash.Vector" | "openfl.Vector", [t]): TTVector(resolveHaxeType(t, pos));
			case HTPath("GenericDictionary", [k, v]): TTDictionary(resolveHaxeType(k, pos), resolveHaxeType(v, pos));
			case HTPath("Class", [HTPath("Dynamic", [])]): TTClass;
			case HTPath("Class", [HTPath(path, [])]): TypedTree.declToStatic(resolveDotPath(path));
			case HTPath("Null", [t]): resolveHaxeType(t, pos); // TODO: keep nullability?
			case HTPath("Function" | "flash.utils.Function" | "haxe.Constraints.Function", []): TTFunction;
			case HTPath(path, []): TypedTree.declToInst(resolveDotPath(path));
			case HTPath(path, _): throwError("Unsupported parametrized type: " + path, pos);
			case HTFun(args, ret): TTFun([for (a in args) resolveHaxeType(a, pos)], resolveHaxeType(ret, pos));
		};
	}
}
