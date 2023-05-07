using JuMP, Gurobi, Random, CSV, DataFrames, Statistics, Dates, Plots
using JLD2, FileIO
include("network.jl")
include("parameters.jl")
include("display.jl")
include("model.jl");

function load_data(datafolder,vbs_id,nb_locs,cust_id,nb_cust)
    cust = CSV.read(datafolder*"customers.csv", DataFrame)
    cust=cust[findall(in(cust_id),cust.cust_id),:]
    cust.cust_id=1:nb_cust
    vbs = CSV.read(datafolder*"locations.csv", DataFrame)
    locs=vbs[findall(in(vbs_id),vbs.id),:]
    locs.id=1:nb_locs # Update loc ids with 1:nb_locs
    return cust, locs
end

function gen_arcs(locs,locs_id)
    arcs = DataFrame(start_loc = Int64[], end_loc = Int64[], duration = Float64[], distance = Float64[])
    for start_loc in locs.id
        for end_loc in locs.id
            if start_loc != end_loc && !(start_loc in locs_id.sink) && !(end_loc in locs_id.depots) # no arc coming from sink node or leaving a depot node
                if !(end_loc in locs_id.sink) && !(start_loc in locs_id.depots) # not going to sink node or coming from a depot node
                    dist=((locs[locs.id .== start_loc,:].x[1]-locs[locs.id .== end_loc,:].x[1])^2+(locs[locs.id .== start_loc,:].y[1]-locs[locs.id .== end_loc,:].y[1])^2)^0.5
                    time=dist*dr_speed # en minutes
                    push!(arcs, [start_loc, end_loc, time, dist])
                else # arc to sink node or from depot
                    dist=0
                    time=0
                    push!(arcs, [start_loc, end_loc, time, dist])
                end
            end
        end
    end
    return arcs
end

function gen_wo(cust, locs, locs_id)
    vbs_ids=locs_id.all_vbs #classic vbs + dupl hubs
    # create empty matrix of size (nb of customers, nb of locs)
    walking_time_origin = zeros(size(cust)[1],size(locs)[1])
    for i in 1:size(cust)[1]
        for j in locs_id.all
            if j in vbs_ids
                walking_dist_origin=((cust[i,:].x_o-locs[j,:].x)^2+(cust[i,:].y_o-locs[j,:].y)^2)^0.5
                walking_time_origin[i,locs[j,:].id]=walking_dist_origin*wk_speed
            else
                walking_time_origin[i,locs[j,:].id]=Inf # Depots and sinks are unreachable
            end
        end
    end
    return walking_time_origin
end

function gen_wd(cust, locs, locs_id)
    vbs_ids=locs_id.all_vbs #classic vbs + dupl hubs
    walking_time_dest = zeros(size(cust)[1],size(locs)[1])
    for i in 1:size(cust)[1]
        for j in locs_id.all
            if j in vbs_ids
                walking_dist_dest=((cust[i,:].x_d-locs[j,:].x)^2+(cust[i,:].y_d-locs[j,:].y)^2)^0.5
                walking_time_dest[i,locs[j,:].id]=walking_dist_dest*wk_speed
            else
                walking_time_dest[i,locs[j,:].id]=Inf # Depots and sinks are unreachable
            end
        end
    end
    return walking_time_dest
end

function update_hubs_id(hubs_id, vbs_id)
    # update hubs id list with new vbs id (1:nb_locs)
    new_hubs_id=[]
    for h in hubs_id
        if h in vbs_id
            for i in eachindex(vbs_id)
                if vbs_id[i]==h
                    push!(new_hubs_id,i)
                end
            end
        end
    end
    return new_hubs_id
end

function expand_locs(locs,depot_locs,hubs_id)
    # Expand locs and create the different locs_id parameters & locs_desc dictionnary
    # all: indices of all the locs (including hubs, depots, sink)
    # classic_vbs: indices of the classic vbs Only
    # hubs: indices of the hubs Only (not duplicated)
    # all_hubs: indices of all hubs (including duplicated hubs)
    # all_vbs: indices of all vbs = classic_vbs + dupl_hubs
    # depots: indices of the depots Only
    # sink: index of the sink Only
    # locs_desc: dictionnary that contains the description of each location ("Sink", "Depot (in 14)", "Vbs 13 (Hub)")
    
    # Get hubs indices
    hubs_id = update_hubs_id(hubs_id, vbs_id) # Index of hubs
    # Initialize duplicated hub indices
    full_hubs_id=copy(hubs_id)

    # Indices of all vbs(classic vbs + hubs)
    nb_locs=size(locs)[1] # Including hubs but not duplicated
    full_vbs_id=[i for i in 1:nb_locs]

    # Get indices of only classic VBS
    classic_vbs_id=copy(full_vbs_id)
    for i in hubs_id
        classic_vbs_id=classic_vbs_id[classic_vbs_id.!=i]
    end

    # Initialize correspondance between loc id and visuals
    locs_desc=Dict() # Dictionnary that will contain the description of each location ("Sink", "Depot (in 14)", "Vbs 13 (Hub)")
    
    # Duplicate hubs nodes for nb_veh > 1
    count_h=0
    similar_hubs=Dict() # Contain all the hubs located at the same locations
    for id in locs.id
        if id in hubs_id
            similar_hubs[id]=[id]
            # get index of id in hubs_id
            locs_desc[id]=string("Vbs ",id," (Hub)")
            # Create new nodes for each vehicle (nb_veh -1 since we already have one hub)
            for k in 1:nb_veh-1
                id_k=nb_locs+count_h*(nb_veh-1)+k
                locs=vcat(locs,DataFrame(id = id_k,x=locs[locs.id .==id,:x] , y = locs[locs.id .==id,:y]))
                # Add new indices of hubs
                push!(full_hubs_id,id_k)
                push!(full_vbs_id,id_k)
                locs_desc[id_k]=string("Vbs ",id," (Hub)")
                push!(similar_hubs[id],id_k)
            end
            count_h+=1
        else 
            locs_desc[id]=string("Vbs ",id)
        end
    end
    
    # Add depot nodes, one for each depot
    depots_id=[]
    for i in eachindex(depot_locs)
        id=size(locs)[1]+1
        locs=vcat(locs,DataFrame(id = id,x=locs[locs.id .==depot_locs[i],:x] , y = locs[locs.id .==depot_locs[i],:y]))
        locs_desc[id]=string("Depot (Vbs ",depot_locs[i],")")
        push!(depots_id,id)
    end
 
     # Add sink node
    sink_id=size(locs)[1] +1
    locs=vcat(locs,DataFrame(id = sink_id, x = 0, y = 0))
    locs_desc[sink_id]="Sink"

    # Different locs id
    locs_id= (all=locs.id, hubs=hubs_id, all_hubs=full_hubs_id, all_vbs=full_vbs_id, classic_vbs=classic_vbs_id, depots=depots_id, sink=sink_id, similar_hubs)
    return locs, locs_id, locs_desc
end
    

function create_network(map_inputs, model_inputs)
    # map_inputs: datafolder,hubs_id,vbs_id,nb_locs,nb_cust,depot_locs,horizon,tstep
    # model_inputs: G,Gtype,Wk,Q

    datafolder,hubs_id,vbs_id,nb_locs,cust_id,nb_cust,depot_locs,horizon,tstep = map_inputs
    G,Gtype,Wk,Q = model_inputs
    cust, locs = load_data(datafolder,vbs_id,nb_locs,cust_id,nb_cust);
    locs, locs_id, locs_desc=expand_locs(locs,depot_locs,hubs_id); # Update locs with depot, hubs and sink
    map = create_map(locs, cust, locs_id)

    arcs= gen_arcs(locs, locs_id)
    wo= gen_wo(cust, locs, locs_id)
    wd= gen_wd(cust, locs, locs_id)
    tsnetwork,physicalarcs = createfullnetwork(locs, arcs, horizon, tstep)

    # Abbreviations for IO model
    q = cust[!,"load"]; # customer load
    t = cust[!,"depart_time"]; # customer departure time
    I = 1:size(cust)[1]; # customers set
    K = 1:length(depot_locs); # vehicles set
    abbrev=(q,t,I,K)

    shortest_time=cacheShortestTravelTimes(physicalarcs,locs_id)
    params = create_params(tsnetwork,physicalarcs,shortest_time,locs_id, model_inputs, wo, wd,I,t,tstep,horizon)
    
    return cust, locs, locs_id, locs_desc, map, arcs, wo, wd,tsnetwork,shortest_time,physicalarcs, params, abbrev 
end
    