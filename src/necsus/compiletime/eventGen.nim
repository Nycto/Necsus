import macros, strutils, tables
import directiveSet, monoDirective, nimNode, commonVars, systemGen
import ../util/mailbox, ../runtime/[inbox, directives]

proc eventStorageIdent(event: MonoDirective | NimNode): NimNode =
    ## Returns the name of the identifier that holds the storage for an event
    when event is NimNode: ident(event.symbols.join("_") & "_storage")
    elif event is MonoDirective: eventStorageIdent(event.argType)

proc chooseInboxName(argName: NimNode, local: MonoDirective): string =
    argName.signatureHash & "_" & argName.strVal

proc inboxFields(name: string, dir: MonoDirective): seq[WorldField] = @[
    (name, nnkBracketExpr.newTree(bindSym("Mailbox"), dir.argType))
]

proc inboxSystemArg(name: string, dir: MonoDirective): NimNode =
    let storageIdent = name.ident
    let eventType = dir.argType
    return quote:
        newInbox[`eventType`](`appStateIdent`.`storageIdent`)

proc generateInbox(details: GenerateContext, arg: SystemArg, name: string, inbox: MonoDirective): NimNode =
    case details.hook
    of Early:
        let storageIdent = name.ident
        let eventType = inbox.argType
        return quote:
            `appStateIdent`.`storageIdent` = newMailbox[`eventType`](`appStateIdent`.`confIdent`.eventQueueSize)
    of AfterActiveCheck:
        let eventStore = name.ident
        return quote:
            clear(`appStateIdent`.`eventStore`)
    else:
        return newEmptyNode()

let inboxGenerator* {.compileTime.} = newGenerator(
    ident = "Inbox",
    interest = { Early, AfterActiveCheck },
    chooseName = chooseInboxName,
    generate = generateInbox,
    worldFields = inboxFields,
    systemArg = inboxSystemArg,
)

iterator inboxes(details: GenerateContext, outbox: MonoDirective): SystemArg =
    ## Yields the inboxes an outbox should write to
    if inboxGenerator in details.directives:
        for _, sysArg in details.directives[inboxGenerator]:
            if sysArg.monoDir.argType == outbox.argType:
                yield sysArg

proc outboxFields(name: string, dir: MonoDirective): seq[WorldField] =
    @[ (name, nnkBracketExpr.newTree(bindSym("Outbox"), dir.argType)) ]

proc generateOutbox(details: GenerateContext, arg: SystemArg, name: string, outbox: MonoDirective): NimNode =
    case details.hook
    of Standard:
        let event = "event".ident
        let procName = name.ident
        let eventType = outbox.argType

        var body = newStmtList()
        for sysArg in inboxes(details, outbox):
            let inboxIdent = details.nameOf(sysArg).ident
            body.add quote do:
                send[`eventType`](`appStateIdent`.`inboxIdent`, `event`)

        return quote:
            `appStateIdent`.`procName` = proc(`event`: sink `eventType`) = `body`
    else:
        return newEmptyNode()

let outboxGenerator* {.compileTime.} = newGenerator(
    ident = "Outbox",
    interest = { Standard },
    generate = generateOutbox,
    worldFields = outboxFields,
)