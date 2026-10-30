BEND ?= bend

.PHONY: check native-check rounding-check division-check address-check
check:
	$(BEND) PROOF.bend
	$(BEND) tests.bend
	mkdir -p build
	$(BEND) runtime.bend > build/runtime-js.actual
	diff -u runtime.expected build/runtime-js.actual
	$(MAKE) rounding-check
	$(MAKE) division-check
	$(MAKE) address-check

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
