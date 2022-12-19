
function simpleagent1_make_args(scene::Scene,
        dt::Float64,
        num_ticks::Int,
        planner_params::PlannerParams
        ; noise::Float64=3.0, angle_beta::Float64=1.0, 
        pre_comp_rrt::Union{Vector{RRT},Nothing}=nothing,
        obstacle_outlier::Float64=0.0)
    Dict(
    :scene => scene, 
    :dt => dt, 
    :num_ticks => num_ticks, 
    :planner_params => planner_params, 

    :meas_noise => noise,
    :angle_beta => angle_beta,
    :pre_comp_rrt => pre_comp_rrt,
    :obstacle_outlier => obstacle_outlier,
    )
end

@gen function simpleagent1_model(agent_args)
    result = Dict()
    start_x ~ uniform(0, 450)
    start_y ~ uniform(0, 450)
    start = Point(start_x, start_y)

    # pick a shape at random, move away from its center by some random angle and set that as the destination
    scene = agent_args[:scene]
    obstacle_outlier ~ bernoulli(agent_args[:obstacle_outlier])
    if obstacle_outlier
        dest_x ~ uniform(0, 450)
        dest_y ~ uniform(0, 450)
        dest = Point(dest_x, dest_y)
    else
        dest_shape ~ Gen.categorical([1/length(scene.obstacles) for n in scene.obstacles])
        angle_noise ~ beta(agent_args[:angle_beta], agent_args[:angle_beta])
        mean_angle = utils_angle_between_obstacle_point(scene.obstacles[dest_shape], start_x, start_y)
        dest_angle = mean_angle + 2*pi*(angle_noise-0.5)
        dest = utils_obstacle_touch_point(scene.obstacles[dest_shape], dest_angle)
    end

    if isnothing(agent_args[:pre_comp_rrt])  # no pre computed trees, compute new one
        maybe_path = plan_path(start, dest, agent_args[:scene], agent_args[:planner_params])
    else
        tree_choice = Gen.categorical(vec([1/length(agent_args[:pre_comp_rrt]) for n in agent_args[:pre_comp_rrt]]))
        maybe_path = tree_refined_dest_path(agent_args[:pre_comp_rrt][tree_choice], dest, agent_args[:scene], agent_args[:planner_params])
    end
    planning_failed = maybe_path === nothing

    speed ~ uniform(0, 100)

    if planning_failed   
    locations = fill(start, agent_args[:num_ticks])
    else   
    locations = walk_path(maybe_path, speed, agent_args[:dt], agent_args[:num_ticks])
    end

    noise = agent_args[:meas_noise]
    for (i, point) in enumerate(locations)
    x = {:meas => (i, :x)} ~ normal(point.x, noise)
    y = {:meas => (i, :y)} ~ normal(point.y, noise)
    end

    result[:planning_failed] = planning_failed
    result[:maybe_path] = maybe_path
    result[:dest] = Point(dest.x, dest.y)

    return result
end