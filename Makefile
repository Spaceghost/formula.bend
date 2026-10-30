BEND ?= bend

.PHONY: check native-check
check:
	$(BEND) PROOF.bend
	$(BEND) tests.bend
	mkdir -p build
	$(BEND) runtime.bend > build/runtime-js.actual
	diff -u runtime.expected build/runtime-js.actual

native-check:
	mkdir -p build
	$(BEND) runtime.bend -o build/runtime
	./build/runtime > build/runtime-native.actual
	diff -u runtime.expected build/runtime-native.actual
