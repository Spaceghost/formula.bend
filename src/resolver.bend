import Base
import ./core.bend as Core

type Node is Data:
  Entry{name: String, original: Core.Value, children: List<&2, String>}

type Visit is Data:
  Visited{preorder: List<&2, String>, reversed_finish: List<&2, String>, cyclic: Bool}

type Analysis is Data:
  Analyzed{nodes: List<&2, Node>, reachability: List<&2, Node>, components: Core.Value}

type Resolution is Data:
  Ordered{names: Core.Value}
  Cyclic{component: Core.Value}

def contains(names: List<&2, String>, +name: String) -> Bool:
  match names:
    case Nil{}:
      False{}
    case head <> rest:
      Bool.or(String.eq(head, name), contains(rest, name))

def select_names(yes: Bool, a: List<&2, String>, b: List<&2, String>) -> List<&2, String>:
  Bool.pick(List<&2, String>, yes, a, b)

def unique_into(names: List<&2, String>, +seen: List<&2, String>) -> List<&2, String>:
  match names:
    case Nil{}:
      seen
    case +head <> rest:
      unique_into(rest, select_names(contains(seen, head), seen, List.append(&2, String, seen, [head])))

def key_text(value: Core.Value) -> String:
  match value:
    case Core.SymbolValue{text}:
      text
    case Core.TextValue{text}:
      text
    case Core.NullValue{}:
      ""
    case value:
      Core.ruby_render(value, False{}, False{})

def dependency_names(values: Core.Value, +sensitive: Bool) -> List<&2, String>:
  match values:
    case Core.ArrayCons{head, rest}:
      Core.normalize(sensitive, key_text(head)) <> dependency_names(rest, sensitive)
    case values:
      Nil{}

# Hash normalization preserves first insertion order and the last key/value.
def store(nodes: List<&2, Node>, +name: String, +original: Core.Value, +children: List<&2, String>) -> List<&2, Node>:
  match nodes:
    case Nil{}:
      [Entry{name, original, children}]
    case Entry{+old, key, deps} <> +rest:
      Bool.pick(List<&2, Node>, String.eq(old, name), Entry{name, original, children} <> rest, Entry{old, key, deps} <> store(rest, name, original, children))

def prepare(value: Core.Value, nodes: List<&2, Node>, +sensitive: Bool) -> List<&2, Node>:
  match value:
    case Core.HashEntry{+key, deps, rest}:
      prepare(rest, store(nodes, Core.normalize(sensitive, key_text(key)), key, dependency_names(deps, sensitive)), sensitive)
    case value:
      nodes

def children(nodes: List<&2, Node>, +name: String) -> List<&2, String>:
  match nodes:
    case Nil{}:
      Nil{}
    case Entry{key, original, deps} <> rest:
      Bool.pick(List<&2, String>, String.eq(key, name), deps, children(rest, name))

def roots(nodes: List<&2, Node>) -> List<&2, String>:
  match nodes:
    case Nil{}:
      Nil{}
    case Entry{name, original, deps} <> rest:
      name <> roots(rest)

def all_names(nodes: List<&2, Node>, names: List<&2, String>) -> List<&2, String>:
  match nodes:
    case Nil{}:
      names
    case Entry{name, original, deps} <> rest:
      all_names(rest, unique_into(deps, names))

def initial_relation(names: List<&2, String>, +nodes: List<&2, Node>) -> List<&2, Node>:
  match names:
    case Nil{}:
      Nil{}
    case +name <> rest:
      Entry{name, Core.NullValue{}, children(nodes, name)} <> initial_relation(rest, nodes)

# Floyd–Warshall closes the finite graph, including dependencies without keys.
def extend_relation(rows: List<&2, Node>, +via: String, +targets: List<&2, String>) -> List<&2, Node>:
  match rows:
    case Nil{}:
      Nil{}
    case Entry{name, original, +deps} <> rest:
      Entry{name, original, select_names(contains(deps, via), unique_into(targets, deps), deps)} <> extend_relation(rest, via, targets)

def closure(vias: List<&2, String>, +rows: List<&2, Node>) -> List<&2, Node>:
  match vias:
    case Nil{}:
      rows
    case +via <> rest:
      closure(rest, extend_relation(rows, via, children(rows, via)))

def enter(name: String, state: Visit) -> Visit:
  match state:
    case Visited{pre, finish, cyclic}:
      Visited{List.append(&2, String, pre, [name]), finish, cyclic}

def finish(name: String, state: Visit) -> Visit:
  match state:
    case Visited{pre, finished, cyclic}:
      Visited{pre, name <> finished, cyclic}

def seen(state: Visit, name: String) -> Bool:
  match state:
    case Visited{pre, finished, cyclic}:
      contains(pre, name)

def revisit(name: String, state: Visit) -> Visit:
  match state:
    case Visited{pre, +finished, cyclic}:
      Visited{pre, finished, Bool.or(cyclic, Bool.not(contains(finished, name)))}

def visit_choice(done: Bool, yes: Unit -> Visit, no: Unit -> Visit) -> Visit:
  match done:
    case True{}:
      yes(Unit{})
    case False{}:
      no(Unit{})

# A simple DFS path has at most |V| distinct vertices. One further step detects
# a closing edge. The structural depth is
# derived from that exact finite vertex set; there is no configurable cutoff.
# The lexicographic (depth, siblings) recursion also preserves Ruby DFS ordering.
def walk(+depth: Nat, names: List<&2, String>, +nodes: List<&2, Node>, +state: Visit) -> Visit:
  match depth names:
    case 0n names:
      state
    case 1n+p Nil{}:
      state
    case 1n+p +name <> +rest:
      visit_choice(seen(state, name), u => walk(1n+p, rest, nodes, revisit(name, state)), u => walk(1n+p, rest, nodes, finish(name, walk(p, children(nodes, name), nodes, enter(name, state)))))

def same_component(+a: String, +b: String, +relation: List<&2, Node>) -> Bool:
  Bool.or(String.eq(a, b), Bool.and(contains(children(relation, a), b), contains(children(relation, b), a)))

def component_root(preorder: List<&2, String>, +name: String, +relation: List<&2, Node>) -> String:
  match preorder:
    case Nil{}:
      name
    case +head <> rest:
      Bool.pick(String, same_component(head, name, relation), head, component_root(rest, name, relation))

def component_members(preorder: List<&2, String>, +name: String, +relation: List<&2, Node>) -> Core.Value:
  match preorder:
    case Nil{}:
      Core.ArrayNil{}
    case +head <> rest:
      Core.array_keep(Bool.not(same_component(head, name, relation)), Core.TextValue{head}, component_members(rest, name, relation))

# TSort emits SCC members in DFS discovery order, at their first member's exit.
def components(finished: List<&2, String>, +preorder: List<&2, String>, +relation: List<&2, Node>) -> Core.Value:
  match finished:
    case Nil{}:
      Core.ArrayNil{}
    case +name <> rest:
      Core.array_keep(Bool.not(String.eq(name, component_root(preorder, name, relation))), component_members(preorder, name, relation), components(rest, preorder, relation))

def singleton_components(finished: List<&2, String>) -> Core.Value:
  match finished:
    case Nil{}:
      Core.ArrayNil{}
    case name <> rest:
      Core.ArrayCons{Core.ArrayCons{Core.TextValue{name}, Core.ArrayNil{}}, singleton_components(rest)}

# Ordinary dependency DAGs need only the DFS. Compute reachability when a back
# edge exists, to recover the exact ordered strongly connected components.
def analyzed(+nodes: List<&2, Node>, state: Visit) -> Analysis:
  match state:
    case Visited{preorder, finished, False{}}:
      Analyzed{nodes, Nil{}, singleton_components(List.reverse(&2, String, finished))}
    case Visited{preorder, finished, True{}}:
      +names = all_names(nodes, roots(nodes))
      +relation = closure(names, initial_relation(names, nodes))
      Analyzed{nodes, relation, components(List.reverse(&2, String, finished), preorder, relation)}

def analyze(value: Core.Value, sensitive: Bool) -> Analysis:
  +nodes = prepare(value, Nil{}, sensitive)
  +names = all_names(nodes, roots(nodes))
  analyzed(nodes, walk(1n+List.length(&2, String, names), roots(nodes), nodes, Visited{Nil{}, Nil{}, False{}}))

def original_key(nodes: List<&2, Node>, +name: String) -> Core.Value:
  match nodes:
    case Nil{}:
      Core.TextValue{name}
    case Entry{key, original, deps} <> rest:
      Bool.pick(Core.Value, String.eq(key, name), original, original_key(rest, name))

def prepend_order(head: Core.Value, result: Resolution) -> Resolution:
  match result:
    case Ordered{names}:
      Ordered{Core.ArrayCons{head, names}}
    case Cyclic{members}:
      Cyclic{members}

def order_components(groups: Core.Value, +nodes: List<&2, Node>) -> Resolution:
  match groups:
    case Core.ArrayCons{Core.ArrayCons{Core.TextValue{name}, Core.ArrayNil{}}, rest}:
      prepend_order(original_key(nodes, name), order_components(rest, nodes))
    case Core.ArrayCons{group, rest}:
      Cyclic{group}
    case groups:
      Ordered{Core.ArrayNil{}}

def cycle_group(group: Core.Value, relation: List<&2, Node>) -> Bool:
  match group:
    case Core.ArrayCons{Core.TextValue{+name}, Core.ArrayNil{}}:
      contains(children(relation, name), name)
    case Core.ArrayCons{head, tail}:
      True{}
    case group:
      False{}

def cycle_components(groups: Core.Value, +relation: List<&2, Node>) -> Core.Value:
  match groups:
    case Core.ArrayCons{+group, rest}:
      Core.array_keep(Bool.not(cycle_group(group, relation)), group, cycle_components(rest, relation))
    case groups:
      Core.ArrayNil{}

def order_analysis(analysis: Analysis) -> Resolution:
  match analysis:
    case Analyzed{nodes, relation, groups}:
      order_components(groups, nodes)

def find_resolve_order(value: Core.Value, sensitive: Bool) -> Resolution:
  order_analysis(analyze(value, sensitive))

def cycles_analysis(analysis: Analysis) -> Core.Value:
  match analysis:
    case Analyzed{nodes, relation, groups}:
      cycle_components(groups, relation)

def cycles(value: Core.Value, sensitive: Bool) -> Core.Value:
  cycles_analysis(analyze(value, sensitive))

def resolution_snapshot(result: Resolution) -> String:
  match result:
    case Ordered{names}:
      Core.snapshot(names)
    case Cyclic{members}:
      "error:TSort::Cyclic"

def order_snapshot(value: Core.Value, sensitive: Bool) -> String:
  resolution_snapshot(find_resolve_order(value, sensitive))

def cycles_snapshot(value: Core.Value, sensitive: Bool) -> String:
  Core.snapshot(cycles(value, sensitive))
