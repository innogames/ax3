1) parse parsetree into
2) build structure
  a list of modules, each of whose contains:
   - imports
   - main decl
     * class/interface with function signatures
	 * function with its signature
	 * var with type?
   - module-local decls
3) load extern libs with signatures into the structure
4) type the function bodies and var init expressions
5) transform typed tree into a more haxe-friendly one
 - rewrite for
 - rewrite for...in
 - rewrite for..each
 - rewrite implicit to-bool coercion
 - rewrite potentially-undefined-to-basic-type coercion
 - rewrite E4X operators
 - rewrite module-level functions/vars into classes with statics
 - rewrite "untyped" field access to getProperty
6) output Haxe files


TODO:
 - work-around Stage.quality getter bug (add toLowerCase() to the field access)
 - implement class-wrapping for module-level vars/functions
 - handle Null<T> to T conversion in some cases (e.g. for var x:int = dict[inexistant])
 - finish compat abstracts
 - go through TODOs in the code
 - optionally don't generate var type hints if the init expr type is exaclty the same
 - optionally don't generate `private` keywords
 - `escape`, `string.split(regexp)`, `string.concat`, `string.search`
 - generate properties next to first accessor (so they end up within cond.compilation)
 - remove @haxe-type trivia