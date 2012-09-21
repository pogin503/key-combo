(require 'ert)
(require 'el-spec)

(require 'key-combo)
(key-combo-load-default)

(defun test1()
  (interactive)
  (message "test1")
  )

(defun test2()
  (interactive)
  (message "test2")
  )

(defun key-combo-test-helper-execute (cmd)
  (key-combo-mode 1)
  (execute-kbd-macro (key-combo-read-kbd-macro cmd))
  (substring-no-properties (buffer-string)))

(defun key-combo-test-helper-define-lookup (cmd)
  (key-combo-define-global ">>" cmd)
  (key-combo-key-binding ">>"))

(defun key-combo-test-helper-binding-execute (cmd)
  (key-combo-command-execute (key-combo-key-binding cmd))
  (substring-no-properties (buffer-string)))

(dont-compile
  (when (fboundp 'describe)
    (describe ("key-combo in temp-buffer" :vars ((mode)))
      (shared-context ("execute" :vars (cmd))
        (around
          (key-combo-mode 1)
          (if cmd (execute-kbd-macro (key-combo-read-kbd-macro cmd)))
          (funcall el-spec:example)))
      (shared-context ("insert & execute" :vars (pre-string))
        (before
          (key-combo-mode 1)
          (insert pre-string))
        (include-context "execute"))

      (shared-examples "check pre-command-hook"
        (it ()
          (key-combo-mode 1)
          (should (memq 'key-combo-pre-command-function pre-command-hook)))
        (it ()
          (key-combo-mode -1)
          (should-not (memq 'key-combo-pre-command-function pre-command-hook))))
      (shared-examples "C-a"
        (before
          (insert "B\n IP")
          (key-combo-mode 1))
        (it ()
          (should (key-combo-key-binding (kbd "C-a C-a"))))
        ;; (it ()
        ;;   (key-combo-mode -1)
        ;;   (should-not (key-combo-key-binding (kbd "C-a C-a"))))
        (it ()
          (key-combo-test-helper-execute "C-a")
          (should (equal (char-to-string (following-char)) "I")))
        (it ()
          (key-combo-test-helper-execute "C-a C-a")
          (should (equal (char-to-string (following-char)) " ")))
        (it ()
          (key-combo-test-helper-execute "C-a C-a C-a")
          (should (equal (char-to-string (following-char)) "B")))
        ;; fail in temp buffer?
        ;; (it (:vars ((cmd "C-a C-a C-a C-a")))
        ;;   (backward-char)
        ;;   (should (equal (char-to-string (following-char)) "P")))
        )

      (around
        (setq key-combo-command-keys nil)
        (with-temp-buffer
          (switch-to-buffer (current-buffer))
          (let ((key-combo-mode-map
                 (copy-keymap key-combo-mode-map))
                (global-map-org (current-global-map))
                (global-map (copy-keymap (current-global-map))))
            (unwind-protect
                (progn
                  (use-global-map global-map)
                  (funcall el-spec:example))
              (use-global-map global-map-org)))))

      (it ()
        (should (eq key-combo-mode nil)))
      (it "is key-combo element"
        (should (key-combo-elementp ">"))
        (should (key-combo-elementp '(lambda()())))
        (should (key-combo-elementp 'nil))
        (should (key-combo-elementp 'self-insert-command)))
      (it "is not key-combo element"
        (should-not (key-combo-elementp '(">")))
        (should-not (key-combo-elementp '((lambda()()))))
        (should-not (key-combo-elementp '(nil)))
        (should-not (key-combo-elementp '(self-insert-command)))
        (should-not (key-combo-elementp 'wrong-command)))
      (include-examples "check pre-command-hook")
      (include-examples "C-a")
      (it "can define & lookup"
        (should (key-combo-test-helper-define-lookup '(lambda()())))
        (should (key-combo-test-helper-define-lookup ">"))
        (should (key-combo-test-helper-define-lookup 'self-insert-command))
        (should (key-combo-test-helper-define-lookup '((lambda()()))))
        (should (key-combo-test-helper-define-lookup '(">")))
        (should (key-combo-test-helper-define-lookup '(self-insert-command)))
        (should (key-combo-test-helper-define-lookup '(">" ">")))
        (should (key-combo-test-helper-define-lookup '(">" (lambda()()))))
        (should (key-combo-test-helper-define-lookup '((lambda()()) ">")))
        (should
         (key-combo-test-helper-define-lookup '((lambda()()) (lambda()()))))
        (should
         (key-combo-test-helper-define-lookup '(">" self-insert-command)))
        (should
         (key-combo-test-helper-define-lookup '(self-insert-command ">")))
        (should
         (key-combo-test-helper-define-lookup
          '(self-insert-command self-insert-command)))
        )

      (context "in default-mode"
        (context "execute"
          (it ()
            (should (string= (key-combo-test-helper-execute ">") ">")))
          (it ()
            (should (string= (key-combo-test-helper-execute "=") "="))))
        (context ("no execute" :vars ((cmd nil)))
          (it ()
            (key-combo-command-execute (lambda () (insert "a")))
            (should (string= (buffer-string) "a")))
          (it ()
            (should-error (key-combo-command-execute 'wrong-command)))
          (it ()
            (let ((last-command-event ?b))
              (key-combo-command-execute 'self-insert-command))
            (should (string= (buffer-string) "b")))
          (it ()
            (key-combo-command-execute (key-combo-get-command "a"))
            (should (string= (buffer-string) "a")))
          (it ()
            (key-combo-command-execute (key-combo-get-command "a`!!'a"))
            (should (string= (buffer-string) "aa"))
            (should (eq (point) 2)))
          (it ()
            (buffer-enable-undo)
            (let ((key-combo-undo-list))
              (key-combo-command-execute (lambda() (insert "a")))
              (key-combo-undo))
            (should (string= (buffer-string) "")))
          (it ()
            (buffer-enable-undo)
            (let ((key-combo-undo-list))
              (key-combo-command-execute (key-combo-get-command "a`!!'a"))
              (key-combo-undo))
            (should (string= (buffer-string) "")))
          (it ()
            (should-error (key-combo-define-global "a" 'wrong-command)))
          (it ()
            (should (key-combo-define-global "a" 'self-insert-command)))
          (it ()
            (should (eq (key-combo-define-global "a" nil) nil)))
          (it ()
            (should (eq (key-combo-define-global (kbd "C-M-g") nil) nil)))))
      (context "in emacs-lisp-mode"
        (before
          (emacs-lisp-mode))
        (it ()
          (key-combo-define-global (kbd "M-s") "a"))
        (it ()
          (should-not (key-combo-comment-or-stringp)))
        (it ()
          (insert "\"")
          (should (key-combo-comment-or-stringp)))
        (it ()
          (insert ";")
          (should (key-combo-comment-or-stringp)))
        (it ()
          (insert ";\n")
          (should-not (key-combo-comment-or-stringp)))
        (context "isearch-mode"
          (it ()
            (insert "=")
            (should (string= (buffer-string) "="))
            (should (eq (point) 2)))
          (it ()
            (insert "=");; not to raise error from isearch-search
            (isearch-mode nil);; backward search
            (execute-kbd-macro "=")
            (should (string= (buffer-string) "="))
            (should (eq (point) 1))))
        (context "execute only"
          (it ()
            (should (string= (key-combo-test-helper-execute "=") "= ")))
          (it ()
            (should (string= (key-combo-test-helper-execute "==") "eq ")))
          (it ()
            (should (string= (key-combo-test-helper-execute ",") ",")))
          (it ()
            (should (string= (key-combo-test-helper-execute ",,") ",,")))
          (it ()
            (should (string= (key-combo-test-helper-execute ".") ".")))
          (it ()
            (should (string= (key-combo-test-helper-execute ". SPC") " . ")))
          (it ()
            (should (string= (key-combo-test-helper-execute ";") ";; ")))
          (it ()
            (should (string= (key-combo-test-helper-execute ";.") ";; .")))
          (it ()
            (should (string= (key-combo-test-helper-execute ";,") ";; ,")))
          (it ()
            (insert ";")
            (should (string= (key-combo-test-helper-execute "=") ";=")))
          )
        (context "with mock"
          (when (require 'el-mock nil t)
            (it ()
              (should-error
               (with-mock
                 (mock (test1 *) :times 1)
                 (key-combo-define-global (kbd "M-C-d") '(test1 test2)))))
            (it ()
              ;; no error
              (with-mock
                (mock (test1 *) :times 1)
                (key-combo-define-global (kbd "M-C-d") '(test1 test2))
                (execute-kbd-macro (kbd "M-C-d"))))
            (it ()
              ;; no error
              (with-mock
                (mock (test1 *) :times 1)
                (mock (test2 *) :times 1)
                (key-combo-define-global (kbd "M-C-d") '(test1 test2))
                (execute-kbd-macro (kbd "M-C-d M-C-d"))))
            (it ()
              ;; no error
              (with-mock
                (mock (define-key * * *) :times 1)
                (key-combo-define-local "a" "a")))
            (it ()
              ;; no error
              (with-mock
                (mock (define-key * * *) :times 1)
                (key-combo-define-local "a" '("a"))))
            (it ()
              ;; no error
              (with-mock
                (mock (define-key * * *) :times 3);; 1 for recursive call?
                (key-combo-define-local "a" '("a" "b"))))
            (it ()
              ;; no error
              (with-mock
                (mock (lookup-key * *) => t :times 2)
                (mock (define-key * * *) :times 2);; 1 for recursive call?
                (key-combo-define-local "a" '("a" "b")))))
          )
        (context "in skk-mode"
          (when (require 'skk-autoloads nil t)
            (before
              (skk-mode 1)
              (setq this-command 'skk-insert)
              (insert ";")
              )
            (it ()
              (should (string= (key-combo-test-helper-execute ",") ";、")))
            (it ()
              (should (string= (key-combo-test-helper-execute ".") ";。")))
            )
          )
        (context ("insert & move & execute" :vars (pos pre-string))
          (it ()
            (insert "\"")
            (should (string= (key-combo-test-helper-execute "=") "\"=")))
          (it ()
            (insert ";")
            (should (string= (key-combo-test-helper-execute "=") ";=")))
          (it ()
            (insert ";")
            (should (string= (key-combo-test-helper-execute ",") ";,")))
          (it ()
            (insert ";\n")
            (should (string= (key-combo-test-helper-execute ";") ";\n;; ")))
          (it ()
            (insert ";")
            (should (string= (key-combo-test-helper-execute ".") ";.")))
          (it ()
            (insert "\"\"\n")
            (goto-char 3)
            (should (string= (key-combo-test-helper-execute ".") "\"\".\n")))
          (it ()
            (insert "\"\"a")
            (goto-char 3)
            (should (string= (key-combo-test-helper-execute ".") "\"\".a")))
          (it ()
            (insert "\"\"")
            (goto-char 3)
            (should (string= (key-combo-test-helper-execute ".") "\"\".")))
          (it ()
            (insert "\"\"")
            (goto-char 2)
            (should (string= (key-combo-test-helper-execute ".") "\".\"")))
          (it ()
            (insert "a\"\"")
            (goto-char 2)
            (should (string= (key-combo-test-helper-execute ".") "a.\"\"")))
          )
        (include-examples "C-a")
        (include-examples "check pre-command-hook"))
      (context "in ruby"
        (before
          (key-combo-mode 1)
          (ruby-mode)
          (when (boundp 'auto-complete-mode)
            (auto-complete-mode -1)))
        ;; (include-context "execute")
        ;; bug?for auto-complete completion
        (it ()
          (should (string= (key-combo-test-helper-execute ".") ".")))
        (it ()
          (should (string= (key-combo-test-helper-execute "..") "..")))
        (it ()
          (should (string= (key-combo-test-helper-execute "...") "...")))
        (it ()
          (should (string= (key-combo-test-helper-execute "!~") " !~ ")))
        (it ()
          (should (string= (key-combo-test-helper-execute "**") "**")))
        (it ()
          (should (string= (key-combo-test-helper-execute "||=") " ||= "))))
      (context "in c-mode"
        (before
          ;; (key-combo-mode 1)
          (c-mode))
        (context "execute+"
          (it ()
            (should (string= (key-combo-test-helper-execute "+") " + ")))
          (it ()
            (should (string= (key-combo-test-helper-execute "++") "++")))
          ;; (it ()
          ;;   (should (string= (key-description "+") "+")))
          (it ()
            (should (equal (listify-key-sequence "+") '(43))))
          (it ()
            (should (string= (key-description '(?+)) "+")))
          (it ()
            (should (equal (key-combo-make-key-vector '(?+))
                           ;;(vector 'key-combo (intern (key-description )))
                           [key-combo _+])))
          (it ("a")
            (should (not (null (key-binding
                                (key-combo-make-key-vector '(?+))
                                )))))
          (it ("c")
            (should (not (null (lookup-key
                                (current-local-map)
                                (key-combo-make-key-vector '(?+))
                                )))))
          (it ("b")
            (should (not (equal (key-binding
                                 (key-combo-make-key-vector '(?+)))
                                'key-combo-execute-original))))
          (it ()
            (should (not (null (key-combo-get-command "+")))))
          (it ()
            (should (not (equal (key-combo-get-command "+")
                                'key-combo-execute-original))))
          (it ("d")
            (key-combo-define-local "a" nil)
            ;; (key-combo-key-binding "a")
            ;; (key-binding (vector 'key-combo (intern (key-description "a"))))
            ;; accept-default bug?
            (should (eq (lookup-key (current-local-map)
                                    (key-combo-make-key-vector '(?a)))
                        nil))
            (key-combo-define-local "a" "a")
            (should (not (equal (lookup-key (current-local-map)
                                            (key-combo-make-key-vector '(?a)))
                                nil)))
            (key-combo-define-local "a" nil)
            )
          )
        (context "undo"
          (before
            (buffer-enable-undo))
          (it ()
            (should (string= (key-combo-test-helper-execute "=") " = ")))
          (it ()
            (should (string= (key-combo-test-helper-execute "=") " = "))
            (undo)
            (should (string= (buffer-string) "="))
            )
          (it ()
            (should (string= (key-combo-test-helper-execute "= C-x u") "=")))
          (it ()
            (should (string= (key-combo-test-helper-execute "== C-x u") " = ")))
          )
        (context "execute"
          ;; (include-context "execute")
          (it ()
            (should (string= (key-combo-test-helper-execute "=") " = ")))
          (it ()
            (should (string= (key-combo-test-helper-execute "=*") " =* ")))
          (it ()
            (should (string= (key-combo-test-helper-execute "==") " == ")))
          (it ()
            (should (string= (key-combo-test-helper-execute "===") " === ")))
          (it "loop"
            (should (string= (key-combo-test-helper-execute "====") " = ")))
          (it ()
            (should (string= (key-combo-test-helper-execute "=>=") " => = ")))
          ;; (it ()
          ;; (should (string= (key-combo-test-helper-execute "==!") " ==! ")))
          (it ()
            (should (string= (key-combo-test-helper-execute "=>") " => ")))
          (it ()
            (should (string= (key-combo-test-helper-execute "/") "/")))
          (it ()
            (should (string= (key-combo-test-helper-execute "/ SPC") " / ")))
          (it ()
            (should (string= (key-combo-test-helper-execute "*") "*")))
          (it ()
            (should (string= (key-combo-test-helper-execute "**") "**")))
          (it ()
            (should (string= (key-combo-test-helper-execute "->") "->")))
          (it ()
            (should (string= (key-combo-test-helper-execute ".") ".")))
          ;; todo check position
          (it ()
            (should (string= (key-combo-test-helper-execute "/* RET")
                             "/*\n  \n */")))
          ;; todo depend on indent width
          ;; (it ()
          ;; (should (string= (key-combo-test-helper-execute "{ RET") "{\n  \n}"))
          )
        (context ("funcall" :vars (lookup-cmd))
          ;; (before
          ;;   (key-combo-command-execute (key-combo-key-binding lookup-cmd)))
          (it ()
            (should (string=
                     (key-combo-test-helper-binding-execute "=") " = ")))
          (it ()
            (should (string=
                     (key-combo-test-helper-binding-execute "==") " == ")))
          (it ()
            (should (string=
                     (key-combo-test-helper-binding-execute [?=]) " = ")))
          (it ()
            (should (string=
                     (key-combo-test-helper-binding-execute [?= ?=]) " == ")))
          (it ()
            (should (string=
                     (key-combo-test-helper-binding-execute [?= ?>]) " => ")))
          (it ()
            (should (string=
                     (key-combo-test-helper-binding-execute [?= ?= ?=])
                     " === ")))
          ;; (it ()
          ;;   (funcall (key-combo-key-binding [?= ?= ?= ?=]))
          ;;   (should (string= (buffer-string) " ==== ")))
          (it ()
            (key-combo-define-global (kbd "C-M-h") " == ")
            (key-combo-command-execute (key-combo-key-binding (kbd "C-M-h")))
            (should (equal (buffer-string) " == ")))
          (it ()
            (should-not
             (equal
              (key-combo-lookup-key (current-global-map) (kbd "C-M-h"))
              " == ")))
          ;; (it ()
          ;;   (key-combo-define-global (kbd "C-M-h C-M-h") " === ")
          ;;   (execute-kbd-macro (kbd "C-M-h C-M-h"))
          ;;   (should (string= (buffer-string) " === "))
          ;;   )
          (it ()
            (key-combo-define-global (kbd "C-M-h C-M-h") " === ")
            (key-combo-command-execute
             (key-combo-key-binding (kbd "C-M-h C-M-h")))
            (should (string= (buffer-string) " === "))
            )
          (it ()
            (should-not (key-combo-key-binding [?= ?= ?= ?=])))
          (context "pre-string & execute"
            (include-context "insert & execute")
            (it (:vars ((cmd "=")
                        (pre-string "a  ")))
              (should (string= (buffer-string) "a  = ")))
            )
          )
        )
      )
))
