using JuMP, Gurobi, Random, CSV, DataFrames, Statistics, Dates, Plots
using JLD2, FileIO
include("network.jl")
include("parameters.jl")
include("display.jl")
include("model.jl");

function load_data(datafolder,vbs_ind,nb_locs,cust_ind,nb_cust)
    cust = CSV.read(datafolder*"customers.csv", DataFrame)
    cust=cust[findall(in(cust_ind),cust.cust_id),:]
    cust.cust_id=1:nb_cust
    vbs = CSV.read(datafolder*"locations.csv", DataFrame)
    locs=vbs[findall(in(vbs_ind),vbs.id),:]
    locs.id=1:nb_locs
    locs=vcat(locs,DataFrame(id = nb_locs+1, x = 0, y = 0)) # Add sink node
    arcs= gen_arcs(locs,nb_locs)
    wo= gen_wo(cust, locs)
    wd= gen_wd(cust, locs)
    return cust, locs, arcs, wo, wd
end

function gen_arcs(locations,nb_locs)
    arcs = DataFrame(start_loc = Int64[], end_loc = Int64[], duration = Float64[], distance = Float64[])
    for start_loc in locations.id
        for end_loc in locations.id
            if start_loc != end_loc && start_loc <= nb_locs # not coming from sink node
                if end_loc <= nb_locs # not going to sink node
                    dist=((locations[locations.id .== start_loc,:].x[1]-locations[locations.id .== end_loc,:].x[1])^2+(locations[locations.id .== start_loc,:].y[1]-locations[locations.id .== end_loc,:].y[1])^2)^0.5
                    time=dist*dr_speed # en minutes
                    push!(arcs, [start_loc, end_loc, time, dist])
                else # arc to sink node
                    dist=0
                    time=0
                    push!(arcs, [start_loc, end_loc, time, dist])
                end
            end
        end
    end
    return arcs
end

function gen_wo(cust, locations)
    # create empty matrix of size (nb of customers, nb of vbs)
    walking_time_origin = zeros(size(cust)[1],size(locations)[1]-1)
    for i in 1:size(cust)[1]
        for j in 1:size(locations)[1]-1 # We remove the sink node
            walking_dist_origin=((cust[i,:].x_o-locations[j,:].x)^2+(cust[i,:].y_o-locations[j,:].y)^2)^0.5
            walking_time_origin[i,locations[j,:].id]=walking_dist_origin*wk_speed
        end
    end
    return walking_time_origin
end

function gen_wd(cust, locations)
    walking_time_dest = zeros(size(cust)[1],size(locations)[1]-1)
    for i in 1:size(cust)[1]
        for j in 1:size(locations)[1]-1 # We remove the sink node
            walking_dist_dest=((cust[i,:].x_d-locations[j,:].x)^2+(cust[i,:].y_d-locations[j,:].y)^2)^0.5
            walking_time_dest[i,locations[j,:].id]=walking_dist_dest*wk_speed
        end
    end
    return walking_time_dest
end

function update_locs_ind(hubs_ind, vbs_ind,nb_locs)
    # update locs ind with vbs_ind list
    new_hubs_ind=[]
    for h in hubs_ind
        if h in vbs_ind
            for i in 1:nb_locs
                if vbs_ind[i]==h
                    push!(new_hubs_ind,i)
                end
            end
        end
    end
    return new_hubs_ind
end

function create_network(map_inputs, model_inputs)
    # map_inputs: datafolder,hubs_ind,nb_locs,nb_cust,depot_locs,horizon,tstep
    # model_inputs: G,Gtype,Wk,Q

    map_title,hubs_ind,vbs_ind,nb_locs,cust_ind,nb_cust,depot_locs,horizon,tstep = map_inputs
    G,Gtype,Wk,Q = model_inputs

    datafolder="../../data/"*map_title*"/";
    cust, vbs, arcs, wo, wd = load_data(datafolder,vbs_ind,nb_locs,cust_ind,nb_cust);
    hubs_ind = update_locs_ind(hubs_ind, vbs_ind,nb_locs) #hubs_ind[hubs_ind .<= nb_locs]
    map1 = create_map(vbs, cust, hubs_ind,nb_locs)
    
    # Abbreviations for IO model
    q = cust[!,"load"]; # customer load
    t = cust[!,"depart_time"]; # customer departure time
    I = 1:size(cust)[1]; # customers set
    K = 1:length(depot_locs); # vehicles set
    abbrev=(q,t,I,K)

    tsnetwork = createfullnetwork(vbs, arcs, nb_locs, horizon, tstep)
    params = create_params(tsnetwork,hubs_ind, model_inputs, nb_locs,depot_locs,wo, wd,I,t,tstep,horizon)
    data=(cust=cust,locs=vbs,arcs=arcs,wo=wo,wd=wd)
    
    return data, map1, tsnetwork, params, abbrev
end
    