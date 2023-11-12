import unittest, necsus/compiletime/archetypeBuilder, sequtils, sets

suite "Creating archetypes":
    test "Creating archetypes of values":

        var builder = newArchetypeBuilder[string]()
        builder.define([ "A" ])
        builder.define([ "A", "B" ])
        builder.define([ "A", "B" ])
        builder.define([ "A", "B", "C" ])
        let archetypes = builder.build()

        check(archetypes.toSeq.mapIt($it).toHashSet == [ "{A}", "{A, B}", "{A, B, C}" ].toHashSet)

    test "Allowing for attaching new components to existing archetypes":
        var builder = newArchetypeBuilder[string]()
        builder.define([ "A" ])
        builder.define([ "A", "B" ])

        builder.attachable([ "B", "C" ])
        builder.attachable([ "C", "D" ])
        let archetypes = builder.build()

        check(archetypes.toSeq.mapIt($it).toHashSet == toHashSet([
            "{A}", "{A, B, C}", "{A, C, D}", "{A, B, C, D}", "{A, B}"
        ]))

    test "Allowing for detaching new components to existing archetypes":
        var builder = newArchetypeBuilder[string]()
        builder.define([ "A" ])
        builder.define([ "A", "B" ])
        builder.define([ "A", "B", "C" ])
        builder.define([ "A", "B", "C", "D" ])

        builder.detachable([ "A" ])
        builder.detachable([ "B", "C" ])
        builder.detachable([ "C", "D" ])
        let archetypes = builder.build()

        check(archetypes.toSeq.mapIt($it).toHashSet == toHashSet([
            "{A}", "{A, D}", "{A, B, C}", "{B}", "{D}", "{B, C, D}", "{B, C}", "{A, B, C, D}", "{A, B}"
        ]))

    test "Require that the same archetype be added with elements in the same order":
        var builder = newArchetypeBuilder[string]()
        builder.define([ "A", "B", "C" ])
        builder.define([ "A", "B", "C" ])

        expect(UnsortedArchetype):
            builder.define([ "C", "A", "B" ])

        check(builder.build().toSeq.mapIt($it).toHashSet == [ "{A, B, C}" ].toHashSet)
