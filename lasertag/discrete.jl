using LaserTag
using Plots
using POMDPToolbox
using Reel
using ProgressMeter
using PmapProgressMeter
using ParticleFilters
using ContinuousPOMDPTreeSearchExperiments
using Plots
using QMDP
using JLD
# using DESPOT
using BasicPOMCP
using ARDESPOT

file_contents = readstring(@__FILE__())

@everywhere begin
    using POMDPs
    using POMDPToolbox
    using ContinuousPOMDPTreeSearchExperiments
    using DiscreteValueIteration
    using ParticleFilters
    using POMCPOW
    using LaserTag
    using QMDP
    # using DESPOT
    using BasicPOMCP
    using ARDESPOT

    N = 1000
    n = 1_000_000
    P = typeof(gen_lasertag(rng=MersenneTwister(18)))

    solvers = Dict{String, Union{Policy, Solver}}(

        #=
        "pomcpow" => begin
            # ro = MoveTowards()
            solver = POMCPOWSolver(tree_queries=1_000_000_000, #500_000
                                   criterion=MaxUCB(60.0),
                                   final_criterion=MaxTries(),
                                   max_depth=90,
                                   max_time=1.0,
                                   enable_action_pw=false,
                                   # k_action=4.0,
                                   # alpha_action=1/8,
                                   k_observation=2.0,
                                   alpha_observation=1/20,
                                   estimate_value=FOValue(ValueIterationSolver()),
                                   check_repeat_act=false,
                                   check_repeat_obs=false,
                                   init_N=InevitableInit(),
                                   init_V=InevitableInit(),
                                   rng=MersenneTwister(13)
                                  )
            solver
        end,
        =#

        # "move_towards_sampled" => MoveTowardsSampled(MersenneTwister(17)),

        # "ml" => OptimalMLSolver(ValueIterationSolver()),

        # "be" => BestExpectedSolver(ValueIterationSolver()),

        # "random" => RandomSolver(rng=MersenneTwister(4)),

        "despot" => begin
            DESPOTSolver(lambda=0.01,
                         K=500,
                         max_trials=1_000_000,
                         T_max=1.0,
                         bounds=LaserBounds{P}(),
                         default_action=NoGapTag(),
                         bounds_warnings=false,
                         random_source=MemorizingSource(500, 90, MersenneTwister(5), min_reserve=10)
                         rng=MersenneTwister(4))
        end,

        # "qmdp" => QMDPSolver(max_iterations=1000),

        #=
        "pomcp" => POMCPSolver(tree_queries=n,
                                   c=20.0,
                                   max_depth=100,
                                   estimate_value=FOValue(ValueIterationSolver()),
                                   rng=MersenneTwister(13)
                                  )
        =#
    )
end

@show N
@show solvers["despot"].lambda
@show solvers["despot"].K
@show solvers["despot"].T_max
@show solvers["pomcpow"].max_time

rdict = Dict{String, Any}()
for (k,sol) in solvers
    prog = Progress(N, desc="Simulating...")
    @show k 
    rewards = pmap(prog, 1:N) do i
    # rewards = map(1:N) do i
        pomdp = gen_lasertag(rng=MersenneTwister(i+700_000))
        if isa(sol,Solver)
            p = solve(deepcopy(sol), pomdp)
        else
            p = sol
        end
        hr = HistoryRecorder(max_steps=100, rng=MersenneTwister(i))
        up_rng = MersenneTwister(i+140_000)
        up = ObsAdaptiveParticleFilter(deepcopy(pomdp), LowVarianceResampler(100_000), 0.05, up_rng)
        hist = simulate(hr, pomdp, p, up)
        discounted_reward(hist)
    end
    @show mean(rewards)
    @show std(rewards)/sqrt(N)
    rdict[k] = rewards
end

filename = Pkg.dir("ContinuousPOMDPTreeSearchExperiments", "data", "laser_discrete_run_$(Dates.format(now(), "E_d_u_HH_MM")).jld")
println("saving to $filename...")
@save(filename, solvers, rdict, file_contents)
println("done.")
