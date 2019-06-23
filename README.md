# ax3

This is an AS3 to Haxe converter that tries to be very smart and precise about rewriting code.
To achieve that, it actually resembles the typical compiler a lot, so here's how it works:

 - parse as3 modules into the ParseTree structure, containing all the syntatic information
 - load classes and signatures from the SWC libraries so we have the external type information
 - process ParseTree and build the TypedTree, resolving all imports and type references and assigning type to every piece of code
 - run a sequence of "filters" which analyze and re-write the TypedTree structures to adapt the code for Haxe
 - generate haxe modules from the processed TypedTree

## Usage:

```
java -jar converter.jar config.json
```
where `config.json` is something like:
```json
{
  "src": "<as3 sources>",
  "hxout": "<hx output>",
  "swc": [
    "playerglobal32_0.swc",
    "<other swc libraries>"
  ]
}
```

## TODO

Most of the `TODO`s are actually in the code, so look there too, but still:

 - implement class-wrapping for module-level vars/functions
 - handle Null<T> to T conversion in some cases (e.g. for var x:int = dict[inexistant])
 - unify RewriteForIn and RewriteForEach because they are very similar and there's a lot of duplicate logic
 - patch some types loaded from SWC (e.g. DisplayObject.filters is Array<BitmapFilter>)
