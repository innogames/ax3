package ax3.filters;

private typedef VarState = {
	var decl:TVarDecl;
	var inited:Bool;
}

// TODO: analyze field inits in the constructor to figure out if they need default value too
// TODO: move var decalrations into the deeper scope where it's actually used
class VarInits extends AbstractFilter {
	final stack:Array<Map<TVar,VarState>>;
	var vars:Map<TVar,VarState>;

	public function new(context) {
		super(context);
		vars = new Map();
		stack = [vars];
	}

	function push() {
		vars = [for (v => s in vars) v => {decl: s.decl, inited: s.inited}];
		stack.push(vars);
	}

	function pop():Map<TVar, VarState> {
		var last = stack.pop();
		vars = stack[stack.length - 1];
		return last;
	}

	function intersect(states:Array<Map<TVar, VarState>>) {
		for (v => state in vars) {
			if (!state.inited) {
				var wasInited = false;
				for (varsState in states) {
					if (varsState[v].inited) {
						wasInited = true;
					} else {
						wasInited = false;
						break;
					}
				}
				if (wasInited) {
					state.inited = true;
				}
			}
		}
	}

	override function processExpr(e:TExpr):TExpr {

		function loop(e:TExpr) {
			switch e.kind {
				case TEVars(_, varDecls):
					// var declarations - remember uninited vars
					for (decl in varDecls) {
						if (decl.init == null) {
							vars[decl.v] = {decl: decl, inited: false};
						} else {
							loop(decl.init.expr);
						}
					}

				case TEBinop({kind: TELocal(_, v)}, OpAssign(_), eright):
					// assignment - if the var was uninited, mark it as inited
					loop(eright);
					var state = vars[v];
					if (state != null) {
						state.inited = true;
					}

				case TELocal(_, v):
					// local var access
					// if it was uninited and still is - add initialization and mark as inited
					var state = vars[v];
					if (state != null && !state.inited) {
						state.decl.init = processVarInit(v.type, true);
						state.inited = true;
					}

				// loops - consider inits in the body scope to be not always executed
				case TEFor(_) | TEForEach(_) | TEForIn(_):
					// we rewrite these anyway, so why bother
					throwError(exprPos(e), "AS3 for loops must be processed before");

				case TEHaxeFor(f):
					loop(f.iter);
					push();
					loop(f.body);
					pop();

				case TEWhile(w):
					loop(w.cond);
					push();
					loop(w.body);
					pop();

				case TECondCompBlock(_, expr):
					// conditional compilation - inits inside it are not always executed
					// just like if without else
					push();
					loop(expr);
					pop();

				// branching (if/switch/try) - collect init flags from all the branches
				// and mark the var inited when all branches agree on that :)
				case TEIf(i):
					loop(i.econd);

					push();
					loop(i.ethen);
					var varsAfterThen = pop();

					if (i.eelse != null) {
						push();
						loop(i.eelse.expr);
						var varsAfterElse = pop();
						intersect([varsAfterThen, varsAfterElse]);
					}

				case TESwitch(s):
					loop(s.subj);
					var caseStates = [];
					for (c in s.cases) {
						push();
						for (e in c.body) {
							loop(e.expr);
						}
						var afterCase = pop();
						caseStates.push(afterCase);
					}
					if (s.def != null) {
						push();
						for (e in s.def.body) {
							loop(e.expr);
						}
						var afterDefault = pop();
						caseStates.push(afterDefault);
						intersect(caseStates);
					}

				case TETry(t):
					var catchStates = [];
					for (c in t.catches) {
						push();
						loop(c.expr);
						var afterCatch = pop();
						catchStates.push(afterCatch);
					}
					push();
					loop(t.expr);
					var afterTry = pop();
					catchStates.push(afterTry);
					intersect(catchStates);

				case TEReturn(_, null) | TEBreak(_) | TEContinue(_):
					// code after these ones is not reachable, so mark all vars as inited as it should be safe
					for (state in vars) state.inited = true;

				case TEReturn(_, e) | TEThrow(_, e):
					// same as above except that we want to check the returned/thrown value first
					loop(e);
					for (state in vars) state.inited = true;

				case _:
					// TODO: maybe there's something to do with the local functions, have to check
					iterExpr(loop, e);
			}
		}
		loop(e);

		return e;
	}

	override function processVarField(v:TVarField) {
		if (v.init == null) {
			v.init = processVarInit(v.type, false);
		}
	}

	static function processVarInit(type:TType, initNull:Bool):TVarInit {
		var expr = getDefaultInitExpr(type, initNull);
		return if (expr == null) null else { equalsToken: equalsToken, expr: expr };
	}

	static final equalsToken = new Token(0, TkEquals, "=", [whitespace], [whitespace]);
	static final eFalse = mk(TELiteral(TLBool(mkIdent("false"))), TTBoolean, TTBoolean);
	static final eZeroInt = mk(TELiteral(TLInt(new Token(0, TkDecimalInteger, "0", [], []))), TTInt, TTInt);
	static final eZeroUint = mk(TELiteral(TLInt(new Token(0, TkDecimalInteger, "0", [], []))), TTUint, TTUint);
	static final eNaN = mkBuiltin("NaN", TTNumber);

	static function getDefaultInitExpr(t:TType, initNull:Bool):TExpr {
		return switch t {
			case TTBoolean: eFalse;
			case TTInt: eZeroInt;
			case TTUint: eZeroUint;
			case TTNumber: eNaN;
			case _: if (initNull) mkNullExpr(t) else null;
		};
	}
}
