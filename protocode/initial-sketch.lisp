(uiop:define-package :hidden)
(in-package :cl-user)

;;------------------------------------------------------------

(defun symb (&rest parts)
  (intern (format nil "~{~a~}" parts)))

(defun kwd (&rest parts)
  (intern (format nil "~{~a~}" parts) :keyword))

(defun psymb (package &rest parts)
  (intern (format nil "~{~a~}" parts)
          package))

(defun hide (s) (psymb :hidden s))

;;------------------------------------------------------------

(defmacro defrec (name &body slot-names)
  nil)

#||

generate 2 types, a regular and incomplete version.

All apis take the regular (which is immutable) but the incomplete one is mutable
and can be passed around for incremental construction. You then call #'complete
with it and get the regular version.

Should have trivial copy method where you get to replace data in slots.

||#


(defrec a-thing
  a ;; you would also list your requirements for the slot
  b
  c)

;; makes

(defclass incomplete-a-thing () ;; could be a struct in final program?
  ((hidden::a :initarg :a :accessor a) ;; or maybe keep classes forever as we
   (hidden::b :initarg :b :accessor b) ;; don't always need that speed
   (hidden::c :initarg :c :accessor c)))

(defclass a-thing () ;; could also be a struct, where we can use :read-only
  ((hidden::a :initarg :a :reader a)
   (hidden::b :initarg :b :reader b)
   (hidden::c :initarg :c :reader c)))

(defmethod (setf a) (value (obj a-thing))
  (error "The slot A on the instance of type A-THING is immutable:~%~a"
         obj))

(defmethod complete ((proto incomplete-a-thing))
  (make-instance 'a-thing
                 :a (a proto)
                 :b (b proto)
                 :c (c proto)))

(defmethod copy ((obj a-thing)
                 &key (a nil a-set)
                   (b nil b-set)
                   (c nil c-set))
  (make-instance 'a-thing
                 :a (if a-set a (a obj))
                 :a (if b-set b (b obj))
                 :a (if c-set c (c obj))))

#||

with classes we lose guarenteed immutability and with structs we loose
with-slots.

We could always obsure the true slot-name, force the reader to be the public
name and then with-slots won't work, however we can then implement with-rec as:

`(symbol-macrolet ((,slot-a (,slot-a ,thing))
                   (,slot-b (,slot-b ,thing)))
   ..)

||#

(defmacro with-rec ((&rest slot-names) instance &body body)
  (let ((slots (mapcar (lambda (x)
                         (etypecase x
                           (symbol (list x x))
                           (list x)))
                       slot-names)))
    (alexandria:with-gensyms (inst)
      `(let ((,inst ,instance))
         (symbol-macrolet
             ,(mapcar (lambda (s) `(,(second s) (,(first s) ,inst)))
                      slots)
           ,@body)))))

;;------------------------------------------------------------



(defmacro defrec (name &body slot-names)
  (let ((incomplete (symb :incomplete- name))
        (set-names (mapcar (lambda (n) (symb n :-set)) slot-names)))
    `(progn
       ,@(gen-rec-classes name incomplete slot-names)
       ,@(gen-rec-constructors name incomplete slot-names)
       ,@(mapcar (lambda (s) (gen-rec-set-method name s))
                 slot-names)
       ,(gen-rec-complete-method name incomplete slot-names)
       ,(gen-rec-copy-method name slot-names set-names)
       ,(gen-rec-copy-method incomplete slot-names set-names)
       ,(gen-rec-print-object name slot-names)
       ,(gen-rec-print-object incomplete slot-names))))

(defun gen-rec-print-object (name slot-names)
  `(defmethod print-object ((obj ,name) stream)
     (with-rec ,slot-names obj
       (format stream ,(format nil "#<~a~{ :~a ~~s~}>" name slot-names)
               ,@slot-names))))

(defun gen-rec-constructors (name incomplete slot-names)
  (let ((begin (symb :begin- name))
        (construct (symb :make- name)))
    `((defmethod ,begin (&key ,@slot-names)
        (make-instance ',incomplete
                       ,@(mapcan (lambda (n) `(,(kwd n) ,n)) slot-names)))
      ;;
      (defmethod ,construct (&key ,@slot-names)
        (complete (,begin ,@(mapcan (lambda (n) `(,(kwd n) ,n)) slot-names))))
      ;;
      (defmethod begin ((rec-type (eql ',name)) &key ,@slot-names)
        (,begin ,@(mapcan (lambda (n) `(,(kwd n) ,n)) slot-names)))
      ;;
      (defmethod revert ((rec ,name))
        (with-rec ,slot-names rec
          (,begin ,@(mapcan (lambda (n) `(,(kwd n) ,n)) slot-names)))))))

(defun gen-rec-classes (name incomplete slot-names)
  `((defclass ,incomplete ()
      ,(mapcar (lambda (s) `(,(hide s) :initarg ,(kwd s) :accessor ,s))
               slot-names))
    (defclass ,name ()
      ,(mapcar (lambda (s) `(,(hide s) :initarg ,(kwd s) :reader ,s))
               slot-names))))

(defun gen-rec-set-method (name slot-name)
  `(defmethod (setf ,slot-name) (value (obj ,name))
     (declare (ignore value))
     (error ,(format nil "The slot ~a on the instance of type ~a is immutable:~~%~~a"
                     slot-name name)
            obj)))

(defun gen-rec-copy-method (name slot-names set-names)
  `(defmethod copy ((obj ,name)
                    &key ,@(mapcar (lambda (n sn) `(,n nil ,sn))
                                   slot-names set-names))
     (make-instance
      ',name
      ,@(mapcan (lambda (n sn) `(,(kwd n) (if ,sn ,n (,n obj))))
                slot-names set-names))))

(defun gen-rec-complete-method (name incomplete slot-names)
  `(defmethod complete ((proto ,incomplete))
     (with-rec ,slot-names proto
       (make-instance
        ',name
        ,@(mapcan (lambda (s) (list (kwd s) s))
                  slot-names)))))

;;------------------------------------------------------------

(defgeneric begin (rec-type &key))
(defgeneric revert (rec-type))

(defmethod rec-eql (a b)
  (eq a b))

;;------------------------------------------------------------

(defrec something a b c)

;;------------------------------------------------------------
#|| Alternate language

pouch vessel item

seal
unseal

cap
uncap

open
close

if it's a completable type then defcompletable works, then complete & revert
work too

||#
