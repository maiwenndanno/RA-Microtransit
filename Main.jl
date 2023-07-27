using JuMP, Gurobi, Random, CSV, DataFrames, Statistics, JLD2, FileIO, DelimitedFiles,Printf,Suppressor

model_type="model_without_k";
include("2_scripts/"*model_type*"/display.jl"); 
include("2_scripts/"*model_type*"/model.jl"); 
include("2_scripts/"*model_type*"/run.jl"); 
include("1_data/map_config.jl");
include("2_scripts/"*model_type*"/benders_model.jl");

# Benchmarks definition
b1=Dict("Name"=> "1)", "Transfer"=> false, "Flexible" => false, "High capacity" => false);
b2=Dict("Name"=> "2)", "Transfer"=> false, "Flexible" => false, "High capacity" => true); # We take high capacity busses
b3=Dict("Name"=> "3)", "Transfer"=> false, "Flexible" => true, "High capacity" => true); # We take high capacity busses + Flexible assign
b4=Dict("Name"=> "4)", "Transfer"=> true, "Flexible" => true, "High capacity" => true); # We take high capacity busses + Flexible assign + Transfer

# Model Inputs
G = 2 # max detour ratio for customers (traveling time < (1+G)gamma)
Gtype= "shortestpathpercent" # or "absolutetime"

# Model objective coefficients
alpha2 = 5 #course price 
alpha1 = 0.1 #variable service cost (price per min) 
alpha0 = 5 #fixed service cost (price per vehicle used) 
mu = 0.1 # Cost of 1min cust walking 
beta = 0.05 #Cost of 1min cust waiting 
delta = 0.01 #Cost of 1mn cust traveling in bus 
lambda = 1 #Cost of cust transfers 
coefficients=alpha2, alpha1, alpha0, mu, beta, delta, lambda;

# ------------------------------- Optim Models & Save results ----------------------------------

function solve_direct_model(save_res,map_type,benchmark,G,Gtype,coefficients)
    map_inputs,Wk,Q=create_inputs(map_type,benchmark);
    (_,_,_,_,_,_,_,horizon,tstep,_)=map_inputs;
    model_inputs = (G,Gtype,Wk,Q);
    
    data, map1, tsnetwork, params, abbrev, pre_time = create_network(map_inputs, model_inputs,benchmark);
    q, t, I, K=abbrev;

    sol=network_model_profit(Q,abbrev,data.wo,tsnetwork,params,coefficients,0);
    if save_res && sum(sol.z)>0
        benchmark_name=string(benchmark["Name"])*"Tr_"*string(benchmark["Transfer"])*"_Flex_"*string(benchmark["Flexible"])*"_HighCap_"*string(benchmark["High capacity"])
        resultfolder="3_results/"*model_type*"/"*map_type*"/"*benchmark_name*"/";
        #resultfolder="3_results/"*model_type*"/"*map_type*"/";
        if !isdir("3_results/"*model_type*"/"*map_type*"/")
            mkdir("3_results/"*model_type*"/"*map_type*"/")
        end
        if !isdir(resultfolder)
            mkdir(resultfolder)
        end
        jldsave(resultfolder*"solution.jld2", xi=sol.xi, x=sol.x, z=sol.z)
        write_result(resultfolder*"res.txt",sol,tsnetwork,params,abbrev,data.wo,data.locs_id,false)
    end
    if sum(sol.z)>0    
        timespaceviz_bus(resultfolder*"tsplot.png", horizon, tstep, tsnetwork, params, sol.z, data.locs_id, data.locs_desc,x_size=2000, y_size=1000)
        ts=0 # time from which we want to print the arcs
        map2=print_traveling_arcs(sol,0,map1,data.locs,tsnetwork,params,horizon,data.locs_id,data.locs_desc,false,save_res,resultfolder)
    end
end

function solve_benders(save_res,map_type,benchmark,G,Gtype,coefficients,print_all=true)
    map_inputs,Wk,Q=create_inputs(map_type,benchmark);
    (_,_,_,_,_,_,_,horizon,tstep,_)=map_inputs;
    model_inputs = (G,Gtype,Wk,Q);
    
    data, map1, tsnetwork, params, abbrev, pre_time = create_network(map_inputs, model_inputs,benchmark);

    sol_benders,benders_prop=solve_benders_profit(Q,abbrev,data,tsnetwork,params,coefficients);
    map2bis, plot_bounds, plot_times= save_and_display(map1,"benders",map_type,benchmark,save_res,sol_benders,horizon, tstep,tsnetwork,params,abbrev,data,print_all,benders_prop);
end

#-------- Step 1: Solve model with benchmark 4 for every map

benchmark=b4;
maps=["unif_map_1"]#,"unif_map_2","unif_map_3","unif_map_5"]
for map in maps
    println("\n ---- Solve for map $map")
    solve_direct_model(true,map,benchmark,G,Gtype,coefficients)
end

maps=["unif_map_5"]#,"clust_map_5"]#["clust_map_1","clust_map_2"]#["clust_map_all"]#["unif_map_all_1way"]#["clust_map_1","clust_map_2","clust_map_3","clust_map_4","clust_map_5"]#["clust_map_5"]
benchmarks=[b4]
for map in maps
    for benchmark in benchmarks
        name=string(benchmark["Name"])
        println("\n ---- Solve for map $map with benchmark $name")
        solve_benders(true,map,benchmark,G,Gtype,coefficients,false)
    end
end

