const dr_speed = 5 # nb of minutes per km when driving;
const wk_speed = 12 # nb of minutes per km when walking;

######  CLUSTERED MAPS ######

function clust_map_1()
    # 1: 10 locs, 3 cust, 10 veh
    map_title= "map_cluster_BIG"
    
    nb_locs=10; 
    vbs_id=[1,3,5,7,9,20,23,11,13,26];

    nb_cust=3;
    cust_id=[1,3,5];
    
    nb_veh=10;
    depot_locs = repeat([1,2,1,7,8],outer=2); # in new indices
    hubs_id=[5]; # in new indices

    horizon = dr_speed*2500									
    tstep = 500;

    map_inputs= (map_title,hubs_id,vbs_id,nb_locs,cust_id,nb_cust,depot_locs,horizon,tstep)

    return map_inputs
end

function clust_map_2()
    # 2: 10 locs, 6 cust, 10 veh
    map_title= "map_cluster_BIG"
    
    nb_locs=10; 
    vbs_id=[1,3,5,7,9,20,23,11,13,26];

    nb_cust=6;
    cust_id=[1,3,5,7,9,11];
    
    nb_veh=10;
    depot_locs = repeat([1,2,1,7,8],outer=2); # in new indices, 
    #depot_locs = [rand(1:nb_locs) for i in 1:nb_veh] # in new idices

    hubs_id=[2,5]; # in new indices

    horizon = dr_speed*2500									
    tstep = 500;

    map_inputs= (map_title,hubs_id,vbs_id,nb_locs,cust_id,nb_cust,depot_locs,horizon,tstep)
    
    return map_inputs
end

function clust_map_3()
    # 3: 15 locs, 5 cust, 4 veh
    map_title= "map_cluster_BIG"
    
    nb_locs=15; 
    vbs_id=[1,3,5,7,9,11,13,15,17,19,20,23,25,26,29];

    nb_cust=5;
    cust_id=[1,3,5,7,9];
    
    nb_veh=4;
    depot_locs = [1,2,7,8]; # in new indices, 
    #depot_locs = [rand(1:nb_locs) for i in 1:nb_veh] # in new idices

    hubs_id=[2,5]; # in new indices

    horizon = dr_speed*2500									
    tstep = 500;

    map_inputs= (map_title,hubs_id,vbs_id,nb_locs,cust_id,nb_cust,depot_locs,horizon,tstep)
    
    return map_inputs
end

######  UNIF MAPS ######
function unif_map_1()
    # 3: 15 locs, 5 cust, 4 veh
    map_title= "map_unif_small" # 20 VBS, 10 cust unif
    
    nb_locs=10; 
    vbs_id=1:nb_locs;

    nb_cust=10; 
    cust_id=1:nb_cust;

    hubs_id=[5,6,15];
    nb_veh=2;
    depot_locs = [rand(1:nb_locs) for i in 1:nb_veh]

    horizon = 200								
    tstep = 10;

    map_inputs= (map_title,hubs_id,vbs_id,nb_locs,cust_id,nb_cust,depot_locs,horizon,tstep)
    
    return map_inputs
end

function create_inputs(map_type)
    # Create Map Inputs
    if map_type == "clust_map_1"
        map_inputs = clust_map_1()
        Wk = 200 # max walking time for customers from origin or to destination
    elseif map_type == "clust_map_2"
        map_inputs = clust_map_2()
        Wk = 200 # max walking time for customers from origin or to destination
    elseif map_type == "clust_map_3"
        map_inputs = clust_map_3()
        Wk = 200 # max walking time for customers from origin or to destination
    elseif map_type == "unif_map_1"
        map_inputs = unif_map_1()
        Wk = 40 # max walking time for customers from origin or to destination
    else
        error("map_type not recognized")
    end

    return map_inputs,Wk
end