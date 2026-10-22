# Push Ifs Up And Fors Down

<https://matklad.github.io/2023/11/15/push-ifs-up-and-fors-down.html>

[matklad](https://matklad.github.io/)[About](https://matklad.github.io/about.html)[Links](https://matklad.github.io/links.html)[Blogroll](https://matklad.github.io/blogroll.html)

# Push Ifs Up And Fors Down

Nov 15, 2023

A short note on two related rules of thumb.

## [Push Ifs Up](https://matklad.github.io/2023/11/15/push-ifs-up-and-fors-down.html#Push-Ifs-Up)

If there’s an `if` condition inside a function, consider if it could be moved to the caller instead:

```
// GOOD
fn frobnicate(walrus: Walrus) {
    ...
}

// BAD
fn frobnicate(walrus: Option<Walrus>) {
  let walrus = match walrus {
    Some(it) => it,
    None => return,
  };
  ...
}
```

As in the example above, this often comes up with preconditions: a function might check precondition inside and “do nothing” if it doesn’t hold, or it could push the task of precondition checking to its caller, and enforce via types (or an assert) that the precondition holds. With preconditions especially, “pushing up” can become viral, and result in fewer checks overall, which is one motivation for this rule of thumb.

Another motivation is that control flow and `if`s are complicated, and are a source of bugs. By pushing `if`s up, you often end up centralizing control flow in a single function, which has a complex branching logic, but all the actual work is delegated to straight line subroutines.

_If_ you have complex control flow, better to fit it on a screen in a single function, rather than spread throughout the file. What’s more, with all the flow in one place it often is possible to notice redundancies and dead conditions. Compare:

```
fn f() {
  if foo && bar {
    if foo {

    } else {

    }
  }
}

fn g() {
  if foo && bar {
    h()
  }
}

fn h() {
  if foo {

  } else {

  }
}
```

For `f`, it’s much easier to notice a dead branch than for a combination of `g` and `h`!

A related pattern here is what I call “dissolving enum” refactor. Sometimes, the code ends up looking like this:

```
enum E {
  Foo(i32),
  Bar(String),
}

fn main() {
  let e = f();
  g(e)
}

fn f() -> E {
  if condition {
    E::Foo(x)
  } else {
    E::Bar(y)
  }
}

fn g(e: E) {
  match e {
    E::Foo(x) => foo(x),
    E::Bar(y) => bar(y)
  }
}
```

There are two branching instructions here and, by pulling them up, it becomes apparent that it is the exact same condition, triplicated (the third time reified as a data structure):

```
fn main() {
  if condition {
    foo(x)
  } else {
    bar(y)
  }
}
```

## [Push Fors Down](https://matklad.github.io/2023/11/15/push-ifs-up-and-fors-down.html#Push-Fors-Down)

This comes from data oriented school of thought. Few things are few, many things are many. Programs usually operate with bunches of objects. Or at least the hot path usually involves handling many entities. It is the volume of entities that makes the path hot in the first place. So it often is prudent to introduce a concept of a “batch” of objects, and make operations on batches the base case, with a scalar version being a special case of a batched ones:

```
// GOOD
frobnicate_batch(walruses)

// BAD
for walrus in walruses {
  frobnicate(walrus)
}
```

The primary benefit here is performance. Plenty of performance, [in extreme cases](http://venge.net/graydon/talks/VectorizedInterpretersTalk-2023-05-12.pdf).

If you have a whole batch of things to work with, you can amortize startup cost and be flexible about the order you process things. In fact, you don’t even need to process entities in any particular order, you can do vectorized/struct-of-array tricks to process one field of all entities first, before continuing with other fields.

Perhaps the most fun example here is [FFT-based polynomial multiplication](https://en.wikipedia.org/wiki/Sch%C3%B6nhage%E2%80%93Strassen_algorithm): turns out, evaluating a polynomial at a bunch of points simultaneously could be done faster than a bunch of individual point evaluations!

The two pieces of advice about `for`s and `if`s even compose!

```
// GOOD
if condition {
  for walrus in walruses {
    walrus.frobnicate()
  }
} else {
  for walrus in walruses {
    walrus.transmogrify()
  }
}

// BAD
for walrus in walruses {
  if condition {
    walrus.frobnicate()
  } else {
    walrus.transmogrify()
  }
}
```

The `GOOD` version is good, because it avoids repeatedly re-evaluating `condition`, removes a branch from the hot loop, and potentially unlocks vectorization. This pattern works on a micro level and on a macro level — the good version is the architecture of TigerBeetle, where in the data plane we operate on batches of objects at the same time, to amortize the cost of decision making in the control plane.

While performance is perhaps the primary motivation for the `for` advice, sometimes it helps with expressiveness as well. `jQuery` was quite successful back in the day, and it operates on collections of elements. The language of abstract vector spaces is often a better tool for thought than bunches of coordinate-wise equations.

To sum up, push the `if`s up and the `for`s down!

[Fix typo](https://github.com/matklad/matklad.github.io/edit/master/content/posts/2023-11-15-push-ifs-up-and-fors-down.dj)[Subscribe](https://matklad.github.io/feed.xml)[All posts](https://matklad.github.io/)[Get in touch](mailto:aleksey.kladov+blog@gmail.com)[matklad](https://github.com/matklad)
