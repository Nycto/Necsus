import world, entityId, ../util/blockstore

type
    ArchRow[Comps: tuple] = object
        ## A row of data stored about an entity that matches a specific archetype
        entityId: EntityId
        components: Comps

    ArchetypeStore*[Archs: enum, Comps: tuple] = ref object
        ## Stores a specific archetype shape
        archetype: Archs
        initialSize: int
        compStore: BlockStore[ArchRow[Comps]]

    ArchView*[ViewComps: tuple] = ref object
        ## An object able to iterate over an archetype using a specific view of the data
        buildIterator: proc(): iterator(slot: var ViewComps): EntityId
        length: proc(): uint

    NewArchSlot*[Comps: tuple] = distinct Entry[ArchRow[Comps]]

proc newArchetypeStore*[Archs: enum, Comps: tuple](
    archetype: Archs,
    initialSize: SomeInteger
): ArchetypeStore[Archs, Comps] =
    ## Creates a new storage block for an archetype
    ArchetypeStore[Archs, Comps](initialSize: initialSize.int, archetype: archetype)

proc archetype*[Archs: enum, Comps: tuple](store: ArchetypeStore[Archs, Comps]): Archs {.inline.} = store.archetype
    ## Accessor for the archetype of a store

proc newSlot*[Archs: enum, Comps: tuple](
    store: var ArchetypeStore[Archs, Comps],
    entityId: EntityId
): NewArchSlot[Comps] {.inline.} =
    ## Reserves a slot for storing a new component

    if store.compStore == nil:
        store.compStore = newBlockStore[ArchRow[Comps]](store.initialSize)

    let slot = store.compStore.reserve
    slot.value.entityId = entityId
    return NewArchSlot[Comps](slot)

proc index*[Comps: tuple](entry: NewArchSlot[Comps]): uint {.inline.} = Entry[ArchRow[Comps]](entry).index

proc setComp*[Comps: tuple](slot: NewArchSlot[Comps], comps: sink Comps): EntityId {.inline.} =
    ## Stores an entity and its components into this slot
    let entry = Entry[ArchRow[Comps]](slot)
    value(entry).components = comps
    commit(entry)
    return value(entry).entityId

proc asView*[Archs: enum, ArchetypeComps: tuple, ViewComps: tuple](
    input: ArchetypeStore[Archs, ArchetypeComps],
    convert: proc (input: ptr ArchetypeComps): ViewComps
): ArchView[ViewComps] =
    ## Creates an iterable view into this component that uses the given converter
    proc buildIter(): auto =
        return iterator(comps: var ViewComps): EntityId =
            if input.compStore != nil:
                for row in items(input.compStore):
                    comps = convert(addr row.components)
                    yield row.entityId
    proc getLength(): uint =
        return if input.compStore != nil: input.compStore.len else: 0
    return ArchView[ViewComps](buildIterator: buildIter, length: getLength)

iterator items*[ViewComps: tuple](view: ArchView[ViewComps], comps: var ViewComps): EntityId {.inline.} =
    ## Iterates over the components in a view
    let instance = view.buildIterator()
    for entityId in instance(comps):
        yield entityId

proc len*[ViewComps: tuple](view: ArchView[ViewComps]): uint {.inline.} =
    ## Iterates over the components in a view
    view.length()

proc getComps*[Archs: enum, Comps: tuple](store: var ArchetypeStore[Archs, Comps], index: uint): ptr Comps =
    ## Return the components for an archetype
    unsafeAddr store.compStore[index].components

proc del*(store: var ArchetypeStore, index: uint) =
    ## Return the components for an archetype
    discard store.compStore.del(index)

proc moveEntity*[Archs: enum, FromArch: tuple, ToArch: tuple](
    world: var World[Archs],
    entityIndex: ptr EntityIndex[Archs],
    fromArch: var ArchetypeStore[Archs, FromArch],
    toArch: var ArchetypeStore[Archs, ToArch],
    convert: proc (input: sink FromArch): ToArch
) {.inline.} =
    ## Moves the components for an entity from one archetype to another
    let deleted = fromArch.compStore.del(entityIndex.archetypeIndex)
    let existing = deleted.components
    let newSlot = newSlot[Archs, ToArch](toArch, entityIndex.entityId)
    discard setComp(newSlot, convert(existing))
    entityIndex.archetype = toArch.archetype
    entityIndex.archetypeIndex = newSlot.index
