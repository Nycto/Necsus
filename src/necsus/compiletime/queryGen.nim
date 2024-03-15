import tables, macros
import tupleDirective, archetype, componentDef, tools, systemGen, archetypeBuilder, commonVars
import ../runtime/[archetypeStore, query], ../util/bits

iterator selectArchetypes(details: GenerateContext, query: TupleDirective): Archetype[ComponentDef] =
    ## Iterates through the archetypes that contribute to a query
    for archetype in details.archetypes:
        if archetype.bitset.matches(query.filter):
            yield archetype

let slot {.compileTime.} = ident("slot")
let entry {.compileTime.} = ident("entry")
let iter {.compileTime.} = ident("iter")
let eid {.compileTime.} = ident("eid")

proc walkArchetypes(
    details: GenerateContext,
    name: string,
    query: TupleDirective,
    queryTupleType: NimNode,
): (NimNode, NimNode) =
    ## Creates the views that bind an archetype to a query
    var lenCalculation = newLit(0'u)
    var nextEntityBody = nnkCaseStmt.newTree(newDotExpr(iter, "continuationIdx".ident))

    var index = 0
    for archetype in details.selectArchetypes(query):
        let archetypeIdent = archetype.ident
        let tupleCopy = newDotExpr(entry, ident("components")).copyTuple(archetype, query)

        lenCalculation = quote do:
            `lenCalculation` + len(`appStateIdent`.`archetypeIdent`)

        let nextBody = quote do:
            var `entry` = `appStateIdent`.`archetypeIdent`.next(`iter`.iter)
            if `entry` != nil:
                `eid`= `entry`.entityId
                `slot` = `tupleCopy`
                result = ActiveIter

        nextEntityBody.add nnkOfBranch.newTree(newLit(index), nextBody)
        index += 1

    nextEntityBody.add nnkElse.newTree quote do:
        result = DoneIter

    return (lenCalculation, nextEntityBody)

proc worldFields(name: string, dir: TupleDirective): seq[WorldField] =
    @[ (name, nnkBracketExpr.newTree(bindSym("RawQuery"), dir.asTupleType)) ]


proc systemArg(queryType: NimNode, name: string, dir: TupleDirective): NimNode =
    let nameIdent = name.ident
    let tupleType = dir.args.asTupleType
    return quote:
        `queryType`[`tupleType`](addr `appStateIdent`.`nameIdent`)

proc querySystemArg(name: string, dir: TupleDirective): NimNode = systemArg(bindSym("Query"), name, dir)

proc fullQuerySystemArg(name: string, dir: TupleDirective): NimNode = systemArg(bindSym("FullQuery"), name, dir)

let appStatePtr {.compileTime.} = ident("appStatePtr")

proc generate(details: GenerateContext, arg: SystemArg, name: string, dir: TupleDirective): NimNode =
    ## Generates the code for instantiating queries

    let queryTuple = dir.args.asTupleType
    let getLen = details.globalName(name & "_getLen")
    let nextEntity = details.globalName(name & "_nextEntity")

    case details.hook
    of GenerateHook.Outside:
        let appStateTypeName = details.appStateTypeName

        let (lenCalculation, nextEntityBody) = details.walkArchetypes(name, dir, queryTuple)

        return quote do:

            func `getLen`(`appStatePtr`: pointer): uint {.fastcall.} =
                let `appStateIdent` = cast[ptr `appStateTypeName`](`appStatePtr`)
                return `lenCalculation`

            func `nextEntity`(
                `iter`: var QueryIterator, `appStatePtr`: pointer, `eid`: var EntityId, `slot`: var `queryTuple`
            ): NextIterState {.gcsafe, raises: [], fastcall.} =
                let `appStateIdent` = cast[ptr `appStateTypeName`](`appStatePtr`)
                result = IncrementIter
                `nextEntityBody`

    of GenerateHook.Standard:
        let ident = name.ident
        return quote do:
            `appStateIdent`.`ident` = newQuery[`queryTuple`](addr `appStateIdent`, `getLen`, `nextEntity`)
    else:
        return newEmptyNode()

let queryGenerator* {.compileTime.} = newGenerator(
    ident = "Query",
    interest = { Standard, Outside },
    generate = generate,
    worldFields = worldFields,
    systemArg = querySystemArg,
)

let fullQueryGenerator* {.compileTime.} = newGenerator(
    ident = "FullQuery",
    interest = { Standard, Outside },
    generate = generate,
    worldFields = worldFields,
    systemArg = fullQuerySystemArg,
)

