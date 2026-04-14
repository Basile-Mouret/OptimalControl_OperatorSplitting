@testset "reference solutions" begin
    @testset "unconstrained stage-varying problem" begin
        data = build_stage_varying_unconstrained_problem()
        cache = setup_cache(data)

        x, u, tt = solve(cache, identity_prox!; max_iters=3000)
        x_ref, u_ref = solve_reference_with_ipopt(data)

        @test tt.converged
        @test max_abs_diff(x, x_ref) <= 1e-4
        @test max_abs_diff(u, u_ref) <= 1e-4
    end

    @testset "box-constrained problem" begin
        data = build_box_constrained_problem()
        cache = setup_cache(data)

        x, u, tt = solve(cache, box_prox!; max_iters=3000)
        x_ref, u_ref = solve_reference_with_ipopt(data; u_lower=-1.0, u_upper=1.0)

        @test tt.converged
        @test max_abs_diff(x, x_ref) <= 1e-4
        @test max_abs_diff(u, u_ref) <= 1e-4
    end
end
