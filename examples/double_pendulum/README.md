## Double Pendulum Demo

The cart double-pendulum showcase lives in its own Julia environment under [examples/double_pendulum](examples/double_pendulum) so the visualization and simulation dependencies stay out of the main solver environment.

Instantiate the example environment once:

```bash
julia --project=examples/double_pendulum -e 'using Pkg; Pkg.instantiate()'
```

Run the real-time demo from the repository root:

```bash
julia --project=examples/double_pendulum examples/double_pendulum/simulation.jl
```

Useful flags:

```bash
julia --project=examples/double_pendulum examples/double_pendulum/simulation.jl --upright
julia --project=examples/double_pendulum examples/double_pendulum/simulation.jl --headless --no-realtime --duration=8
```

The default demo starts from a large-angle recovery state that hands off into the stabilizing MPC mode. Use `--upright` to exercise the local balance controller and solver directly from a near-upright condition.
