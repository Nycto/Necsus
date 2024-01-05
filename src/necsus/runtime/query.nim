import entityId, options

type
    QueryItem*[Comps: tuple] = tuple[entityId: EntityId, components: Comps]
        ## An individual value yielded by a query. Where `Comps` is a tuple of the components to fetch in
        ## this query

    QueryIterator*[Comps: tuple] = iterator(slot: var Comps): EntityId
        ## An iterator over a query

    RawQuery*[Comps: tuple] = object
        ## Allows systems to query for entities with specific components. Where `Comps` is a tuple of
        ## the components to fetch in this query.
        getLen: proc: uint
        getIterator: proc: QueryIterator[Comps]

    Query*[Comps: tuple] = ptr RawQuery[Comps]
        ## Allows systems to query for entities with specific components. Where `Comps` is a tuple of
        ## the components to fetch in this query.

    Not*[Comps] = distinct int8
        ## A query flag that indicates a component should be excluded from a query. Where `Comps` is
        ## the single component that should be excluded.

proc newQuery*[Comps: tuple](getLen: proc(): uint, getIterator: proc(): QueryIterator[Comps]): RawQuery[Comps] =
    RawQuery[Comps](getLen: getLen, getIterator: getIterator)

iterator pairs*[Comps: tuple](query: Query[Comps]): QueryItem[Comps] =
    ## Iterates through the entities in a query
    let iter = query.getIterator()
    var slot: Comps
    for eid in iter(slot):
        yield (eid, slot)

iterator items*[Comps: tuple](query: Query[Comps]): Comps =
    ## Iterates through the entities in a query
    for (_, components) in query.pairs: yield components

proc len*[Comps: tuple](query: Query[Comps]): uint =
    ## Returns the number of entities in this query
    query.getLen()

proc single*[Comps: tuple](query: Query[Comps]): Option[Comps] =
    ## Returns a single element from a query
    for comps in query:
        return some(comps)
