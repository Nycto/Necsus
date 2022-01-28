import unittest, necsus, sequtils

type
    A = object
        value: int
    B = object
        value: int
    C = object
        value: int

proc setup(spawn: Spawn[(A, B, C)]) =
    for i in 1..10:
        discard spawn((A(value: i), B(value: i), C(value: i)))

proc detacher(abc: Query[tuple[a: A, b: B, c: C]], detachBC: Detach[(B, C)], detachC: Detach[(C, )]) =
    for (eid, comps) in abc:
        if comps.a.value <= 3:
            detachBC(eid)
        elif comps.a.value <= 6:
            detachC(eid)

proc assertDetached(abc: Query[(A, B, C)], ab: Query[(A, B)], a: Query[(A, )]) =
    check(toSeq(abc.components).len == 4)
    check(toSeq(ab.components).len == 7)
    check(toSeq(a.components).len == 10)

proc reattach(query: Query[(A, )], attach: Attach[(B, C)]) =
    for (eid, _) in query:
        eid.attach((B(value: 1), C(value: 1)))

proc assertReattached(abc: Query[(A, B, C)]) =
    check(toSeq(abc.components).len == 10)

proc runner(tick: proc(): void) =
    tick()

proc testDetach() {.necsus(
    runner,
    [~setup],
    [~detacher, ~assertDetached, ~reattach, ~assertReattached],
    conf = newNecsusConf()
).}

test "Detaching components":
    testDetach()