import unittest, necsus

var ranSetup = false
var ranTick = false
var ranTeardown = false

proc setup() =
    ranSetup = true

proc tick() =
    ranTick = true

proc teardown() =
    ranTeardown = true

proc runner(tick: proc(): void) =
    tick()

proc myApp() {.necsus(runner, [~setup], [~tick], [~teardown], conf = newNecsusConf()).}

test "System phases should be executed":
    myApp()
    check(ranSetup)
    check(ranTick)
    check(ranTeardown)