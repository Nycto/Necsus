import entitySet, entity, queryFilter, packedIntTable

type
    QueryItem*[T: tuple] = tuple[entityId: EntityId, components: T]
        ## An individual value yielded by a query

    Query*[T: tuple] = proc(): iterator(): QueryItem[T]
        ## Allows systems to query for entities with specific components

    QueryStorage*[C: enum, M: tuple] {.byref.} = object
        ## Storage container for query data
        filter: QueryFilter[C]
        members: PackedIntTable[M]
        deleted: EntitySet

proc newQueryStorage*[C, M](initialSize: int, filter: QueryFilter[C]): QueryStorage[C, M] =
    ## Creates a storage container for query data
    QueryStorage[C, M](filter: filter, members: newPackedIntTable[M](initialSize), deleted: newEntitySet())

proc addToQuery*[C, M](storage: var QueryStorage[C, M], entityId: EntityId, componentRefs: sink M) =
    ## Registers an entity with this query
    storage.members[entityId.int32] = componentRefs
    storage.deleted -= entityId

proc removeFromQuery*[C, M](storage: var QueryStorage[C, M], entityId: EntityId) =
    ## Removes an entity from this query
    storage.deleted += entityId

proc shouldAdd*[C, M](storage: var QueryStorage[C, M], entityId: EntityId, components: set[C]): bool =
    ## Returns whether an entity should be added to this query
    storage.filter.evaluate(components) and ((entityId.int32 notin storage.members) or (entityId in storage.deleted))

iterator values*[C, M](storage: var QueryStorage[C, M]): (EntityId, M) =
    ## Yields the component pointers in a storage object
    for (eid, components) in storage.members.pairs:
        let entity = EntityId(eid)
        if entity notin storage.deleted:
            yield (entity, components)

iterator pairs*[T: tuple](query: Query[T]): QueryItem[T] =
    ## Iterates through the entities in a query
    let iter = query()
    for pair in iter(): yield pair

iterator items*[T: tuple](query: Query[T]): T =
    ## Iterates through the entities in a query
    for (_, components) in query.pairs: yield components

proc finalizeDeletes*[C, M](query: var QueryStorage[C, M]) =
    ## Removes any entities that are pending deletion from this query
    for entityId in items(query.deleted):
        query.members.del(entityId.int32)
    query.deleted.clear()