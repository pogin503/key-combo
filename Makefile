ifndef EMACS
	EMACS=emacs
endif

travis-ci:
	${EMACS} --version
	${EMACS} -batch -Q -L . -l test/run-test.el
