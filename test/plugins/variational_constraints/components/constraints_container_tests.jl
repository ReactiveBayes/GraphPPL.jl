@testitem "push!(::Constraints, ::Constraint)" begin
    using Distributions
    import GraphPPL:
        Constraints,
        FactorizationConstraint,
        FactorizationConstraintEntry,
        MarginalFormConstraint,
        MessageFormConstraint,
        SpecificSubModelConstraints,
        GeneralSubModelConstraints,
        IndexedVariable,
        FactorID

    # Test 1: Test push! with FactorizationConstraint
    constraints = Constraints()
    constraint = FactorizationConstraint(
        (IndexedVariable(:x, nothing), IndexedVariable(:y, nothing)),
        (FactorizationConstraintEntry((IndexedVariable(:x, nothing), IndexedVariable(:y, nothing)),),)
    )
    push!(constraints, constraint)
    @test_throws ErrorException push!(constraints, constraint)
    constraint = FactorizationConstraint(
        (IndexedVariable(:x, 1), IndexedVariable(:y, 1)),
        (FactorizationConstraintEntry((IndexedVariable(:x, nothing), IndexedVariable(:y, nothing))),)
    )
    push!(constraints, constraint)
    @test_throws ErrorException push!(constraints, constraint)
    constraint = FactorizationConstraint(
        (IndexedVariable(:y, nothing), IndexedVariable(:x, nothing)),
        (FactorizationConstraintEntry((IndexedVariable(:x, nothing), IndexedVariable(:y, nothing))),)
    )
    @test_throws ErrorException push!(constraints, constraint)

    # Test 2: Test push! with MarginalFormConstraint
    constraint = MarginalFormConstraint(IndexedVariable(:x, nothing), Normal)
    push!(constraints, constraint)
    @test_throws ErrorException push!(constraints, constraint)
    constraint = MarginalFormConstraint((IndexedVariable(:x, nothing), IndexedVariable(:y, nothing)), Normal)
    push!(constraints, constraint)
    @test_throws ErrorException push!(constraints, constraint)
    constraint = MarginalFormConstraint(IndexedVariable(:x, 1), Normal)
    push!(constraints, constraint)
    @test_throws ErrorException push!(constraints, constraint)
    constraint = MarginalFormConstraint([IndexedVariable(:x, 1), IndexedVariable(:y, 1)], Normal)
    push!(constraints, constraint)
    @test_throws ErrorException push!(constraints, constraint)

    # Test 3: Test push! with MessageFormConstraint
    constraint = MessageFormConstraint(IndexedVariable(:x, nothing), Normal)
    push!(constraints, constraint)
    @test_throws ErrorException push!(constraints, constraint)
    constraint = MessageFormConstraint(IndexedVariable(:x, 2), Normal)
    push!(constraints, constraint)
    @test_throws ErrorException push!(constraints, constraint)

    # Test 4: Test push! with SpecificSubModelConstraints
    constraint = SpecificSubModelConstraints(FactorID(sum, 3), Constraints())
    push!(constraints, constraint)
    @test_throws ErrorException push!(constraints, constraint)

    # Test 5: Test push! with GeneralSubModelConstraints
    constraint = GeneralSubModelConstraints(sum, Constraints())
    push!(constraints, constraint)
    @test_throws ErrorException push!(constraints, constraint)
end

@testitem "push!(::SubModelConstraints, c::Constraint)" setup = [TestUtils] begin
    using Distributions
    import GraphPPL:
        Constraint,
        GeneralSubModelConstraints,
        SpecificSubModelConstraints,
        FactorizationConstraint,
        FactorizationConstraintEntry,
        MarginalFormConstraint,
        MessageFormConstraint,
        getconstraint,
        Constraints,
        IndexedVariable

    # Test 1: Test push! with FactorizationConstraint
    constraints = GeneralSubModelConstraints(TestUtils.gcv)
    constraint = FactorizationConstraint(
        (IndexedVariable(:x, nothing), IndexedVariable(:y, nothing)),
        (FactorizationConstraintEntry((IndexedVariable(:x, nothing), IndexedVariable(:y, nothing))),)
    )
    push!(constraints, constraint)
    @test getconstraint(constraints) == Constraints([
        FactorizationConstraint(
            (IndexedVariable(:x, nothing), IndexedVariable(:y, nothing)),
            (FactorizationConstraintEntry((IndexedVariable(:x, nothing), IndexedVariable(:y, nothing)),),)
        )
    ],)
    @test_throws MethodError push!(constraints, "string")

    # Test 2: Test push! with MarginalFormConstraint
    constraints = GeneralSubModelConstraints(TestUtils.gcv)
    constraint = MarginalFormConstraint(IndexedVariable(:x, nothing), Normal)
    push!(constraints, constraint)
    @test getconstraint(constraints) == Constraints([MarginalFormConstraint(IndexedVariable(:x, nothing), Normal)],)
    @test_throws MethodError push!(constraints, "string")

    # Test 3: Test push! with MessageFormConstraint
    constraints = GeneralSubModelConstraints(TestUtils.gcv)
    constraint = MessageFormConstraint(IndexedVariable(:x, nothing), Normal)
    push!(constraints, constraint)
    @test getconstraint(constraints) == Constraints([MessageFormConstraint(IndexedVariable(:x, nothing), Normal)],)
    @test_throws MethodError push!(constraints, "string")

    # Test 4: Test push! with SpecificSubModelConstraints
    constraints = SpecificSubModelConstraints(GraphPPL.FactorID(TestUtils.gcv, 3))
    constraint = FactorizationConstraint(
        (IndexedVariable(:x, nothing), IndexedVariable(:y, nothing)),
        (FactorizationConstraintEntry((IndexedVariable(:x, nothing), IndexedVariable(:y, nothing))),)
    )
    push!(constraints, constraint)
    @test getconstraint(constraints) == Constraints([
        FactorizationConstraint(
            (IndexedVariable(:x, nothing), IndexedVariable(:y, nothing)),
            (FactorizationConstraintEntry((IndexedVariable(:x, nothing), IndexedVariable(:y, nothing)),),)
        )
    ],)
    @test_throws MethodError push!(constraints, "string")

    # Test 5: Test push! with MarginalFormConstraint
    constraints = GeneralSubModelConstraints(TestUtils.gcv)
    constraint = MarginalFormConstraint(IndexedVariable(:x, nothing), Normal)
    push!(constraints, constraint)
    @test getconstraint(constraints) == Constraints([MarginalFormConstraint(IndexedVariable(:x, nothing), Normal)],)
    @test_throws MethodError push!(constraints, "string")

    # Test 6: Test push! with MessageFormConstraint
    constraints = GeneralSubModelConstraints(TestUtils.gcv)
    constraint = MessageFormConstraint(IndexedVariable(:x, nothing), Normal)
    push!(constraints, constraint)
    @test getconstraint(constraints) == Constraints([MessageFormConstraint(IndexedVariable(:x, nothing), Normal)],)
    @test_throws MethodError push!(constraints, "string")
end