(in-package #:completable-types)

;;------------------------------------------------------------

(defun symb (&rest parts)
  (intern (format nil "~{~a~}" parts)))

(defun kwd (&rest parts)
  (intern (format nil "~{~a~}" parts) :keyword))

(defun psymb (package &rest parts)
  (intern (format nil "~{~a~}" parts)
          package))

(defun hide (s) (psymb :completable-types-hidden s))

(defun func-form-p (x)
  (and (listp x)
       (= (length x) 2)
       (eq (first x) 'function)
       (symbolp (second x))))

;;------------------------------------------------------------

(defclass standard-able-object () ())
(defclass standard-complete-object (standard-able-object) ())
(defclass standard-incomplete-object (standard-able-object) ())

;;------------------------------------------------------------

(defmacro defcompletable (name options &body slots)
  (declare (ignore options))
  (multiple-value-bind (slot-names predicates)
      (parse-rec-slots slots)
    (let ((incomplete (symb :incomplete- name))
          (set-names (mapcar (lambda (n) (symb n :-set)) slot-names)))
      `(progn
         ,@(gen-rec-classes name incomplete slot-names)
         ,@(gen-rec-constructors name incomplete slot-names)
         ,@(mapcar (lambda (s) (gen-rec-set-method name s))
                   slot-names)
         ,(gen-rec-complete-method name incomplete slot-names predicates)
         ,(gen-rec-copy-method name slot-names set-names)
         ,(gen-rec-copy-method incomplete slot-names set-names)
         ,(gen-rec-print-object name slot-names)
         ,(gen-rec-print-object incomplete slot-names)
         ,(gen-rec-comparator name 'eq slot-names)
         ,(gen-rec-comparator name 'eql slot-names)
         ,(gen-rec-comparator name 'equal slot-names)
         ,(gen-rec-comparator incomplete 'eq slot-names)
         ,(gen-rec-comparator incomplete 'eql slot-names)
         ,(gen-rec-comparator incomplete 'equal slot-names)))))

(defun parse-rec-slots (slots)
  (labels ((listify (x) (if (listp x) x (list x))))
    (let* ((slots (mapcar #'listify slots))
           (slot-names (mapcar #'first slots))
           (pred-forms (mapcar #'rest slots))
           (predicates
            (loop :for (pred-args . pred-body) :in pred-forms :collect
               (cond
                 ((and (null pred-args) (null pred-body))
                  nil)
                 ((func-form-p pred-args)
                  (assert (null pred-body) ()
                          "defcompletable: malformed slot ~a"
                          (cons pred-args pred-body))
                  pred-args)
                 ((and (= 1 (length pred-args)) pred-body)
                  `(lambda ,pred-args ,@pred-body))
                 (t (error "defcompletable: malformed slot ~a"
                           (cons pred-args pred-body)))))))
      (values slot-names predicates))))

(defun gen-rec-print-object (name slot-names)
  `(defmethod print-object ((obj ,name) stream)
     (with-contents ,slot-names obj
       (format stream ,(format nil "#<~a~{ :~a ~~s~}>" name slot-names)
               ,@slot-names))))

(defun gen-rec-classes (name incomplete slot-names)
  `((defclass ,incomplete (standard-incomplete-object)
      ,(mapcar (lambda (s) `(,(hide s) :initarg ,(kwd s) :accessor ,s))
               slot-names))
    (defclass ,name (standard-complete-object)
      ,(mapcar (lambda (s) `(,(hide s) :initarg ,(kwd s) :reader ,s))
               slot-names))))

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
        (with-contents ,slot-names rec
          (,begin ,@(mapcan (lambda (n) `(,(kwd n) ,n)) slot-names)))))))

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

(defun gen-rec-complete-method (name incomplete slot-names predicates)
  (let* ((test-vars (mapcar (lambda (x) (gensym (symbol-name x))) slot-names))
         (pred-tripples (mapcar #'list slot-names test-vars predicates))
         (pred-tripples (remove nil pred-tripples :key #'third))
         (final-test-vars (mapcar #'second pred-tripples)))
    `(defmethod complete ((proto ,incomplete))
       (with-contents ,slot-names proto
         (let ,(loop :for (slot var pred) :in pred-tripples :when pred :collect
                  `(,var (unless (funcall ,pred ,slot)
                           (format nil "The following predicate failed for ~a which has the value ~s:~%~s"
                                   ',slot ,slot ',pred))))
           (when (or ,@final-test-vars)
             (error "Could not complete ~a into a ~a for the following reasons:~{~%~%~a~}"
                    proto ',name (remove nil (list ,@final-test-vars))))
           (make-instance
            ',name
            ,@(mapcan (lambda (s) (list (kwd s) s))
                      slot-names)))))))

(defun gen-rec-comparator (name comparator slot-names)
  (let* ((mtd-name (psymb :completable-types :content- comparator))
         (b-names (mapcar (lambda (n) (gensym (symbol-name n)))
                          slot-names))
         (b-pairs (mapcar #'list slot-names b-names)))
    `(defmethod ,mtd-name ((a ,name) (b ,name))
       (with-contents ,slot-names a
         (with-contents ,b-pairs b
           (and ,@(mapcar (lambda (an bn) `(eq ,an ,bn))
                          slot-names b-names) ))))))

;;------------------------------------------------------------

(defgeneric begin (rec-type &key))
(defgeneric revert (rec-type))

(defmethod content-eq (a b)
  (eq a b))

(defmethod content-eql (a b)
  (eql a b))

(defmethod content-equal (a b)
  (equal a b))

;;------------------------------------------------------------

(defmacro with-contents ((&rest slot-names) instance &body body)
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
;; Example

#+nil
(defcompletable gadget ()
  wheel
  (sprocket-count #'numberp)
  (name (o) (and (typep o 'string) (> (length o) 2))))

;;------------------------------------------------------------
