BEND ?= bend
LUA ?= lua
BUN ?= bun

.PHONY: parity-check check native-check rounding-check division-check address-check enumeration-check unicode-check unicode-boundary-check wire-check
check:
	$(MAKE) integer-context-check
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
	$(MAKE) binary64-check
	$(MAKE) stored-check
	$(MAKE) stored-dependencies-check
	$(MAKE) parity-check

.PHONY: binary64-check
binary64-check:
	mkdir -p build
	$(LUA) tools/generate-binary64-cases.lua build/binary64.input
	$(BEND) compat/binary64-runtime.bend -o build/binary64-runtime.js
	$(BUN) build/binary64-runtime.js build/binary64.input > build/binary64.actual
	diff -u compat/binary64-oracle.tsv build/binary64.actual
	$(LUA) tools/generate-binary64-conversion-cases.lua build/binary64-conversion.input
	$(BUN) build/binary64-runtime.js build/binary64-conversion.input > build/binary64-conversion.actual
	diff -u compat/binary64-conversion-oracle.tsv build/binary64-conversion.actual
	$(LUA) tools/generate-binary64-format-cases.lua build/binary64-format.input
	$(BUN) build/binary64-runtime.js build/binary64-format.input > build/binary64-format.actual
	diff -u compat/binary64-format-oracle.tsv build/binary64-format.actual
	$(LUA) tools/generate-binary64-ruby-conversion-cases.lua build/binary64-ruby-conversion.input
	$(BUN) build/binary64-runtime.js build/binary64-ruby-conversion.input > build/binary64-ruby-conversion.actual
	diff -u compat/binary64-ruby-conversion-oracle.tsv build/binary64-ruby-conversion.actual
	$(LUA) tools/generate-binary64-coercion-cases.lua build/binary64-coercion.input
	$(BUN) build/binary64-runtime.js build/binary64-coercion.input > build/binary64-coercion.actual
	diff -u compat/binary64-coercion-oracle.tsv build/binary64-coercion.actual

.PHONY: binary64-native-check
binary64-native-check:
	mkdir -p build
	$(LUA) tools/generate-binary64-cases.lua build/binary64.input
	$(LUA) tools/generate-binary64-conversion-cases.lua build/binary64-conversion.input
	$(LUA) tools/generate-binary64-format-cases.lua build/binary64-format.input
	$(LUA) tools/generate-binary64-ruby-conversion-cases.lua build/binary64-ruby-conversion.input
	$(LUA) tools/generate-binary64-coercion-cases.lua build/binary64-coercion.input
	$(BEND) compat/binary64-runtime.bend -o build/binary64-runtime-native
	./build/binary64-runtime-native build/binary64.input +RTS --gpu off --threads 1 > build/binary64-native-1.actual
	diff -u compat/binary64-oracle.tsv build/binary64-native-1.actual
	./build/binary64-runtime-native build/binary64.input +RTS --gpu off --threads 8 > build/binary64-native-8.actual
	diff -u compat/binary64-oracle.tsv build/binary64-native-8.actual
	./build/binary64-runtime-native build/binary64-conversion.input +RTS --gpu off --threads 1 > build/binary64-conversion-native-1.actual
	diff -u compat/binary64-conversion-oracle.tsv build/binary64-conversion-native-1.actual
	./build/binary64-runtime-native build/binary64-conversion.input +RTS --gpu off --threads 8 > build/binary64-conversion-native-8.actual
	diff -u compat/binary64-conversion-oracle.tsv build/binary64-conversion-native-8.actual
	./build/binary64-runtime-native build/binary64-format.input +RTS --gpu off --threads 1 > build/binary64-format-native-1.actual
	diff -u compat/binary64-format-oracle.tsv build/binary64-format-native-1.actual
	./build/binary64-runtime-native build/binary64-format.input +RTS --gpu off --threads 8 > build/binary64-format-native-8.actual
	diff -u compat/binary64-format-oracle.tsv build/binary64-format-native-8.actual
	./build/binary64-runtime-native build/binary64-ruby-conversion.input +RTS --gpu off --threads 1 > build/binary64-ruby-conversion-native-1.actual
	diff -u compat/binary64-ruby-conversion-oracle.tsv build/binary64-ruby-conversion-native-1.actual
	./build/binary64-runtime-native build/binary64-ruby-conversion.input +RTS --gpu off --threads 8 > build/binary64-ruby-conversion-native-8.actual
	diff -u compat/binary64-ruby-conversion-oracle.tsv build/binary64-ruby-conversion-native-8.actual
	./build/binary64-runtime-native build/binary64-coercion.input +RTS --gpu off --threads 1 > build/binary64-coercion-native-1.actual
	diff -u compat/binary64-coercion-oracle.tsv build/binary64-coercion-native-1.actual
	./build/binary64-runtime-native build/binary64-coercion.input +RTS --gpu off --threads 8 > build/binary64-coercion-native-8.actual
	diff -u compat/binary64-coercion-oracle.tsv build/binary64-coercion-native-8.actual

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
	$(MAKE) binary64-native-check
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

.PHONY: integer-context-check
integer-context-check:
	$(LUA) tools/check-integer-context.lua

.PHONY: stored-check
stored-check:
	mkdir -p build
	$(LUA) tools/generate-wire.lua compat/stored-cases.lua build/stored.input
	$(BEND) compat/stored-runtime.bend -o build/stored-runtime.js
	$(BUN) build/stored-runtime.js build/stored.input > build/stored.actual
	diff -u compat/stored-oracle.tsv build/stored.actual

.PHONY: stored-dependencies-check
stored-dependencies-check:
	mkdir -p build
	$(LUA) tools/generate-wire.lua compat/stored-cases.lua build/stored.input
	$(LUA) tools/generate-wire.lua compat/stored-dependency-cases.lua build/stored-dependencies.input
	$(LUA) tools/generate-wire.lua compat/stored-checked-cases.lua build/stored-checked.input
	$(LUA) tools/generate-wire.lua compat/stored-native-error-cases.lua build/stored-native-error.input
	$(BEND) compat/stored-runtime.bend -o build/stored-analysis-runtime.js
	$(BUN) build/stored-analysis-runtime.js build/stored-dependencies.input > build/stored-dependencies.actual
	diff -u compat/stored-dependency-oracle.tsv build/stored-dependencies.actual
	$(BUN) build/stored-analysis-runtime.js build/stored-checked.input > build/stored-checked.actual
	diff -u compat/stored-checked-oracle.tsv build/stored-checked.actual
	$(BUN) build/stored-analysis-runtime.js build/stored.input > build/stored-analysis-values.actual
	diff -u compat/stored-oracle.tsv build/stored-analysis-values.actual
	$(BUN) build/stored-analysis-runtime.js build/stored-native-error.input > build/stored-native-error.actual
	diff -u compat/stored-native-error-oracle.tsv build/stored-native-error.actual
