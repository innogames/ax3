# ax3

This is an AS3 to Haxe converter that tries to be very smart and precise about rewriting code.
To achieve that, it actually resembles the typical compiler a lot, so here's how it works:

 - parse as3 modules into the ParseTree structure, containing all the syntatic information
 - load classes and signatures from the SWC libraries so we have the external type information
 - process ParseTree and build the TypedTree, resolving all imports and type references and assigning type to every piece of code
 - run a sequence of "filters" which analyze and re-write the TypedTree structures to adapt the code for Haxe
 - generate haxe modules from the processed TypedTree

## DISCLAIMER

This tool was developed and used by [InnoGames](https://www.innogames.com/) to migrate our ActionScript 3 codebases. Feel free to ask questions,
fork and contribute fixes. However, we are NOT planning to maintain and provide official support for this project.

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

## Known limitations

 - The parser doesn't currently support ASI (automatic semicolon insertion). The only case where a semicolon can be omitted is the last expression of a block.
 - Only a small, most commonly used subset of E4X is supported. It's recommended to rewrite the unsupported things in AS3 sources to adapt it for conversion.

## Building

The converter is written in Haxe 4 and is only one library, `format`, for reading the SWC files.
To make it easy there's a [Lix](https://github.com/lix-pm/lix.client) scope configured, so assuming you have nodejs installed, you can do:

 * `npm i lix`
 * `npx lix download`
 * `npx haxe build.hxml`

It uses the Java target (actually, even the new JVM bytecode target), because JVM has great GC and handles unoptimized functional code of this converter very well. Originally I used JS target, but node.js worked slower and eventually died on so many allocations. :)

## TODO

Most of the `TODO`s are actually in the code, so look there too, but still:

 - don't parse `*=` as a single token when parsing signatures (fix `a:*=b` parsing without spaces)
 - add a "final-step" filter to remove redundant `TEHaxeRetype`s too
 - rewrite `arr[arr.length] = value` to `arr.push(value)`
 - generate "type patch" files for loaded SWCs, replacing `Object` with `ASObject` and `*` with `ASAny`
 - review and cleanup `ASCompat` - rework some things as static extensions (e.g. Vector/Array compat methods)
 - add some more empty ctors to work around https://github.com/HaxeFoundation/haxe/issues/8531
 - add configuration options for some things (like omitting type hints and `private` keywords)
 - fix imports
  - add imports for fully-qualified names that can come from `@haxe-type`
  - remove duplicate imports (can happen when merging in out-of-package imports)
 - maybe add `inline` for arithmetic ops in static var inits where all operands are also static inline
 - remove `public` from `@:inject`/`@:postConstruct`/`@:preDestroy` as these should not really be part of public API
