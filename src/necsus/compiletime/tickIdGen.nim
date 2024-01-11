import macros
import commonVars, systemGen, ../runtime/directives

let tickId {.compileTime.} = ident("tickId")
let getTickId {.compileTime.} = ident("getTickId")

proc fields(name: string): seq[WorldField] = @[ (tickId.strVal, ident("uint")), (getTickId.strVal, bindSym("TickId")) ]

proc sysArg(name: string): NimNode =
    return quote:
        `appStateIdent`.`getTickId`

proc generate(details: GenerateContext, arg: SystemArg, name: string): NimNode =
    case details.hook
    of Standard:
        return quote:
            `appStateIdent`.`getTickId` = proc(): auto = `appStateIdent`.`tickId`
    of LoopStart:
        return quote:
            `appStateIdent`.`tickId` += 1
    else:
        return newEmptyNode()

let tickIdGenerator* {.compileTime.} = newGenerator(
    ident = "TickId",
    interest = { LoopStart, Standard },
    generate = generate,
    worldFields = fields,
    systemArg = sysArg,
)
