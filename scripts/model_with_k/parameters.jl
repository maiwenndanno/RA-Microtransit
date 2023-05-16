include("shortestpath.jl")

function create_params(tsnetwork,hubs_ind, model_inputs, nb_locs,depot_locs,wo, wd,I,t,tstep,horizon,benchmark)
    G,Gtype,Wk,Q=model_inputs
    physicalarcs,shortest_time=tsnetwork.physicalarcs,tsnetwork.shortest_time
    vo, vd = create_vo_vd(wo, wd, Wk, I,benchmark);
    gamma = create_gamma(I,vo,vd,wo,wd,shortest_time,horizon);
    N, N_depot, N_star = create_Ns(tsnetwork.nodeid, tsnetwork.nodedesc, depot_locs, nb_locs);
    A, A_tilde_depot,Ai,notAi, deadlines = create_As(tsnetwork, physicalarcs, N_depot, shortest_time, gamma, I, nb_locs, vo, vd, wo,wd, t, G, Gtype,tstep,horizon)
    Ai_plus,Ai_minus=create_Aplus_minus_i(tsnetwork,I,Ai,N);
    Ia=create_Ia(I,A,Ai);
    P,P_T = create_paths(vo,vd,I,hubs_ind,wo,wd,benchmark);
    O, D, H = create_OHD_sets(N,I,P,t,gamma,tsnetwork.nodedesc,tstep,wo, wd,deadlines,shortest_time);
    N_vo, N_vd, N_except_vo_vd_H=create_N_vo_vd_H(N,vo,vd,I,P, H,tsnetwork.nodedesc);
    return (vo=vo, vd=vd, P=P, H=H, O=O, D=D, deadlines=deadlines,
            N_vo=N_vo, N_vd=N_vd, N_except_vo_vd_H=N_except_vo_vd_H, 
            P_T=P_T, A=A, Ai=Ai, notAi= notAi, Ai_plus=Ai_plus, Ai_minus=Ai_minus, Ia=Ia,
            A_tilde_depot=A_tilde_depot, N=N, N_depot=N_depot, N_star=N_star,gamma=gamma)
end

#-----------------------------------------------------------------------------------#
function create_Ns(nodeid,nodedesc, depot_locs,nb_locs)

    N=collect(values(nodeid)) # set of time-space nodes indices

    N_depot=Dict()
    N_star=Dict() # set of time-space nodes indices excluding the sink and the depot locs
    K=length(depot_locs)
    for k in 1:K
        N_depot[k]=Vector()
        N_star[k]=Vector()
        for n in N
            if nodedesc[n][1]==depot_locs[k]
                push!(N_depot[k], n)
            elseif nodedesc[n][1]!=nb_locs+1 # if not at sink location
                push!(N_star[k], n)
            end
        end
    end
    return N, N_depot, N_star

end

#-----------------------------------------------------------------------------------#
function create_Aplus_minus_i(tsn,I,Ai,N)
    Ai_plus=Dict()
    Ai_minus=Dict()
    for i in I
        Ai_plus[i]=Dict()
        Ai_minus[i]=Dict()
        for n in N
            Ai_plus[i][n]=Vector()
            Ai_minus[i][n]=Vector()
            for a in tsn.A_plus[n]
                if a in Ai[i]
                    push!(Ai_plus[i][n],a)
                end
            end
            for a in tsn.A_minus[n]
                if a in Ai[i]
                    push!(Ai_minus[i][n],a)
                end
            end
        end
    end
    return Ai_plus, Ai_minus
end
#-----------------------------------------------------------------------------------#

function create_As(tsn, physicalarcs, N_depot, shortest_time, gamma, I, nb_locs, vo, vd, wo, wd, t, G, Gtype,tstep,horizon)

    A=collect(values(tsn.arcid))
    veh=collect(keys(N_depot))

    # Only the traveling arcs from the depot
    A_tilde_depot=Dict()
    for k in veh
        A_tilde_depot[k]=Vector()
        for a in A
            if tsn.arcdesc[a][1] in N_depot[k] && !(tsn.arcdesc[a][2] in N_depot[k])
                push!(A_tilde_depot[k], a)
            end
        end
    end

    # Reduce the number of arcs for each customer with heuristic
    Ai,notAi,deadlines=reduce_arcs(tsn, physicalarcs, G, Gtype, vo, vd, wo, wd, t,shortest_time, gamma,nb_locs,I,tstep,horizon)
    return A,A_tilde_depot,Ai,notAi, deadlines
end

#---------------------------------------------------------------------------------------#
function create_Ia(I,A,Ai)
    Ia=Dict()
    for a in A
        Ia[a]=Vector() # List of customers that can use arc a
        for i in I
            if a in Ai[i]
                push!(Ia[a],i)
            end
        end
    end
    return Ia
end
#---------------------------------------------------------------------------------------#
function reduce_arcs(tsn, physicalarcs, G, Gtype, vo, vd, wo,wd, t, shortest_time,gamma,nb_locs,I,tstep,horizon)
    Ai=Dict()
    notAi=Dict() # = A minus A[i]

    deadlines=Dict()
    for i in I
	    Ai[i]=Vector(); # Set of arcs that are feasible for customer i to arrive at destination by the deadlines
        notAi[i]=Vector();

        #Set the deadlines by which we want the customer to arrive at his destination location
        if Gtype == "absolutetime"
            deadlines[i] = tstep * ceil(t[i]) + tstep*ceil((G+gamma[i]["best_full"])/tstep)
        elseif Gtype == "shortestpathpercent"
            deadlines[i] = tstep * ceil(t[i]/tstep) + tstep*ceil(((1+G)*gamma[i]["best_full"])/tstep)
        end
        if deadlines[i] > horizon
            deadlines[i] = horizon
        end

        #Create stationary arcs
        stationaryarcs = []
        for l in 1:nb_locs
            push!(stationaryarcs, (l, l, 0, tstep, tstep))
        end
        
        for arc in union(physicalarcs, stationaryarcs)
            loc1, loc2, loc1loc2_traveltime = arc[1], arc[2], arc[5]
            if loc2 <= nb_locs # we don't consider arcs to sink for customers
                if !(loc1 in vd[i])
                    t1 = tstep * ceil(minimum([wo[i,o]+shortest_time[o, loc1] for o in vo[i]])/tstep) # shortest time for cust to reach loc 1 from origin
                    t2 = loc1loc2_traveltime # shortest driving time from loc 1 to loc 2
                    t3 = tstep * ceil(minimum([wd[i,d]+shortest_time[loc2, d] for d in vd[i]])/tstep) #shortest time for cust to reach destination from loc 2 
                    
                    #Add time-space network arc at each time step t if it meets two criteria:
                    #  (i) We could reach loc1 by time t, leaving from origin at time no earlier than t_i
                    #  (ii) We could reach destination by the deadlines, after traveling from loc1 to loc2 at time t
                    for start in 0:tstep:horizon-t2
                        new=tsn.arcid[tsn.nodeid[loc1, start], tsn.nodeid[loc2, start + t2]]
                        if (t[i] + t1 <= start) & (start + t2 + t3 <= deadlines[i])
                            push!(Ai[i],new)	
                        else
                            push!(notAi[i], new)
                        end
                    end
                else
                    for start in 0:tstep:horizon-arc[5]
                        new=tsn.arcid[tsn.nodeid[loc1, start], tsn.nodeid[loc2, start + arc[5]]]
                        push!(notAi[i], new)
                    end
                end
            end
        end
    end
	return Ai,notAi,deadlines
end

#-----------------------------------------------------------------------------------#

function create_vo_vd(wo, wd, Wk, I,benchmark)

    vo = Dict() # dictionnaire of pick-up locations indices
    vd = Dict() # dictionnaire of drop-off locations indices
    for i in I
        if benchmark["Flexible"]
            # find all the locations that are within walking distance of the customer origin
            vo[i]=findall(x->x<=Wk, wo[i,:])
            #deleteat!(vo[i], findall(x->x==depot_loc, vo[i]))
            # find all the locations that are within walking distance of the customer destination
            vd[i]=findall(x->x<=Wk, wd[i,:])
            #deleteat!(vd[i], findall(x->x==depot_loc, vd[i]))
        else 
            vo[i]=argmin(wo[i,:])
            vd[i]=argmin(wd[i,:])
        end
    end
    return vo, vd

end

#-----------------------------------------------------------------------------------#

function create_paths(vo,vd,I,hubs_ind,wo,wd,benchmark)
    P=Dict() # dictionnaire of paths of all customers
    P_T=Dict()  # dictionnaire of indirect paths of all customers 
    for i in I
        P[i]=Vector()
        P_T[i]=Vector()
        for o in vo[i]
            for d in vd[i]
                if o!=d
                    direct_path=Dict("o"=>o,"d"=>d,"transfer"=>0,"walking"=>round(wo[i,o]+wd[i,d],digits=2)) 
                    push!(P[i], direct_path)
                    if benchmark["Transfer"]
                        for h in hubs_ind
                            if d!=h
                                transfer_path=Dict("o"=>o,"d"=>d,"h"=>h,"transfer"=>1,"walking"=> round(wo[i,o]+wd[i,d],digits=2))
                                push!(P[i], transfer_path)
                                push!(P_T[i], transfer_path)
                            end
                        end
                    end
                end
            end
        end
    end
    return P,P_T
end

#-----------------------------------------------------------------------------------#

function create_gamma(I,vo, vd, wo,wd,shortest_time,horizon)
    # Return shortest travel time (with walking distance to closest VBS and direct driving time)
    gamma=[]
    for i in I
        closest_vo=vo[i][1]
        closest_vd=vd[i][1]
        best_vo=vo[i][1]
        best_vd=vd[i][1]
        for j in vo[i]
            if wo[i,j]<wo[i,closest_vo]
                closest_vo=j
            end
        end
        for j in vd[i]
            if wd[i,j]<wd[i,closest_vd]
                closest_vd=j
            end
        end
        best_full=horizon
        for jo in vo[i]
            for jd in vd[i]
                full=wo[i,jo]+wd[i,jd]+shortest_time[jo,jd]
                if full<best_full
                    best_full=full
                    best_vo=jo 
                    best_vd=jd
                end
            end
        end
        push!(gamma,Dict("closest_vo"=> closest_vo, "closest_vd"=> closest_vd, "best_full"=> best_full, "best_vo"=> best_vo, "best_vd"=> best_vd))
    end
    return gamma
end

#-----------------------------------------------------------------------------------#

function create_OHD_sets(N,I,P,t,gamma,nodedesc,tstep,wo, wd,deadlines, shortest_time)
    # Wk: max malking time
    # Wt: max waiting time at pick-up
    # G: Detour ratio for driving time
    O=Dict() # dictionnaire of pick-up nodes indices for each customer and each path
    D=Dict() # dictionnaire of drop-off nodes indices for each customer and each path
    H=Dict() # dictionnaire of transfer nodes indices for each customer and each path

    for i in I
        O[i], D[i], H[i]=Dict(), Dict(), Dict()

        for p in P[i]
            O_ip, D_ip, H_ip=Vector(), Vector(), Vector()
            for n in N
                node=nodedesc[n]
                if node[1] in p["o"] && (node[2]<=deadlines[i]-(gamma[i]["best_full"]-wo[i,node[1]])) && (node[2]>=t[i]+wo[i,node[1]])
                    # gamma[i]["best_full"]-wo[i,node[1]] is a lower bound of the remaining travel time from this pick-up vbs
                    push!(O_ip, n)
                end
                if node[1] in p["d"] && (node[2]<=deadlines[i]-wd[i,node[1]]) && (node[2]>=tstep * ceil((t[i]+wo[i,gamma[i]["best_vo"]])/tstep)+shortest_time[gamma[i]["best_vo"],node[1]])
                    push!(D_ip, n)
                else
                    if p["transfer"]==1 # if transfer
                        if node[1] in p["h"] 
                            push!(H_ip, n)
                        end
                    end
                end
            end
            O[i][p]=O_ip
            D[i][p]=D_ip
            H[i][p]=H_ip

        end
    end
    return O, D, H
end

#-----------------------------------------------------------------------------------#

function create_N_vo_vd_H(N,vo,vd,I,P, H_ind,nodedesc)
    # Create the dictionaries of nodes at pick-up and drop-off locations
    N_vo=Dict() # dictionnaire of nodes at pick-up locations
    N_vd=Dict() # dictionnaire of nodes at drop-off locations
    N_except_vo_vd_H=Dict() # dictionnaire of nodes except pick-up and drop-off locations
    for i in I
        N_vo[i]=Vector()
        N_vd[i]=Vector()
        N_except_vo_vd_H[i]=Dict()
        for p in P[i]
            N_except_vo_vd_H[i][p]=Vector()
            for n in N
                node=nodedesc[n]
                if node[1] in vo[i]
                    push!(N_vo[i], n)
                elseif node[1] in vd[i]
                    push!(N_vd[i], n)
                elseif !(node[1] in H_ind[i][p])
                    push!(N_except_vo_vd_H[i][p], n)
                end
            end
        end
    end
    return N_vo, N_vd, N_except_vo_vd_H
end

# -----------------------------------------------------------------------------------#
# Return the start time of an arc (index type)
function getT(a,tsnetwork)
	return tsnetwork.nodedesc[tsnetwork.arcdesc[a][1]][2]
end

# -----------------------------------------------------------------------------------#
# Return the start location index of a node (index type)
function getL(n,tsnetwork)
	return tsnetwork.nodedesc[n][1]
end

# -----------------------------------------------------------------------------------#
function get_wo(i,node,tsnetwork,wo)
    return wo[i,getL(node,tsnetwork)]
end

# -----------------------------------------------------------------------------------#
# Return the arcs that are stationary at a hub location
#function getA_H_noH(A,hubs_ind)
#    A_H=Vector()
#    A_noH=Vector()
#    for a in A
#        if getL(arcdesc[a][1])==getL(arcdesc[a][2]) && getL(arcdesc[a][1]) in hubs_ind
#            push!(A_H, a)
#        else
#            push!(A_noH, a)
#        end
#    end
#    return A_H, A_noH
#end