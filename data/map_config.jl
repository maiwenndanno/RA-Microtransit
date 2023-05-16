const dr_speed = 5 # nb of minutes per km when driving;
const wk_speed = 12 # nb of minutes per km when walking;

######  CLUSTERED MAPS ######

function clust_map_1()
    map_title= "map_cluster_BIG"
    
    nb_locs=6; 
    vbs_id=[1,3,5,10,20,26]; # /!\ Increasing order

    nb_cust=5;
    cust_id=[1,3,5,7,9];
    
    nb_veh=3;
    depot_locs = [1,3,5]; # in new indices
    hubs_id=[5]; # in new indices
    park_slots=2; # max nb parking slots at each hub location

    horizon = dr_speed*3500									
    tstep = 500;

    map_inputs= (map_title,hubs_id,vbs_id,nb_locs,cust_id,nb_cust,depot_locs,horizon,tstep,park_slots)

    return map_inputs
end

function clust_map_2()
    map_title= "map_cluster_BIG"
    
    nb_locs=10; 
    vbs_id=[1,2,3,5,10,20,23,25,26,27]#[1,3,5,7,9,20,23,11,13,26];

    nb_cust=5;
    cust_id=[1,3,5,7,9];
    
    nb_veh=5;
    depot_locs = [1,2,3,5,2]; # in new indices, 
    #depot_locs = [rand(1:nb_locs) for i in 1:nb_veh] # in new idices
    park_slots=2; # max nb parking slots at each hub location

    hubs_id=[3,5]; # in new indices

    horizon = dr_speed*3500									
    tstep = 500;

    map_inputs= (map_title,hubs_id,vbs_id,nb_locs,cust_id,nb_cust,depot_locs,horizon,tstep,park_slots)
    
    return map_inputs
end

function clust_map_3()
    map_title= "map_cluster_BIG"
    
    nb_locs=6; 
    vbs_id=[1,3,5,10,20,26]#[1,3,5,7,9,11,13,15,17,19,20,23,25,26,29];

    nb_cust=10;
    cust_id=1:10#[1,3,5,7,9];
    
    nb_veh=3;
    depot_locs = [1,3,5]; # in new indices, 
    #depot_locs = [rand(1:nb_locs) for i in 1:nb_veh] # in new idices
    park_slots=2; # max nb parking slots at each hub location

    hubs_id=[5]; # in new indices

    horizon = dr_speed*3500									
    tstep = 500;

    map_inputs= (map_title,hubs_id,vbs_id,nb_locs,cust_id,nb_cust,depot_locs,horizon,tstep,park_slots)
    
    return map_inputs
end

function clust_map_4()
    map_title= "map_cluster_BIG"
    
    nb_locs=6; 
    vbs_id=[1,3,5,10,20,26]#[1,3,5,7,9,11,13,15,17,19,20,23,25,26,29];

    nb_cust=10;
    cust_id=1:10#[1,3,5,7,9];
    
    nb_veh=5;
    depot_locs = [1,3,5,1,3]; # in new indices, 
    #depot_locs = [rand(1:nb_locs) for i in 1:nb_veh] # in new idices
    park_slots=2; # max nb parking slots at each hub location

    hubs_id=[5]; # in new indices

    horizon = dr_speed*3500									
    tstep = 500;

    map_inputs= (map_title,hubs_id,vbs_id,nb_locs,cust_id,nb_cust,depot_locs,horizon,tstep,park_slots)
    
    return map_inputs
end
function clust_map_5()
    map_title= "map_cluster_BIG"
    
    nb_locs=10; 
    vbs_id=[1,2,3,5,10,20,23,25,26,27]#[1,3,5,13,20,26]#[1,3,5,7,9,11,13,15,17,19,20,23,25,26,29];

    nb_cust=10;
    cust_id=1:10#[1,3,5,7,9];
    
    nb_veh=5;
    depot_locs = [1,3,5,1,3]; # in new indices, 
    #depot_locs = [rand(1:nb_locs) for i in 1:nb_veh] # in new idices
    park_slots=2; # max nb parking slots at each hub location

    hubs_id=[2,5]; # in new indices

    horizon = dr_speed*3500									
    tstep = 500;

    map_inputs= (map_title,hubs_id,vbs_id,nb_locs,cust_id,nb_cust,depot_locs,horizon,tstep,park_slots)
    
    return map_inputs
end

function clust_map_all()
    map_title= "map_cluster_BIG"
    
    nb_locs=30; 
    vbs_id=1:nb_locs#[1,3,5,7,9,11,13,15,17,19,20,23,25,26,29];

    nb_cust=15#5;
    cust_id=1:nb_cust#[1,3,5,7,9];
    
    nb_veh=4;
    depot_locs = [1,2,7,8]; # in new indices, 
    #depot_locs = [rand(1:nb_locs) for i in 1:nb_veh] # in new idices
    park_slots=2; # max nb parking slots at each hub location

    hubs_id=[2,5]; # in new indices

    horizon = dr_speed*2500									
    tstep = 500;

    map_inputs= (map_title,hubs_id,vbs_id,nb_locs,cust_id,nb_cust,depot_locs,horizon,tstep,park_slots)
    
    return map_inputs
end




######  UNIF MAPS ######
function unif_map_1()
    map_title= "map_unif_small" # 20 VBS, 10 cust unif
    
    nb_locs=6; 
    vbs_id=[2,3,10,11,14,19]#[2,6,10,11,15,19]#1:nb_locs;

    nb_cust=5; 
    cust_id=[1,3,5,7,9]#1:nb_cust;

    hubs_id=[3,14]#[6,15]; 
    nb_veh=3;
    depot_locs = [2,11,14]#[rand(1:nb_locs) for i in 1:nb_veh]
    park_slots=2; # max nb parking slots at each hub location

    horizon = 400								
    tstep = 10;

    map_inputs= (map_title,hubs_id,vbs_id,nb_locs,cust_id,nb_cust,depot_locs,horizon,tstep,park_slots)
    
    return map_inputs
end

function unif_map_2()
    map_title= "map_unif_small" # 20 VBS, 10 cust unif
    
    nb_locs=10; 
    vbs_id=[2,3,7,9,10,11,14,18,19,20]#[1,2,6,9,10,11,12,15,19,20]#1:nb_locs;

    nb_cust=5; 
    cust_id=[1,3,5,7,9]#1:nb_cust;

    hubs_id=[3,14]; 
    nb_veh=5;
    depot_locs = [2,3,11,11,14]#[rand(1:nb_locs) for i in 1:nb_veh]
    park_slots=2; # max nb parking slots at each hub location

    horizon = 400								
    tstep = 10;

    map_inputs= (map_title,hubs_id,vbs_id,nb_locs,cust_id,nb_cust,depot_locs,horizon,tstep,park_slots)
    
    return map_inputs
end

function unif_map_3()
    map_title= "map_unif_small" # 20 VBS, 10 cust unif
    
    nb_locs=6; 
    vbs_id=[2,3,10,11,14,19]#[2,6,10,11,15,19]#1:nb_locs;

    nb_cust=10; 
    cust_id=1:nb_cust;

    hubs_id=[3,14]#[6,15]; 
    nb_veh=3;
    depot_locs = [2,11,14]#[rand(1:nb_locs) for i in 1:nb_veh]
    
    park_slots=2; # max nb parking slots at each hub location

    horizon = 400								
    tstep = 10;

    map_inputs= (map_title,hubs_id,vbs_id,nb_locs,cust_id,nb_cust,depot_locs,horizon,tstep,park_slots)
    
    return map_inputs
end

function unif_map_4()
    map_title= "map_unif_small" # 20 VBS, 10 cust unif
    
    nb_locs=6; 
    vbs_id=[2,3,10,11,14,19]#[2,6,10,11,15,19]#1:nb_locs;

    nb_cust=10; 
    cust_id=1:nb_cust;

    hubs_id=[3,14]#[6,15];  
    nb_veh=5;
    depot_locs = [2,3,11,11,14]#[1,2,6,12,15]#[rand(1:nb_locs) for i in 1:nb_veh]
    park_slots=2; # max nb parking slots at each hub location

    horizon = 400								
    tstep = 10;

    map_inputs= (map_title,hubs_id,vbs_id,nb_locs,cust_id,nb_cust,depot_locs,horizon,tstep,park_slots)
    
    return map_inputs
end

function unif_map_5()
    map_title= "map_unif_small" # 20 VBS, 10 cust unif
    
    nb_locs=10; 
    vbs_id=[2,3,7,9,10,11,14,18,19,20]#[1,2,6,9,10,11,12,15,19,20]#1:nb_locs;

    nb_cust=10; 
    cust_id=1:nb_cust;

    hubs_id=[3,14]; 
    nb_veh=5;
    depot_locs = [2,3,11,11,14]#[1,2,6,12,15]#[rand(1:nb_locs) for i in 1:nb_veh]
    park_slots=2; # max nb parking slots at each hub location

    horizon = 400								
    tstep = 10;

    map_inputs= (map_title,hubs_id,vbs_id,nb_locs,cust_id,nb_cust,depot_locs,horizon,tstep,park_slots)
    
    return map_inputs
end

function unif_map_all()
    map_title= "map_unif_small" # 20 VBS, 10 cust unif
    
    nb_locs=20; 
    vbs_id=1:nb_locs;

    nb_cust=10; 
    cust_id=1:nb_cust;

    hubs_id=[3,6,14,15];
    nb_veh=2;
    depot_locs = [rand(1:nb_locs) for i in 1:nb_veh]
    park_slots=2; # max nb parking slots at each hub location

    horizon = 200								
    tstep = 10;

    map_inputs= (map_title,hubs_id,vbs_id,nb_locs,cust_id,nb_cust,depot_locs,horizon,tstep,park_slots)
    
    return map_inputs
end

function create_inputs(map_type,benchmark)
    if benchmark["High capacity"]
        Q = 10 # vehicle capacity;
    else
        Q = 1
    end

    # Create Map Inputs
    if map_type == "clust_map_1"
        map_inputs = clust_map_1()
        Wk = 1500 # max walking time for customers from origin or to destination
    elseif map_type == "clust_map_2"
        map_inputs = clust_map_2()
        Wk = 1500 # max walking time for customers from origin or to destination
    elseif map_type == "clust_map_3"
        map_inputs = clust_map_3()
        Wk = 1500 # max walking time for customers from origin or to destination
    elseif map_type == "clust_map_4"
        map_inputs = clust_map_4()
        Wk = 1500 # max walking time for customers from origin or to destination
    elseif map_type == "clust_map_5"
        map_inputs = clust_map_5()
        Wk = 1500 # max walking time for customers from origin or to destination
    elseif map_type == "clust_map_all"
        map_inputs = clust_map_all()
        Wk = 1200 # max walking time for customers from origin or to destination
    
    elseif map_type == "unif_map_1"
        map_inputs = unif_map_1()
        Wk = 60 # max walking time for customers from origin or to destination
    elseif map_type == "unif_map_2"
        map_inputs = unif_map_2()
        Wk = 60 # max walking time for customers from origin or to destination
    elseif map_type == "unif_map_3"
        map_inputs = unif_map_3()
        Wk = 60 # max walking time for customers from origin or to destination
    elseif map_type == "unif_map_4"
        map_inputs = unif_map_4()
        Wk = 60 # max walking time for customers from origin or to destination
    elseif map_type == "unif_map_5"
        map_inputs = unif_map_5()
        Wk = 60 # max walking time for customers from origin or to destination
    elseif map_type == "unif_map_all"
        map_inputs = unif_map_all()
        Wk = 40 # max walking time for customers from origin or to destination
    else
        error("map_type not recognized")
    end

    return map_inputs,Wk,Q
end