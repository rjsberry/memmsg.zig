# _memmsg.zig_

> :construction: Work in progress!

Safe zero-cost message passing between Zig programs.

Memmsg itself is not a binary protocol. It's a building block for creating your
own binary protocols with stability guarantees across CPU architectures.

At its core Memmsg will just cast your types to/from arrays of bytes; at runtime
it's effectively no-op. However! It also performs compile-time checking of the
types you pass to it, and generates a compile error if the ABI of the type is
not safe to pass between programs. This lets you create structures whose
in-memory layout and over-the-wire binary format are identical with confidence!

