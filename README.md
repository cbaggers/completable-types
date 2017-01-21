# Completable-Types

This is just me playing around. Nothing of any interest to see here.

-------------

This is yet another way of defining simple classes. It's a completely untested theory, but I want to try it out in some projects.

The idea is you define a simple type:

    (defcompletable gadget ()
      wheel sprocket oil-tank)

And then you can either make it as with structs:

    (make-gadget :wheel a-wheel
                 :sprocket a-sprocket
                 :oil-tank an-oil-tank)

    #<GADGET :WHEEL #<..> :SPROCKET #<..> :OIL-TANK #<..>>

Which gives you a 'complete' immutable instance of the type. Or you can call the `begin-` variant:

    (begin-gadget :wheel a-wheel
                  :sprocket a-sprocket
                  :oil-tank an-oil-tank)

    #<INCOMPLETE-GADGET :WHEEL #<..> :SPROCKET #<..> :OIL-TANK #<..>>

Which gives you a 'incomplete' mutable instance of the type. You can then call `#'complete` to get a 'complete' (and immutable) version.

    (complete some-incomplete-gadget)

    #<GADGET :WHEEL #<..> :SPROCKET #<..> :OIL-TANK #<..>>

The idea is that local mutablity is (near enough) perfectly safe in sensible hands. It's nice to be able to construct an object over the duration of a function body for example. You can then make the business code of your project out of methods specializing on the complete variant of the type (`gadget` in the case above) and be sure you arent getting any mutation later on.

There is a version of `with-slots` called `with-contents` for accessing the contents of the objects and the accessors are always named the same as the slot.

There is a `copy` method which will make a new instance of a complete or incomplete type allowing you to change some of the contents if you wish.

    (defvar tmp0 (make-doohicky :a 1 :b 2 :c 3)) ;; this is a complete type
    (defvar tmp1 (copy tmp0 :b 200)) ;; the contents are now a=1 b=200 c=3

If you want to make an incomplete instance out of an existing complete one then just call `#'revert` on it.

Both `#'complete` & `#'revert` always create a new instance when called.

### Completion Predicates

In order to complete an object the values in the incomplete object may need to satify some predicate. Here is an example definition:

    (defcompletable gadget ()
      wheel
      (sprocket-count #'numberp)
      (name (o) (and (typep o 'string) (> (length o) 2))))

The predicate can either be declared as a function literal (which must start with `#'`) or you may write the predicate inline, in a lambda-like fashion.

When defining inline predicated you provide an argument list (which must contain only one argument) and then the body of the predicate.

With the above set we can get fairly decent error messages when `#'complete` is called. For example this form:

    COMPLETABLE-TYPES> (complete (begin-gadget :wheel "foo" :name "j" :sprocket-count #\a))

Results in the following error message

    Could not complete #<INCOMPLETE-GADGET :WHEEL "foo" :SPROCKET-COUNT #\a :NAME "j"> into a GADGET for the following reasons:

    The following predicate failed for SPROCKET-COUNT which has the value #\a:
    #'NUMBERP

    The following predicate failed for NAME which has the value "j":
    (LAMBDA (O) (AND (TYPEP O 'STRING) (> (LENGTH O) 2)))
       [Condition of type SIMPLE-ERROR]

    Restarts:
     0: [RETRY] Retry SLIME REPL evaluation request.
     1: [*ABORT] Return to SLIME's top level.
     2: [ABORT] abort thread (#<THREAD "repl-thread" RUNNING {1003B20033}>)

    Backtrace:
      0: ((:METHOD COMPLETE (INCOMPLETE-GADGET)) #<INCOMPLETE-GADGET :WHEEL "foo" :SPROCKET-COUNT #\a :NAME "j">) [fast-method]
      1: (SB-INT:SIMPLE-EVAL-IN-LEXENV (COMPLETE (BEGIN-GADGET :WHEEL "foo" :NAME "j" :SPROCKET-COUNT ...)) #<NULL-LEXENV>)
      2: (EVAL (COMPLETE (BEGIN-GADGET :WHEEL "foo" :NAME "j" :SPROCKET-COUNT ...)))
     --more--
