# ifndef EMACS
# 	EMACS=emacs
# endif

travis-ci:
	${EMACS} --version
	${EMACS} -batch -Q -l test/run-test.el
