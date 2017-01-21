;;;; completable-types.asd

(asdf:defsystem #:completable-types
  :description "Define dual incomplete (mutable) & complete (immutable) versions of the same class with convertors between the two"
  :author "Chris Bagley (Baggers) <chris.bagley@gmail.com>"
  :license "BSD 2 Clause"
  :serial t
  :depends-on (:alexandria)
  :components ((:file "package")
               (:file "base")))
