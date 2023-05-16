using JuMP, Gurobi, Random, CSV, DataFrames, Statistics, JLD2, FileIO,DelimitedFiles

model_type="model_with_k";
include("scripts/"*model_type*"/display.jl"); include("scripts/"*model_type*"/model.jl"); include("scripts/"*model_type*"/run.jl"); include("data/map_config.jl");
b4=Dict("Name"=> "4)", "Transfer"=> true, "Flexible" => true, "High capacity" => true); # We take high capacity busses + Flexible assign + Transfer

# Model Inputs
benchmark=b4;
G = 2 # max detour ratio for customers (traveling time < (1+G)gamma)
Gtype= "shortestpathpercent" # or "absolutetime"

function solve_with_k(save_res,map_type,benchmark,G,Gtype)
    map_inputs,Wk,Q=create_inputs(map_type,benchmark);
    (map_title,hubs_id,vbs_id,nb_locs,cust_id,nb_cust,depot_locs,horizon,tstep)=map_inputs
    model_inputs = (G,Gtype,Wk,Q);
    
    data, map1, tsnetwork, params, abbrev,pre_time, depot_locs = create_network(map_inputs, model_inputs,benchmark);
    q, t, I, K=abbrev;

    coefficients=1,1,1,1,20,0
    sol=network_model(Q,abbrev,data.wo,tsnetwork,params,coefficients,0);

    if save_res
        benchmark_name=string(benchmark["Name"])*"Tr_"*string(benchmark["Transfer"])*"_Flex_"*string(benchmark["Flexible"])*"_HighCap_"*string(benchmark["High capacity"])
        resultfolder="results/"*model_type*"/"*map_type*"/"*benchmark_name*"/";

        if !isdir("results/"*model_type*"/"*map_type*"/")
            mkdir("results/"*model_type*"/"*map_type*"/")
        end
        if !isdir(resultfolder)
            mkdir(resultfolder)
        end
        jldsave(resultfolder*".solutionjld2", xi=sol.xi, x=sol.x, z=sol.z)
        write_result(resultfolder,sol,tsnetwork,params,abbrev,data.wo,false)
    end

    timespaceviz_bus(resultfolder*"tsplot.png", horizon, tstep, tsnetwork, params, sol.z, K, nb_locs,x_size=2000, y_size=1000)
    ts=0 # time from which we want to print the arcs
    map2=print_traveling_arcs(sol,ts,params,horizon,K,map1,data.locs,tsnetwork,nb_locs,false,save_res,resultfolder)
end

unif_maps=["unif_map_1","unif_map_2","unif_map_3","unif_map_4","unif_map_5"]
for unif_map in unif_maps
    println("\n ---- Solve for map $unif_map")
    solve_with_k(true,unif_map,benchmark,G,Gtype)
end

clust_maps=["clust_map_1","clust_map_2","clust_map_3","clust_map_4","clust_map_5"]
for clust_map in clust_maps
    println("\n --- Solve for map $clust_map")
    solve_with_k(true,clust_map,benchmark,G,Gtype)
end



