# import pandas library as pd
import pandas as pd
import os

#Inputs
dr_speed = 2 # nb of minutes per km when driving;
wk_speed = 12 # nb of minutes per km when walking;
    
# LOCATIONS
# ------------------ BASIC CASE: 7 VBS + 1 DEPOT
def gen_loc_basic(loc_file_path):
    # hubs at index 4,5,6
    locations = pd.DataFrame([[1,0,0],[2,1,3],[3,1,1],[4,5,3],[5,5,2],[6,5,1],[7,9,3],[8,9,1]], columns = ['id', 'x', 'y'])
    # Add "sink" node at the end (index 999)
    # locations=pd.concat([locations,pd.DataFrame([["sink",0,0]], columns = ['id', 'x', 'y'])], ignore_index = True)
    
    locations.to_csv(loc_file_path,index=False)
    return locations
        
# ------------------ VBS CASE 1 : 10 VBS incl 2 HUBS + 1 DEPOT
def gen_loc_uniform_10(loc_file_path):
    # hubs at index 6,7
    locations = pd.DataFrame([[1,3,-1],
                              [2,1,1],
                              [3,1,5],
                              [4,3,3],
                              [5,3,7],
                              [6,5,1],
                              [7,5,5],
                              [8,7,3],
                              [9,7,7], 
                              [10,9,1],
                              [11,9,5]], columns = ['id', 'x', 'y'])
    # Add sink node at the end (index 999)
    #locations=pd.concat([locations,pd.DataFrame([["sink",0,0]], columns = ['id', 'x', 'y'])], ignore_index = True)

    locations.to_csv(loc_file_path,index=False)
    return locations   

# ------------------ VBS CASE 2 : 20 VBS incl 4 HUBS + 1 DEPOT
def gen_loc_uniform_20(loc_file_path):
    # hubs at index 6,7,16,17
    locations = pd.DataFrame([[1,2,1],
                              [2,2,5],
                              [3,6,3],
                              [4,6,7],
                              [5,10,1],
                              [6,10,5],
                              [7,14,3],
                              [8,14,7], 
                              [9,18,1],
                              [10,18,5],
                              [11,2,3], 
                              [12,2,7],
                              [13,6,1],
                              [14,6,5],
                              [15,10,3],
                              [16,10,7],
                              [17,14,1],
                              [18,14,5], 
                              [19,18,3],
                              [20,18,7]], columns = ['id', 'x', 'y'])
    # Add sink node at the end (index 999)
    #locations=pd.concat([locations,pd.DataFrame([["sink",0,0]], columns = ['id', 'x', 'y'])], ignore_index = True)
    
    locations.to_csv(loc_file_path,index=False)
    return locations   

def gen_loc_uniform_30_BIG(loc_file_path):
    vbs_list = []
    for i in range(1,11,1): # from 1 to 10
        for j in range(1,4): # from 1 to 3
            vbs_list.append([3*(i-1)+j,i*1.6,2.5*(j-1)])
    locations = pd.DataFrame(vbs_list, columns = ['id', 'x', 'y'])
    # Add sink node at the end (index 999)
    #locations=pd.concat([locations,pd.DataFrame([["sink",0,0]], columns = ['id', 'x', 'y'])], ignore_index = True)
    
    locations.to_csv(loc_file_path,index=False)
    return locations

    
# CUSTOMERS
# ----------------- BASIC CASE: 10 CUST, going from left to right
def gen_cust_basic(cust_file_path):
    cust = pd.DataFrame(columns = ['cust_id', 'x_o', 'y_o', 'x_d', 'y_d', 'depart_time', 'load'])
    # 7 customers whose origin is uniformely distributed between (0.5,0) and (1.5,4) and whose destination is uniformely distributed between (8.5,0) and (9.5,4)
    for i in range(7):
        x_o=i/6*1+0.5
        y_o=i/6*4
        x_d=i/6*1+8.5
        y_d=i/6*4
        time=i/6*20 # between 0 and 5 minutes
        load=1
        cust=pd.concat([cust,pd.DataFrame([[str(i+1),x_o,y_o, x_d, y_d, time, load]], columns=['cust_id','x_o','y_o','x_d', 'y_d','depart_time','load'])], ignore_index = True)
    # 3 customers whose origin is uniformely distributed between (4.5,0) and (5.5,4) and whose destination is uniformely distributed between (8.5,0) and (9.5,4)
    for i in range(3):
        x_o=i/2*1+4.5
        y_o=i/2*4
        x_d=i/2*1+8.5
        y_d=i/2*4
        time=i/2*20 # between 0 and 5 minutes
        load=1
        cust=pd.concat([cust,pd.DataFrame([[str(i+8),x_o,y_o, x_d, y_d, time, load]], columns=['cust_id','x_o','y_o','x_d', 'y_d','depart_time','load'])], ignore_index = True)

    cust.to_csv(cust_file_path,index=False)
    return cust

# ------------------ CUST CASE 1 : 5 UNIF CUST, going from left (origins uniformly distributed in left half) to right (origins uniformly distributed in right half)
def gen_cust_uniform_5(cust_file_path):
    cust = pd.DataFrame(columns = ['cust_id', 'x_o', 'y_o', 'x_d', 'y_d', 'depart_time', 'load'])
    # 5 customers whose origin is uniformely distributed between (0,0) and (2,8) and whose destination is uniformely distributed between (8,0) and (10,8)
    for i in range(5):
        x_o=i/4*2
        y_o=i/4*8
        x_d=i/4*2+8
        y_d=i/4*8
        time=i/6*20 # between 0 and 5 minutes
        load=1
        cust=pd.concat([cust,pd.DataFrame([[str(i+1),x_o,y_o, x_d, y_d, time, load]], columns=['cust_id','x_o','y_o','x_d', 'y_d','depart_time','load'])], ignore_index = True)
    cust.to_csv(cust_file_path,index=False)
    return cust

# ------------------ CUST CASE 2 : 20 UNIF CUST, 10 going from left (origins uniformly distributed in left half) to right (origins uniformly distributed in right half), 5 from botton to left, 5 from right to left
def gen_cust_uniform_20(cust_file_path):
    cust = pd.DataFrame(columns = ['cust_id', 'x_o', 'y_o', 'x_d', 'y_d', 'depart_time', 'load'])
    # 5 customers whose origin is uniformely distributed between (0,0) and (2,8) and whose destination is uniformely distributed between (8,0) and (10,8)
    for i in range(5):
        x_o=i/4*2
        y_o=i/4*6+0.5
        x_d=i/4*1.5+17
        y_d=i/4*6+0.5
        time=i/4*20 # between 0 and 5 minutes
        load=1
        cust=pd.concat([cust,pd.DataFrame([[str(i+1),x_o,y_o, x_d, y_d, time, load]], columns=['cust_id','x_o','y_o','x_d', 'y_d','depart_time','load'])], ignore_index = True)
    # 5 customers whose origin is uniformely distributed between (4,0) and (6,8) and whose destination is uniformely distributed between (9,0) and (10,8)
    for i in range(5):
        x_o=i/4*2+5
        y_o=i/4*4+1.5
        x_d=i/4*1+14
        y_d=(4-i)/4*5+2.5
        time=i/4*20 # between 0 and 5 minutes
        load=1
        cust=pd.concat([cust,pd.DataFrame([[str(i+6),x_o,y_o, x_d, y_d, time, load]], columns=['cust_id','x_o','y_o','x_d', 'y_d','depart_time','load'])], ignore_index = True)
    # 5 customers from bottom to top
    for i in range(5):
        x_o=i/4*2+9
        y_o=i/4*3 + 1
        x_d=i/4*8+5
        y_d=i/4*0.5+6
        time=i/4*20 # between 0 and 5 minutes
        load=1
        cust=pd.concat([cust,pd.DataFrame([[str(i+11),x_o,y_o, x_d, y_d, time, load]], columns=['cust_id','x_o','y_o','x_d', 'y_d','depart_time','load'])], ignore_index = True)
    # 5 customers from right to left
    for i in range(5):
        x_o=i/4*2+15
        y_o=(4-i)/4*6+1
        x_d=i/4*5
        y_d=i/4*2+1
        time=i/4*20 # between 0 and 5 minutes
        load=1
        cust=pd.concat([cust,pd.DataFrame([[str(i+16),x_o,y_o, x_d, y_d, time, load]], columns=['cust_id','x_o','y_o','x_d', 'y_d','depart_time','load'])], ignore_index = True)
    cust.to_csv(cust_file_path,index=False)
    return cust

def gen_cust_uniform_20_1way(cust_file_path): # 20 customers form left to right
    cust = pd.DataFrame(columns = ['cust_id', 'x_o', 'y_o', 'x_d', 'y_d', 'depart_time', 'load'])
    # 10 customers whose origin is uniformely distributed between (0,0) and (2,8) and whose destination is uniformely distributed between (8,0) and (10,8)
    for i in range(10):
        x_o=i/9*2+1
        y_o=i/9*6+0.5
        x_d=i/9*2+13
        y_d=i/9*6.5+0.5
        time=i/9*10+5 # between 5 and 15 minutes
        load=1
        cust=pd.concat([cust,pd.DataFrame([[str(i+1),x_o,y_o, x_d, y_d, time, load]], columns=['cust_id','x_o','y_o','x_d', 'y_d','depart_time','load'])], ignore_index = True)
    # 10 customers whose origin is uniformely distributed between (4,0) and (6,8) and whose destination is uniformely distributed between (9,0) and (10,8)
    for i in range(10):
        x_o=i/9*2+4
        y_o=i/9*6+0.5
        x_d=i/9*1+18
        y_d=(9-i)/9*5+0.5
        time=i/9*10 +5 # between 5 and 15 minutes
        load=1
        cust=pd.concat([cust,pd.DataFrame([[str(i+11),x_o,y_o, x_d, y_d, time, load]], columns=['cust_id','x_o','y_o','x_d', 'y_d','depart_time','load'])], ignore_index = True)
    cust.to_csv(cust_file_path,index=False)
    return cust

# ------------------ CUST CASE 3 : 10 CUST CLUSTERISES
def gen_cust_clust_10(cust_file_path):
    cust = pd.DataFrame(columns = ['cust_id', 'x_o', 'y_o', 'x_d', 'y_d', 'depart_time', 'load'])
    # Cluster 1 : 5 customers whose origin is uniformely distributed between (1,0) and (3,2) and 3 of them go to (9,0) and 2 of them go to (9,8)
    for i in range(5):
        x_o=i/4*2+1
        y_o=i/4*2
        if i <=2:
            x_d=15
            y_d=0
        else:
            x_d=16
            y_d=8
        time=i/4*20 # between 0 and 5 minutes
        load=1
        cust=pd.concat([cust,pd.DataFrame([[str(i+1),x_o,y_o, x_d, y_d, time, load]], columns=['cust_id','x_o','y_o','x_d', 'y_d','depart_time','load'])], ignore_index = True)
    # Cluster 2 : 5 customers whose origin is uniformely distributed between (1,6) and (3,8) and 2 of them go to (9,0) and 3 of them go to (9,8)
    for i in range(5):
        x_o=i/4*2+1
        y_o=i/4*2+6
        if i <=1:
            x_d=18
            y_d=0
        else:
            x_d=17
            y_d=8
        time=i/4*20 # between 0 and 5 minutes
        load=1
        cust=pd.concat([cust,pd.DataFrame([[str(i+6),x_o,y_o, x_d, y_d, time, load]], columns=['cust_id','x_o','y_o','x_d', 'y_d','depart_time','load'])], ignore_index = True)
    cust.to_csv(cust_file_path,index=False)
    return cust

def gen_cust_clust_20_BIG(cust_file_path):
    cust = pd.DataFrame(columns = ['cust_id', 'x_o', 'y_o', 'x_d', 'y_d', 'depart_time', 'load'])
    # Cluster 1 : 5 customers whose origin is uniformely distributed between (95,25) and (105,35) and 3 of them go around (700,20) and 2 of them go around (900,30)
    for i in range(5):
        x_o=i/4*0.25+1.5
        y_o=i/4*2 +3.5
        if i <=2:
            x_d=11+0.4*i
            y_d=2+i
        else:
            x_d=14+0.2*i
            y_d=4 + 0.25*i
        time=0
        load=1
        cust=pd.concat([cust,pd.DataFrame([[str(i+1),x_o,y_o, x_d, y_d, time, load]], columns=['cust_id','x_o','y_o','x_d', 'y_d','depart_time','load'])], ignore_index = True)
    # Cluster 2 : 5 customers whose origin is uniformely distributed between (95,5) and (105,10) and 3 of them go around (900,20) and 2 of them go around (300,0)
    for i in range(5):
        x_o=i/4*0.2+1.3
        y_o=i/4*1 + 0.4
        if i <=2:
            x_d=12+0.1*i
            y_d=2 +0.3*i
        else:
            x_d=5+0.1*i
            y_d=0.1+0.04*i
        time=0 
        load=1
        cust=pd.concat([cust,pd.DataFrame([[str(i+6),x_o,y_o, x_d, y_d, time, load]], columns=['cust_id','x_o','y_o','x_d', 'y_d','depart_time','load'])], ignore_index = True)
    # Cluster 3 : 5 customers whose origin is uniformely distributed between (95,10) and (105,15) and all of them go around (600,0) 
    for i in range(5):
        x_o=i/4*0.3+1.4
        y_o=i/4*1.4 + 2.5
        x_d=11+0.15*i
        y_d=2.5 + 0.8*i
        time=6*dr_speed
        load=1
        cust=pd.concat([cust,pd.DataFrame([[str(i+11),x_o,y_o, x_d, y_d, time, load]], columns=['cust_id','x_o','y_o','x_d', 'y_d','depart_time','load'])], ignore_index = True)
    # Cluster 5 : 5 customers whose origin is uniformely distributed between (495,20) and (505,25) and all of them go around (700,20) 
    for i in range(5):
        x_o=i/4*0.2+3.2
        y_o=i/4*1.1 +3
        x_d=14+0.3*i
        y_d=1.6+ 0.4*i
        time=7*dr_speed
        load=1
        cust=pd.concat([cust,pd.DataFrame([[str(i+16),x_o,y_o, x_d, y_d, time, load]], columns=['cust_id','x_o','y_o','x_d', 'y_d','depart_time','load'])], ignore_index = True)
    
    cust.to_csv(cust_file_path,index=False)
    return cust
    
# --------------------- MAIN -------------------
def gen_folder(vbs_type, cust_type):
    if vbs_type=="vbs_basic" and cust_type=="cust_basic":
        folder='1_data/basic/'
    elif vbs_type=="vbs_U20" and cust_type=="cust_U20":
        folder='1_data/map_unif_small/'
    elif vbs_type=="vbs_U20" and cust_type=="cust_U20_1way":
        folder='1_data/map_unif_small_1way/'
    elif vbs_type=="vbs_U20" and cust_type=="cust_C10":
        folder='1_data/map_cluster_small/'
    elif vbs_type=="vbs_U30_BIG" and cust_type=="cust_C20_BIG":
        folder='1_data/map_cluster_BIG/'
    else:
        folder='1_data/'+vbs_type+'_'+cust_type+'/'
    if not os.path.exists(folder):
        os.makedirs(folder)    
    
    if vbs_type=="vbs_basic":
        locations=gen_loc_basic(folder+'locations.csv')
    elif vbs_type=="vbs_U10":
        locations=gen_loc_uniform_10(folder+'locations.csv')
    elif vbs_type=="vbs_U20":
        locations=gen_loc_uniform_20(folder+'locations.csv')
    elif vbs_type=="vbs_U30_BIG":
        locations=gen_loc_uniform_30_BIG(folder+'locations.csv')
    
    if cust_type=="cust_basic":
        cust=gen_cust_basic(folder+'customers.csv')  
    elif cust_type=="cust_U5":
        cust=gen_cust_uniform_5(folder+'customers.csv')
    elif cust_type=="cust_U20":
        cust=gen_cust_uniform_20(folder+'customers.csv')
    elif cust_type=="cust_U20_1way":
        cust=gen_cust_uniform_20_1way(folder+'customers.csv')
    elif cust_type=="cust_C10":
        cust=gen_cust_clust_10(folder+'customers.csv')
    elif cust_type=="cust_C20_BIG":
        cust=gen_cust_clust_20_BIG(folder+'customers.csv')
    
## BASIC MAP
#gen_folder("vbs_basic", "cust_basic")

## MAP 1: 10 VBS UNIFORM & 5 CUST UNIFORM
#gen_folder("vbs_U10", "cust_U5")

## MAP 2: 10 VBS UNIFORM & 10 CUST UNIFORM
#gen_folder("vbs_U10", "cust_U10")

## MAP 3: 20 VBS UNIFORM & 20 CUST UNIFORM
gen_folder("vbs_U20", "cust_U20")

## MAP 3b: 20 VBS UNIFORM & 20 CUST UNIFORM 1 dir left => right
gen_folder("vbs_U20", "cust_U20_1way")

## MAP 4: 20 VBS UNIFORM & 20 CUST CLUSTERED
#gen_folder("vbs_U20", "cust_C10")

# MAP 5 : HARD - 30 VBS UNIFORM & 20 CUST CLUSTERED
gen_folder("vbs_U30_BIG", "cust_C20_BIG")
