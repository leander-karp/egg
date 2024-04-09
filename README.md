# Egg

This is a implementation of a lisp-interpreter loosely based on [this article](http://kjetilvalle.com/posts/original-lisp.html):

```
# Create a list from the arguments
(defun pair (x y)
  (cons x (cons y 'nil)))
```

## Tests

To run the tests execute:

```sh
zig build test
```

New test files are only picked up if they are listed in `build.zig`.
