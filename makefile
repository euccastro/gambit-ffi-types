test-scheme-object-size-in-words: test-scheme-object-size-in-words.scm ffi-types-lib.scm test-lib.scm test-macro.scm
	gsc -debug -exe -o test-scheme-object-size-in-words -cc-options -g test-lib.scm ffi-types-lib.scm test-scheme-object-size-in-words.scm

integration-test: test-lib.scm test-macro.scm ffi-types-lib.scm ffi-types-include.scm expand.scm integration-test.scm
	gsc -debug -exe -o integration-test -cc-options -g test-lib.scm ffi-types-lib.scm integration-test.scm

test: integration-test
	gsi test-expansion.scm && ./integration-test && echo "\nAll OK."

clean:
	rm -f *.o *.c integration-test
