import LinearAlgebra

struct MyPoint
    x::Float16
    y::Float16
end
mutable struct Node
    position::MyPoint
    cost::Float16
    parent::Union{Node, Nothing}
end
struct Cluster
    position::MyPoint
    nodes::Vector{Node}
end
struct NodeClusters
    allNodes::Vector{Node}
    clusters::Vector{Cluster}
end

function NodeClusters_isinside(cluster::Cluster, node::Node)::Bool
    # TODO: update from normal grid like to dynamic grid
    return floor(node.position.x) == cluster.position.x && floor(node.position.y) == cluster.position.y
end

function findNodesNear(nodeCluster::NodeClusters, node::Node)::Vector{Node}
    # TODO: maybe implement neighbour radius like paper suggests?
    for cluster in nodeCluster.clusters
        if NodeClusters_isinside(cluster, node)
            if length(cluster.nodes) <= 1
                # return nodeCluster.allNodes
            end
            return cluster.nodes
        end
    end
    # return nodeCluster.allNodes
    return []
end

function NodeClusters_addNode(nodeCluster::NodeClusters, node::Node)
    push!(nodeCluster.allNodes, node)
    for cluster in nodeCluster.clusters
        if NodeClusters_isinside(cluster, node)
            push!(cluster.nodes, node)
            return
        end
    end
    # TODO: update from normal grid like to dynamic grid
    new_cluster_pos = MyPoint(floor(node.position.x), floor(node.position.y))
    new_cluster = Cluster(new_cluster_pos, [node])
    push!(nodeCluster.clusters, new_cluster)
end

function point_distance(p1::MyPoint, p2::MyPoint)
    return LinearAlgebra.norm([p1.x-p2.x, p1.y-p2.y])
end

function Node_get_closest_node(node::Node, nodeList::Vector{Node})
    """Returns (Node, Distance)"""
    res = (nothing, Inf)
    for other in nodeList
        dist = point_distance(node.position, other.position)
        if dist < res[2]
            res = (other, dist)
        end
    end
    return res
end

function eq1_random_sampling(x_0::Node, x_goal::Node; a=0.1, b=2)::MyPoint
    v_x = x_goal.position.x - x_0.position.x
    v_y = x_goal.position.y - x_0.position.y
    r = rand()
    if r > 1-a
        scaler = rand()
        res = MyPoint(x_0.position.x + scaler*v_x, x_0.position.y + scaler*v_y)
        return res
    end
    # elseif r <= (1-a)/b || !path_free(x_0, x_goal)
    # sampling from ellipsis is too complex right now and i dont feel like it :/
    # TODO: make ellipse where x_0 and x_goal as focal points, transverse and conjugate diameters equal to cbest and sq_rt(cbest^2 − cmin^2) 
    # cbest is the length of the path from x_0 to x_goal, and cmin is norm(x_0 −x_goal)
    # for now sample a point in a box from x_0 to x_goal
    res = MyPoint(rand()*450, rand()*450)
    return res
end

function has_LOS(scene::Any, p1::MyPoint, p2::MyPoint)
    # TODO: reimplement this in abstract way
    # return true
    p1 = Point(p1.x, p1.y)
    p2 = Point(p2.x, p2.y)
    res = line_is_obstructed(scene, p1, p2)
    # println(p1, " ", p2, " ", !res)
    return !res
end

function alg3_add_node_to_tree(x_new::Node, x_closest::Node, set_near::Vector{Node}, scene::Any)
    x_min = x_closest
    c_min = x_closest.cost + point_distance(x_closest.position, x_new.position)
    for x_near in set_near
        c_new = x_near.cost + point_distance(x_near.position, x_new.position)
        if c_new < c_min && has_LOS(scene, x_near.position, x_new.position)
            x_min = x_near
            c_min = c_new
        end
    end
    x_new.parent = x_min
    x_new.cost = c_min
end

function alg3_add_node_to_tree(x_new::Node, X_si::NodeClusters, scene::Any)
    x_min = nothing
    c_min = Inf
    for cluster in X_si.clusters
        for x_near in cluster.nodes
            c_new = x_near.cost + point_distance(x_near.position, x_new.position)
            if c_new < c_min && has_LOS(scene, x_near.position, x_new.position)
                x_min = x_near
                c_min = c_new
            end
        end
    end
    x_new.parent = x_min
    x_new.cost = c_min
end

function alg4_rewire_random_nodes(q_r::Vector{Node}, X_si::NodeClusters, scene::Any)
    """I think this is going through nodes in q_r and checking if a path exists shorter than its parent"""
    # TODO: maybe implement timeup for this function like the paper suggests
    while length(q_r) > 0
        x_r::Node = popfirst!(q_r)
        X_near::Vector{Node} = findNodesNear(X_si, x_r)
        for x_near in X_near
            c_old = x_near.cost
            c_new = x_r.cost + point_distance(x_r.position, x_near.position)
            if c_new < c_old && has_LOS(scene, x_r.position, x_near.position)
                x_near.parent = x_r
                push!(q_r, x_near)
            end
        end
    end
end

function alg5_rewire_from_tree_root(q_s::Vector{Node}, x_0::Node, X_si::NodeClusters, scene::Any)
    # TODO: maybe implement timeup for this function like the paper suggests
    q_s_pop_memory = Set()
    if length(q_s) == 0
        push!(q_s, x_0)
    end

    while length(q_s) != 0
        x_s = popfirst!(q_s)
        push!(q_s_pop_memory, x_s)
        X_near::Vector{Node} = findNodesNear(X_si, x_s)
        for x_near in X_near
            c_old = x_near.cost
            c_new = x_s.cost + point_distance(x_s.position, x_near.position)
            if c_new < c_old && has_LOS(scene, x_s.position, x_near.position)
                x_near.parent = x_s
            end
            if x_near ∉ q_s_pop_memory
                push!(q_s, x_near)
            end
        end
    end
end


function alg2_expansion_and_rewiring(scene::Any, x_0::Node, x_goal::Node, X_si::NodeClusters, q_r::Vector{Node}, q_s::Vector{Node}, k_max::Int, r_s::Int)
    newly_added_node = x_0
    x_rand = Node(eq1_random_sampling(x_0, x_goal), Inf, nothing)
    # println(x_rand.position)
    # TODO: is that not cluster to x_rand?
    # cluster_nodes = findNodesNear(X_si, x_0)
    # @assert length(cluster_nodes) > 0 "TODO NEED THIS? We always assume the node is in some cluster, so at least it should return itself"
    # x_closest, x_closest_dist = Node_get_closest_node(x_rand, cluster_nodes)
    x_closest, x_closest_dist = Node_get_closest_node(x_rand, X_si.allNodes)

    if has_LOS(scene, x_closest.position, x_rand.position)
        cluster_nodes = findNodesNear(X_si, x_rand)
        if length(cluster_nodes) < k_max || x_closest_dist > r_s
            NodeClusters_addNode(X_si, x_rand)
            # TODO need to redo cluster_nodes?
            # cluster_nodes = findNodesNear(X_si, x_rand)
            # alg3_add_node_to_tree(x_rand, x_closest, cluster_nodes, scene)
            alg3_add_node_to_tree(x_rand, X_si, scene)
            newly_added_node = x_rand
            pushfirst!(q_r, x_rand)
        else
            pushfirst!(q_r, x_closest)
        end
        alg4_rewire_random_nodes(q_r, X_si, scene)
    end
    alg5_rewire_from_tree_root(q_s, x_0, X_si, scene)
    return newly_added_node
end
