@testset "basic solver behavior" begin
    data = build_zero_problem()
    cache = setup_cache(data)
    x, u, tt = solve(cache, identity_prox!; max_iters=50)

    @test size(x) == (1, 2)
    @test size(u) == (1, 2)
    @test all(iszero, x)
    @test all(iszero, u)
    @test tt.converged
    @test tt.itns == 1
    @test tt.r_norm == 0.0
    @test tt.s_norm == 0.0
    @test tt.total_time >= 0.0
end
