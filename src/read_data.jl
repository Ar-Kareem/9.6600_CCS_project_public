
function readdata_get_comm_game_path()
    hostname = gethostname()
    if hostname == "Noors-MacBook-Pro.local"
        comm_game_path = "/Users/nooralmazroa/Documents/Computational Cognative Science/Project/rrt-human-echeng-psiturk/comm_game"
    elseif hostname == "Meshal-Laptop"
        comm_game_path = "C:\\Users\\Meshal\\Dropbox (MIT)\\# MIT CSE\\2022_Fall\\9.660\\rrt-human-echeng-psiturk\\comm_game"
    elseif hostname[length(hostname)-3:end] == "-MSI"
        comm_game_path = "M:\\MyFiles\\Classes\\Grad\\Cognitive Science Project\\rrt-human-echeng-psiturk\\comm_game"
    else
        println("NEW HOST NAME: ", hostname)
    end
end

function readdata_get_gen_quickstart_repo_path()
    #     PATH WHERE gen-quickstart FOLDER IS https://github.com/probcomp/gen-quickstart
    hostname = gethostname()
    if hostname == "Noors-MacBook-Pro.local"
        comm_game_path = "/Users/nooralmazroa/Documents/GitHub/gen-quickstart"
    elseif hostname == "Meshal-Laptop"
        comm_game_path = "C:\\Users\\Meshal\\Dropbox (MIT)\\# MIT CSE\\2022_Fall\\9.660\\gen-quickstart-master"
    elseif hostname[length(hostname)-3:end] == "-MSI"
        comm_game_path = "M:\\MyFiles\\Classes\\Grad\\Cognitive Science Project\\gen\\gen-quickstart"
    else
        println("NEW HOST NAME: ", hostname)
    end
end

function readdata_get_task_from_room(roomdir, memory; VERBOSE=true)
    room = readdir(roomdir, join=true)
    roomdict = JSON.parsefile(room[1])[1];
    res = JSON.parsefile(roomdir*"/"*memory);
    VERBOSE && println("pair: ", roomdict["player"], "-", roomdict["partner"])
    VERBOSE && println("Getting file:", memory)
    VERBOSE && println("Json length:", length(res), " | #Runs should be (n-2)/2 = ", (length(res)-2)/2)
    return res
end

function readdata_get_playerdata_from_task(taskdict, i; VERBOSE=true)
    # get the number key, dont know why its not consistent... look at line 484 in python_scripts/visualize/graphs.py
    mykeys = [i for i in keys(taskdict[i]) if i.∉(Ref(["session", "stage", "timestamp", "player"]))]
    @assert length(mykeys)==1 ("length not one. KEYS: "*join(mykeys, " "))
    # get the run data then arena values
    rundata = taskdict[i][mykeys[1]]
    arenavalues = rundata["arenaValues"]["data"]
    VERBOSE && println("Mode(TEACH/TEST): ", rundata["mode"])
    VERBOSE && println("role(TEACHER/STUDENT): ", rundata["role"])
    arenavalues["mode"] = rundata["mode"]
    arenavalues["role"] = rundata["role"]
    arenavalues["map_name"] = rundata["map"]
    return arenavalues
end


function readdata_visualize_memory(;roomnum, tasknum, hide_student=false, VERBOSE=true)
    x = tasknum <= 40 ? "2" : "4"
    y = string((tasknum-1) % 40 + 1)
    VERBOSE && println("room: "*roomnum)
    file_name = "memory_"*x*".1."*y*".json"
    room = readdata_get_comm_game_path() * "/python_scripts/visualize/pairs_data/room0000"*roomnum
    dict1 = readdata_get_task_from_room(room, file_name, VERBOSE=VERBOSE);
    
    playerdata = readdata_get_playerdata_from_task(dict1, 1, VERBOSE=false);
    VERBOSE && println("scene size: ", playerdata["map"]["xdim"], " ", playerdata["map"]["ydim"])
    mapdata = JSON.parsefile(readdata_get_comm_game_path() * "/nodegame-v6.2.4-dev/games_available/comm-game/public/" * playerdata["map_name"])
    VERBOSE && println("--- Map | Level: ", mapdata["level"], " Dist: ", mapdata["dist"])
    VERBOSE && println("        | Fol: ", mapdata["fol"])
    VERBOSE && println("        | NatLang: ", mapdata["natlang"])
    
    VERBOSE && utils_print_survey_file(room*"/memory_"*x*".2."*y*".json")
    
    runcount = Integer(floor((length(dict1)-2)/2))
    visualize_grid(1:runcount, 4, 1200; separators="gray") do i, frame
        playerdata1 = readdata_get_playerdata_from_task(dict1, 2*i - 1, VERBOSE=false);
        playerdata2 = readdata_get_playerdata_from_task(dict1, 2*i, VERBOSE=false);
    
        @assert playerdata1["role"] in ["STUDENT", "TEACHER"]
        if playerdata1["role"] == "STUDENT"  # Make player1 always teacher
            playerdata1, playerdata2 = playerdata2, playerdata1
        end
        player_trajectory1 = [Point(x, y) for (x, y) in zip(playerdata1["x"], playerdata1["y"])]
        player_trajectory2 = [Point(x, y) for (x, y) in zip(playerdata2["x"], playerdata2["y"])]
    
        scene = utils_scene_from_playerdata(playerdata1, VERBOSE=false)
        if isnothing(scene)  # couldnt get scene, try player 2
            scene = utils_scene_from_playerdata(playerdata2, VERBOSE=false)
            @assert !isnothing(scene) "Both players don't have map"
        end
        
        draw_scene(scene, frame)
        length(player_trajectory1)>0 && draw_path(scene, player_trajectory1[1], player_trajectory1[end], player_trajectory1, frame; markersize=10, pathopacity=1)
        !hide_student && length(player_trajectory2)>0 && draw_path(scene, player_trajectory2[1], player_trajectory2[end], player_trajectory2, frame; markersize=5, pathopacity=1)
    end
end

readdata_all_rooms = ["58", "59", "61", "68", "69", "70", "71", "72", "76", "79", "81", "82", "83"];  # 13 rooms in total that finished the game
readdata_all_pairs = ["borisvel-timmyd", "linv-rphess", "24-23", "33-34", "27-28", "25-26", "53-54", "51-52", "64-63", "56-55", "68-67", "75-76", "61-62"]

