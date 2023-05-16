include("shortestpath.jl")

function create_params(tsnetwork,locs_id, model_inputs, wo, wd,I,t,tstep,horizon,benchmark)
    G,Gtype,Wk,Q=model_inputs
    vo, vd = create_vo_vd(wo, wd, Wk, I,benchmark);
    gamma = create_gamma(I,vo,vd,wo,wd,tsnetwork.shortest_time,horizon);
    N, N_depot, N_star,N_except_sink = create_Ns(tsnetwork.nodeid, tsnetwork.nodedesc, locs_id);
    A, A_tilde_depot,Ai, deadlines = create_As(tsnetwork, locs_id, N_depot, gamma, I, vo, vd, wo,wd, t, G, Gtype,tstep,horizon)
    Ai_plus,Ai_minus,Ai_minus_tilde=create_Aplus_minus_i(tsnetwork,I,Ai,N);
    Ia=create_Ia(I,A,Ai);
    P,P_T = create_paths(vo,vd,I,locs_id,wo,wd,benchmark);
    O, D, H, H_times = create_OHD_sets(N,I,P,t,gamma,tsnetwork.nodedesc,tstep,wo, wd,deadlines,tsnetwork.shortest_time, horizon);
    Ai_except_H=create_Ai_except_H(Ai,I,P,tsnetwork);
    N_vo, N_vd, N_except_vo_vd_H=create_N_vo_vd_H(N,vo,vd,I,P, H,tsnetwork.nodedesc);
    return (vo=vo, vd=vd, P=P, H=H, H_times=H_times, O=O, D=D, deadlines=deadlines,
            N_vo=N_vo, N_vd=N_vd, N_except_vo_vd_H=N_except_vo_vd_H, N_except_sink=N_except_sink,
            P_T=P_T, A=A, Ai=Ai, Ai_plus=Ai_plus, Ai_minus=Ai_minus, Ai_minus_tilde=Ai_minus_tilde, Ia=Ia, Ai_except_H=Ai_except_H,
            A_tilde_depot=A_tilde_depot, N=N, N_depot=N_depot, N_star=N_star,gamma=gamma)
end

#-----------------------------------------------------------------------------------#
function create_Ns(nodeid,nodedesc, locs_id)

    N=collect(values(nodeid)) # set of time-space nodes indices

    N_depot=Dict()
    for d in locs_id.depots # depot indices
        N_depot[d]=Vector()
    end

    N_except_sink=Vector() # set of time-space nodes indices excluding the sink
    N_star=Vector() # set of time-space nodes indices excluding the sink and the depot locs

    for n in N
        if !(nodedesc[n][1] in locs_id.sink) # if not at sink location
            push!(N_except_sink, n)
            if nodedesc[n][1] in locs_id.depots # neither at depot location
                push!(N_depot[nodedesc[n][1]], n)
            else
                push!(N_star, n)
            end
        end
    end
    return N, N_depot, N_star, N_except_sink

end

#-----------------------------------------------------------------------------------#
function create_Aplus_minus_i(tsn,I,Ai,N)
    Ai_plus=Dict()
    Ai_minus=Dict()
    Ai_minus_tilde=Dict()
    for i in I
        Ai_plus[i]=Dict()
        Ai_minus[i]=Dict()
        Ai_minus_tilde[i]=Dict()
        for n in N
            Ai_plus[i][n]=Vector()
            Ai_minus[i][n]=Vector()
            Ai_minus_tilde[i][n]=Vector()
            for a in tsn.A_plus[n]
                if a in Ai[i]
                    push!(Ai_plus[i][n],a)
                end
            end
            for a in tsn.A_minus[n]
                if a in Ai[i]
                    push!(Ai_minus[i][n],a)
                    if tsn.nodedesc[tsn.arcdesc[a][1]][1]!=tsn.nodedesc[tsn.arcdesc[a][2]][1] # if traveling arcs
                        push!(Ai_minus_tilde[i][n],a)
                    end
                end
            end
        end
    end
    return Ai_plus, Ai_minus, Ai_minus_tilde
end
#-----------------------------------------------------------------------------------#

function create_As(tsn, locs_id, N_depot, gamma, I, vo, vd, wo, wd, t, G, Gtype,tstep,horizon)

    A=collect(values(tsn.arcid))
    depots=collect(keys(N_depot))

    # Only the traveling arcs from the depot d
    A_tilde_depot=Dict()
    for d in depots
        A_tilde_depot[d]=Vector()
        for a in A
            if tsn.arcdesc[a][1] in N_depot[d] && !(tsn.arcdesc[a][2] in N_depot[d])
                push!(A_tilde_depot[d], a)
            end
        end
    end

    # Reduce the number of arcs for each customer with heuristic
    Ai,deadlines=reduce_arcs(tsn, locs_id, G, Gtype, vo, vd, wo, wd, t, gamma,I,tstep,horizon)
    return A,A_tilde_depot,Ai, deadlines
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
function reduce_arcs(tsn, locs_id, G, Gtype, vo, vd, wo,wd, t,gamma,I,tstep,horizon)
    Ai=Dict()
    notAi=Dict() # = A minus A[i]

    shortest_time=tsn.shortest_time
    physicalarcs=tsn.physicalarcs

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
        vbs_locs=locs_id.all  # all locations where passengers can travel (no depot or sink)
        stationaryarcs = []
        for l in vbs_locs
            push!(stationaryarcs, (l, l, 0, tstep, tstep))
        end
        
        for arc in union(physicalarcs, stationaryarcs)
            loc1, loc2, loc1loc2_traveltime = arc[1], arc[2], arc[5]
            if !(loc2 in locs_id.sink) && !(loc1 in locs_id.depots) # No arc from depot or to sink
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
                end
            end
        end
    end
	return Ai,deadlines
end

#-----------------------------------------------------------------------------------#

function create_vo_vd(wo, wd, Wk, I,benchmark)

    vo = Dict() # dictionnaire of pick-up locations indices
    vd = Dict() # dictionnaire of drop-off locations indices
    # select the closest pick-up and drop-off locations for each customer
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

function create_paths(vo,vd,I,locs_id,wo,wd,benchmark)
    hubs_ind=locs_id.hubs # not duplicated
    P=Dict() # dictionnaire of paths of all customers
    P_T=Dict()  # dictionnaire of indirect paths of all customers 
    for i in I
        P[i]=Vector()
        P_T[i]=Vector()
        for o in vo[i]
            for d in vd[i]
                if o!=d
                    direct_path=Dict("o"=>o,"d"=>d,"transfer"=>0,"walking"=>round(wo[i,o]+wd[i,d],digits=2),"wo"=> round(wo[i,o],digits=2),"wd"=> round(wd[i,d],digits=2))
                    push!(P[i], direct_path)
                    if benchmark["Transfer"]
                        for h in hubs_ind
                            if !(d in locs_id.similar_hubs[h]) # If h == d, no transfer possible
                                transfer_path=Dict("o"=>o,"d"=>d,"h"=>locs_id.similar_hubs[h],"transfer"=>1,"walking"=> round(wo[i,o]+wd[i,d],digits=2), "wo"=> round(wo[i,o],digits=2),"wd"=> round(wd[i,d],digits=2))
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

function create_OHD_sets(N,I,P,t,gamma,nodedesc,tstep,wo, wd,deadlines, shortest_time, horizon)
    # Wk: max malking time
    # Wt: max waiting time at pick-up
    # G: Detour ratio for driving time
    O=Dict() # dictionnaire of pick-up nodes indices for each customer and each path
    D=Dict() # dictionnaire of drop-off nodes indices for each customer and each path
    H=Dict() # dictionnaire of transfer nodes indices for each customer and each path
    H_times=Dict() # dictionnaire of transfer nodes indices for each customer and each path at time t
    for i in I
        O[i], D[i], H[i], H_times[i]=Dict(), Dict(), Dict(), Dict()

        for p in P[i]
            O_ip, D_ip, H_ip, H_times_ip=Vector(), Vector(), Vector(), Dict()
            for t in 0:tstep:horizon
                H_times_ip[t]=Vector()
            end
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
                            push!(H_times_ip[node[2]], n)
                        end
                    end
                end
            end
            O[i][p]=O_ip
            D[i][p]=D_ip
            H[i][p]=H_ip
            H_times[i][p]=H_times_ip
        end
    end
    return O, D, H, H_times
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
function create_Ai_except_H(Ai,I,P,tsnetwork)
    # Remove from Ai any arcs that is stationnary at a hub location of the select path p
    Ai_except_H=Dict()
    for i in I
        Ai_except_H[i]=Dict()
        for p in P[i]
            if p["transfer"]==0
                Ai_except_H[i][p]=Ai[i] # We do not remove any arcs
            else 
                hubs=p["h"]
                Ai_except_H[i][p]=Vector()
                for a in Ai[i]
                    n_start=tsnetwork.arcdesc[a][1]
                    n_end=tsnetwork.arcdesc[a][2]
                    if !(getL(n_start,tsnetwork) in hubs) || (getL(n_start,tsnetwork)!=getL(n_end,tsnetwork)) 
                        # We keep the arcs that are not stationnary at a hub location
                        push!(Ai_except_H[i][p], a)
                    end
                end
            end
        end
    end
    return Ai_except_H
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


