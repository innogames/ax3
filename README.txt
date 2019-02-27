1) parse into parse tree
2) build typed tree structure for all modules
3) resolve types in the typed tree
4) transform to haxe-friendly tree
 - rewrite for
 - rewrite for...in
 - rewrite for..each
 - rewrite implicit to-bool coercion
 - rewrite potentially-undefined-to-basic-type coercion
 - rewrite E4X
5) output Haxe modules
