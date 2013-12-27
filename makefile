test-scheme-object-size-in-words: test-scheme-object-size-in-words.scm ffi-types-lib.scm test-lib.scm
	gsc -exe -o test-scheme-object-size-in-words test-lib.scm ffi-types-lib.scm test-scheme-object-size-in-words.scm

test: test-scheme-object-size-in-words
	gsi ./test-expand.scm && ./test-scheme-object-size-in-words && echo "\nAll OK."

all: ffi-types-lib
clean:
	rm -f *.o *.c test-scheme-object-size-in-words
