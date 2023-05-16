using JuMP, Gurobi, Random, CSV, DataFrames, Statistics, JLD2, FileIO,DelimitedFiles

model_type="model_without_k";
include("scripts/"*model_type*"/display.jl"); include("scripts/"*model_type*"/model.jl"); include("scripts/"*model_type*"/run.jl"); include("data/map_config.jl");
# Benchmarks definition
b1=Dict("Name"=> "1)", "Transfer"=> false, "Flexible" => false, "High capacity" => false);
b2=Dict("Name"=> "2)", "Transfer"=> false, "Flexible" => false, "High capacity" => true); # We take high capacity busses
b3=Dict("Name"=> "3)", "Transfer"=> false, "Flexible" => true, "High capacity" => true); # We take high capacity busses + Flexible assign
b4=Dict("Name"=> "4)", "Transfer"=> true, "Flexible" => true, "High capacity" => true); # We take high capacity busses + Flexible assign + Transfer

function solve_without_k(save_res,map_type,benchmark,G,Gtype)
    map_inputs,Wk,Q=create_inputs(map_type,benchmark);
    (map_title,hubs_id,vbs_id,nb_locs,cust_id,nb_cust,depot_locs,horizon,tstep,park_slots)=map_inputs;
    model_inputs = (G,Gtype,Wk,Q);
    
    data, map1, tsnetwork, params, abbrev, pre_time = create_network(map_inputs, model_inputs,benchmark);
    q, t, I, K=abbrev;

    coefficients=1,1,1,1,20,0
    sol=network_model(Q,abbrev,data.wo,tsnetwork,params,coefficients,0);

    if save_res
        benchmark_name=string(benchmark["Name"])*"Tr_"*string(benchmark["Transfer"])*"_Flex_"*string(benchmark["Flexible"])*"_HighCap_"*string(benchmark["High capacity"])
        resultfolder="results/"*model_type*"/"*map_type*"/"*benchmark_name*"/";
        #resultfolder="results/"*model_type*"/"*map_type*"/";
        if !isdir("results/"*model_type*"/"*map_type*"/")
            mkdir("results/"*model_type*"/"*map_type*"/")
        end
        if !isdir(resultfolder)
            mkdir(resultfolder)
        end
        jldsave(resultfolder*"solution.jld2", xi=sol.xi, x=sol.x, z=sol.z)
        write_result(resultfolder*"res.txt",sol,tsnetwork,params,abbrev,data.wo,data.locs_id,false)
    end

    timespaceviz_bus(resultfolder*"tsplot.png", horizon, tstep, tsnetwork, params, sol.z, data.locs_id, data.locs_desc,x_size=2000, y_size=1000)
    ts=0 # time from which we want to print the arcs
    map2=print_traveling_arcs(sol,ts,map1,data.locs,tsnetwork,params,horizon,data.locs_id,data.locs_desc,false,save_res,resultfolder)
end

# Model Inputs
G = 2 # max detour ratio for customers (traveling time < (1+G)gamma)
Gtype= "shortestpathpercent" # or "absolutetime"

#-------- Step 1: Solve benchmark 4 for every map

# benchmark=b4;
# unif_maps=["unif_map_1","unif_map_2","unif_map_3","unif_map_4","unif_map_5"]
# for unif_map in unif_maps
#     println("\n ---- Solve for map $unif_map")
#     solve_without_k(true,unif_map,benchmark,G,Gtype)
# end

# clust_maps=["clust_map_1","clust_map_2","clust_map_3","clust_map_4","clust_map_5"]
# for clust_map in clust_maps
#     println("\n --- Solve for map $clust_map")
#     solve_without_k(true,clust_map,benchmark,G,Gtype)
# end

#-------- Step 2: Solve 3 other benchmarks on maps unif_map_5 and clust_map_5
maps=["clust_map_5"]
benchmarks=[b1,b2,b3,b4]
for map in maps
    for benchmark in benchmarks
        name=string(benchmark["Name"])
        println("\n ---- Solve for map $map with benchmark $name")
        solve_without_k(true,map,benchmark,G,Gtype)
    end
end

