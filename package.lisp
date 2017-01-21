;;;; package.lisp

(uiop:define-package #:completable-types
    (:use #:cl)
  (:export :defcompletable :begin :complete :revert
           :content-eq :content-eql :content-equal
           :with-contents :copy
           :standard-complete-object :standard-incomplete-object))

(uiop:define-package #:completable-types-hidden)
