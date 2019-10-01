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

It also uses the `format` library which contains `SWF/ABC` readers, so before building, make sure to install it (`haxelib install format` or `lix install haxelib:format`). Note that you need the version after the commit `88041be7819e1093189e88e50be2d222dddd73a7` (TODO: just use lix and pin the version)

Then, to build the converter binary, just run `haxe build.hxml`.

It uses the Java target (actually, even the new JVM bytecode target), because JVM has
great GC and handles unoptimized functional code of this converter very well.
Originally I used JS target, but node.js worked slower and eventually died on so many allocations. :)

## TODO

Most of the `TODO`s are actually in the code, so look there too, but still:

 - don't parse `*=` as a single token when parsing signatures (fix `a:*=b` parsing without spaces)
 - add a filter to remove redundant parenthesis, because they can become redundant due to expression rewriting (e.g. stripping away `as` upcasts)
 - add a "final-step" filter to remove redundant `TEHaxeRetype`s too
 - rewrite `arr[arr.length] = value` to `arr.push(value)`
 - generate "type patch" files for loaded SWCs, replacing `Object` with `ASObject` and `*` with `ASAny`
 - review and cleanup `ASCompat` - rework some things as static extensions (e.g. Vector/Array compat methods)
 - add some more empty ctors to work around https://github.com/HaxeFoundation/haxe/issues/8531
 - add imports for fully-qualified names that can come from `@haxe-type`
 - remove duplicate imports (can happen when merging in out-of-package imports)
 - add configuration for some things (like omitting type hints and `private` keywords)
