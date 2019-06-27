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

## Building

The converter is written in Haxe, using latest Haxe 4 features, so you need Haxe 4 :)
It also uses the `format` library which contains `SWF/ABC` readers, so before building, make sure to install it (`haxelib install format` or `lix install haxelib:format`).

Then, to build the converter binary, just run `haxe build.hxml`.

It uses the Java target (actually, even the new JVM bytecode target), because JVM has
great GC and handles unoptimized functional code of this converter very well.
Originally I used JS target, but node.js worked slower and eventually died on so many allocations. :)

## TODO

Most of the `TODO`s are actually in the code, so look there too, but still:

 - implement class-wrapping for module-level vars/functions
 - patch some types loaded from SWC (e.g. `DisplayObject.filters` is `Array<BitmapFilter>`)
 - don't parse `*=` as a single token when parsing signatures (fix `a:*=b` parsing without spaces)
 - add a filter to remove redundant parenthesis, because they can become redundant due to expression rewriting (e.g. stripping away `as` upcasts)
 - rewrite `expr is Vector<T>` to something that works on Flash (see pokemon catch in `RewriteAs`), because we can't just do `Std.is(expr, Vector)`
