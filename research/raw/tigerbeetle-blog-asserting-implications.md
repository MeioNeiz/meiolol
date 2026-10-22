# Asserting Implications

<https://tigerbeetle.com/blog/2025-05-26-asserting-implications/>

[Docs](https://docs.tigerbeetle.com/) [Pricing](https://tigerbeetle.com/cloud#pricing) [Blog](https://tigerbeetle.com/blog) [Company](https://tigerbeetle.com/company) [Stories](https://tigerbeetle.com/stories) [ 14.8K ](https://www.youtube.com/@tigerbeetledb)[ 17.2K](https://github.com/tigerbeetle/tigerbeetle)

[Cloud](https://tigerbeetle.com/cloud)

# Asserting Implications

May 26, 2025

-   [
    
    matklad
    
    ](https://matklad.github.io/)

A short one today!

When using assertions heavily, a common pattern is asserting an implication:

```
assert(a implies b);
```

Most programming languages don’t have special syntax for implication, as you don’t often _branch_ based on implications. But in my experience, you want to _assert_ implications all the time!

Recall that `and`, `or`, and `not` logical operators form a basis, so an implication can be expressed in terms of disjunction and negation:

A⇒B ⇔ ¬A∨B

This tautology is how asserting that `a` implies `b` gets expressed by default:

```
assert(!a or b);
```

I find this form hard to read, and suggest using the `if` instead:

```
if (a) assert(b);
```

From a recent code change:

```
// Before:
assert(header_b != null or replica.commit_min == replica.op_checkpoint);

// After:
if (header_b == null) assert(replica.commit_min == replica.op_checkpoint);
```

MORE POSTS

[

## Swarm Testing Data Structures

matklad · Apr 23, 2025

](https://tigerbeetle.com/blog/2025-04-23-swarm-testing-data-structures)

-   [View All Posts](https://tigerbeetle.com/blog)
-   [**RSS**](https://tigerbeetle.com/blog/atom.xml)

 

### Product

[

Cloud

](https://tigerbeetle.com/cloud)[

Pricing

](https://tigerbeetle.com/cloud#pricing)[

Stories

](https://tigerbeetle.com/stories)

### Developers

[

Docs

](https://docs.tigerbeetle.com/)[

GitHub

](https://github.com/tigerbeetle/tigerbeetle)[

Tutorials

](https://github.com/tigerbeetle/tigerlings)[

Releases

](https://github.com/tigerbeetle/tigerbeetle/releases)[

Jepsen

](https://jepsen.io/analyses/tigerbeetle-0.16.11)[

Blog

](https://tigerbeetle.com/blog)

### Connect

[

X

](https://x.com/TigerBeetleDB)[

LinkedIn

](https://www.linkedin.com/company/tigerbeetle/)[

YouTube

](https://www.youtube.com/@tigerbeetledb)[

Email

](mailto:hello@tigerbeetle.com)

### Company

[

About

](https://tigerbeetle.com/company)[

Privacy

](https://tigerbeetle.com/privacy)

### Newsletter

Get monthly highlights and carefully crafted updates.

[Subscribe](https://tigerbeetle.com/newsletter)[

Past Newsletters →

](https://tigerbeetle.com/newsletters)

Correct and Fast

Copyright © 2026 TigerBeetle, Inc. All Rights Reserved.
