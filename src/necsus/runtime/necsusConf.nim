import math

type
    NecsusConf* = ref object
        ## Used to configure
        entitySize*: int
        componentSize*: int
        eventQueueSize*: int
        getTime*: proc(): float
        log*: proc(message: string): void

proc logEcho(message: string) = echo message

proc newNecsusConf*(
    getTime: proc(): float,
    log: proc(message: string): void,
    entitySize: int,
    componentSize: int,
    eventQueueSize: int,
): NecsusConf =
    ## Create a necsus configuration
    NecsusConf(
        entitySize: entitySize,
        componentSize: componentSize,
        eventQueueSize: eventQueueSize,
        getTime: getTime,
        log: log,
    )

proc newNecsusConf*(getTime: proc(): float, log: proc(message: string): void): NecsusConf =
    ## Create a necsus configuration
    NecsusConf(entitySize: 1_000, componentSize: 400, eventQueueSize: 100, getTime: getTime, log: log)

when defined(js) or defined(osx) or defined(windows) or defined(posix):
    import std/times

    proc newNecsusConf*(
        entitySize: int = 1_000,
        componentSize: int = ceilDiv(entitySize, 3),
        eventQueueSize: int = ceilDiv(entitySize, 10)
    ): NecsusConf =
        ## Create a necsus configuration
        newNecsusConf(epochTime, logEcho, entitySize, componentSize, eventQueueSize)
