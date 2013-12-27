test-scheme-object-size-in-words: test-scheme-object-size-in-words.scm ffi-types-lib.scm test-lib.scm
	gsc -debug -exe -o test-scheme-object-size-in-words -cc-options -g test-lib.scm ffi-types-lib.scm test-scheme-object-size-in-words.scm

basic-test: test-lib.scm ffi-types-lib.scm ffi-types-include.scm expand.scm basic-test.scm
	gsc -debug -exe -o basic-test -cc-options -g test-lib.scm ffi-types-lib.scm basic-test.scm

test: test-scheme-object-size-in-words basic-test
	gsi ./test-expand.scm && ./test-scheme-object-size-in-words && ./basic-test && echo "\nAll OK."

all: ffi-types-lib
clean:
	rm -f *.o *.c test-scheme-object-size-in-words basic-test
