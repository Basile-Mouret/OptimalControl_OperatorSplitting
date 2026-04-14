@testset "cache and warm starts" begin
    @testset "repeated solve on same cache warm starts" begin
        data = build_box_constrained_problem()
        cache = setup_cache(data)

        x1, u1, tt1 = solve(cache, box_prox!; max_iters=3000)
        x2, u2, tt2 = solve(cache, box_prox!; max_iters=3000)

        @test tt1.converged
        @test tt2.converged
        @test max_abs_diff(x1, x2) <= 1e-10
        @test max_abs_diff(u1, u2) <= 1e-10
        @test tt2.itns <= tt1.itns
        @test tt2.itns <= 2
    end

    @testset "cache reuse stays correct when only linear data changes" begin
        data = build_stage_varying_unconstrained_problem()
        cache = setup_cache(data)

        solve(cache, identity_prox!; max_iters=3000)
        perturb_linear_terms!(data)

        x_reuse, u_reuse, tt_reuse = solve(cache, identity_prox!; max_iters=3000)

        fresh_cache = setup_cache(data)
        x_fresh, u_fresh, tt_fresh = solve(fresh_cache, identity_prox!; max_iters=3000)

        @test tt_reuse.converged
        @test tt_fresh.converged
        @test max_abs_diff(x_reuse, x_fresh) <= 1e-7
        @test max_abs_diff(u_reuse, u_fresh) <= 1e-7
    end
end
