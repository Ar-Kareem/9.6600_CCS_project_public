

function utils_get_obstacle(obj)
    if obj["shape"] == "square" || obj["shape"] == "triangle"
        vertices = Vector{Point}(undef, length(obj["corners"]))
        for (i, corner) in enumerate(obj["corners"])
            vertices[i] = Point(corner["x"], corner["y"])
        end
        return Obstacle(vertices, obj["color"], obj["size"])
    else
        @assert false "Unknown object shape: "*obj["shape"]
    end
end

function utils_scene_from_playerdata(playerdata; VERBOSE=true)
    if "map" ∉ keys(playerdata)
        VERBOSE && println("Map not found in player data!")
        return nothing
    end
    x, y = playerdata["map"]["xdim"], playerdata["map"]["ydim"]
    VERBOSE && println("scene size: ", x, " ", y)
    scene = Scene(xmin=0, xmax=x, ymin=0, ymax=y)
    for obj in playerdata["map"]["objects"]
        add_obstacle!(scene, utils_get_obstacle(obj))
    end
    return scene
end


function utils_print_survey_file(filename)
    res = JSON.parsefile(filename);

    if res[1]["role"] == "STUDENT"
        res = [res[2], res[1]]
    end
    println("---------")
    for feedback in res
        println("--- Role: ", feedback["role"], " | Done:", feedback["done"])
        if "observations" in keys(feedback)
            println("--- Feedback: ", feedback["observations"]["feedback"])
        end
        if "guess" in keys(feedback)
            println("Guess: ", feedback["guess"]["feedback"])
        end
        println("--- New signs count ", length(feedback["newSigns"]))
        for (k, v) in feedback["newSigns"]
            println("   | New sign #", k, " | Comment: ", v["comment"])
            vb64 = v["base64"][length("data:image/png;base64,")+1:end]
            v = Base64.base64decode(vb64)
            png = Luxor.readpng(IOBuffer(v))
            display(png)
        end
        if "usedOldSigns" in keys(feedback)
            println("--- Old sign keys: ", keys(feedback["usedOldSigns"]))
        end
        println("---------")
    end
end

function utils_strip_trajectory(trajectory; epsilon=1)
    epsilon = epsilon^2
    result::Vector{Point} = [trajectory[1], ]
    last_p = result[end]
    for p in trajectory
        if (last_p.x - p.x)^2 + (last_p.y - p.y)^2 > epsilon
            push!(result, p)
            last_p = p
        end
    end
    return result
end

function utils_obstacle_touch_point(obstacle, angle)
    xs = [i.x for i in obstacle.vertices]
    ys = [i.y for i in obstacle.vertices]
    midx, midy = sum(xs)/length(xs), sum(ys)/length(ys)
    eps = obstacle.size=="big" ? 20 : (obstacle.size=="small" ? 10 : 0)
    touch_point = Point(midx+eps*cos(angle), midy+eps*sin(angle))
    return touch_point
end

function utils_angle_between_obstacle_point(obstacle, x, y)
    xs = [i.x for i in obstacle.vertices]
    ys = [i.y for i in obstacle.vertices]
    midx, midy = sum(xs)/length(xs), sum(ys)/length(ys)
    angle = atan((midy-y)/(midx-x))
    if (x <= midx)
        angle += pi;
    else
        if (y < midy)
            angle += 2*pi;
        end
    end
    return angle
end;

function utils_get_obs_labels(scene)
    labels = zeros(1, 0)
    c = Dict()
    for o in scene.obstacles
        shape = length(o.vertices)==4 ? "square" : "triangle" 
        name = o.size*" "*o.color*" "*shape
        if name in keys(c)
            c[name] = c[name] + 1
            name = name*" "*string(c[name])
        else
            c[name] = 1
        end
        labels = hcat(labels, [name])
    end
    return labels
end