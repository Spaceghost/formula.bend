BEND ?= bend
LUA ?= lua
BUN ?= bun

.PHONY: parity-check check native-check rounding-check division-check address-check enumeration-check unicode-check unicode-boundary-check wire-check
check:
	$(BEND) PROOF.bend
	$(BEND) tests.bend
	mkdir -p build
	$(BEND) runtime.bend > build/runtime-js.actual
	diff -u runtime.expected build/runtime-js.actual
	$(MAKE) rounding-check
	$(MAKE) division-check
	$(MAKE) address-check
	$(MAKE) enumeration-check
	$(MAKE) unicode-check
	$(MAKE) parity-check

unicode-check:
	mkdir -p build
	$(LUA) tools/generate-unicode.lua compat/unicode-ranges.tsv build/unicode-generated.bend
	diff -u src/unicode.bend build/unicode-generated.bend

unicode-boundary-check:
	mkdir -p build
	$(LUA) tools/generate-unicode-check.lua compat/unicode-ranges.tsv build/unicode.input build/unicode.expected
	$(BEND) compat/unicode-runtime.bend -o build/unicode-runtime.js
	$(BUN) build/unicode-runtime.js build/unicode.input > build/unicode.actual
	diff -u build/unicode.expected build/unicode.actual

enumeration-check:
	mkdir -p build
	$(LUA) tools/generate-corpus.lua compat/enumeration-scale-cases.lua build/enumeration-scale --metadata-only
	diff -u enumeration-runtime.expected build/enumeration-scale.expected
	$(BEND) enumeration-runtime.bend > build/enumeration-scale.actual
	diff -u enumeration-runtime.expected build/enumeration-scale.actual

rounding-check:
	mkdir -p build
	$(BEND) rounding-runtime.bend > build/rounding-js.actual
	diff -u rounding-runtime.expected build/rounding-js.actual

division-check:
	mkdir -p build
	$(BEND) division-runtime.bend > build/division-js.actual
	diff -u division-runtime.expected build/division-js.actual

address-check:
	mkdir -p build
	$(BEND) address-runtime.bend > build/address-js.actual
	diff -u address-runtime.expected build/address-js.actual

parity-check:
	mkdir -p build
	$(LUA) tools/generate-corpus.lua compat/scalar-cases.lua build/scalar-corpus
	$(LUA) tools/check-scenario-map.lua
	diff -u compat/scalar-oracle.tsv build/scalar-corpus.expected
	$(LUA) tools/run-corpus.lua compat/scalar-cases.lua build/scalar-corpus $(BEND)
	diff -u compat/scalar-oracle.tsv build/scalar-corpus.actual

wire-check:
	mkdir -p build/wire-check
	$(LUA) tools/generate-wire.lua compat/scalar-cases.lua build/corpus.input
	$(LUA) tools/generate-wire.lua compat/enumeration-scale-cases.lua build/scale.input
	$(BEND) compat/corpus-runtime.bend -o build/corpus-runtime.js
	$(BUN) build/corpus-runtime.js build/corpus.input > build/corpus-runtime-js.actual
	diff -u compat/scalar-oracle.tsv build/corpus-runtime-js.actual
	$(BUN) build/corpus-runtime.js build/scale.input > build/corpus-runtime-scale-js.actual
	diff -u enumeration-runtime.expected build/corpus-runtime-scale-js.actual
	$(LUA) tools/check-wire.lua $(BUN) build/corpus-runtime.js build/wire-check

native-check:
	mkdir -p build
	$(BEND) runtime.bend -o build/runtime
	./build/runtime > build/runtime-native.actual
	diff -u runtime.expected build/runtime-native.actual
	$(BEND) rounding-runtime.bend -o build/rounding-runtime
	./build/rounding-runtime > build/rounding-native.actual
	diff -u rounding-runtime.expected build/rounding-native.actual
	$(BEND) division-runtime.bend -o build/division-runtime
	./build/division-runtime > build/division-native.actual
	diff -u division-runtime.expected build/division-native.actual
	$(BEND) address-runtime.bend -o build/address-runtime
	./build/address-runtime > build/address-native.actual
	diff -u address-runtime.expected build/address-native.actual
	$(LUA) tools/generate-corpus.lua compat/scalar-cases.lua build/scalar-corpus
	$(BEND) build/scalar-corpus.bend -o build/scalar-corpus
	./build/scalar-corpus > build/scalar-corpus-native.actual
	diff -u compat/scalar-oracle.tsv build/scalar-corpus-native.actual
	$(BEND) enumeration-runtime.bend -o build/enumeration-runtime
	./build/enumeration-runtime > build/enumeration-native.actual
	diff -u enumeration-runtime.expected build/enumeration-native.actual
