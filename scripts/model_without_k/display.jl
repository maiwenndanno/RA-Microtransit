include("parameters.jl")

function create_map(locs, cust, locs_id)
    map = Plots.plot()
    colors= ["lightskyblue","lime","magenta","mediumblue","mintcream","mistyrose","moccasin","navy","olive","chocolate4","coral","cornflowerblue","cornsilk4","cyan","darkblue","darkcyan","darkgoldenrod", "deeppink","deepskyblue","dodgerblue","firebrick","forestgreen","fuchsia","gainsboro","goldenrod","gray"]
    hubs_id=locs_id.hubs
    classic_vbs_id=locs_id.classic_vbs

    # plot hubs
    scatter!(locs[hubs_id,:x], locs[hubs_id,:y],label="hubs", color="red", markersize=4,legend=:outertopright)
    # plot all the other vbs locations
    scatter!(locs[classic_vbs_id,:x], locs[classic_vbs_id,:y],label="vbs", color="black", markersize=4,legend=:outertopright)
    #plot!(map,locs[classic_vbs_id,:x], locs[classic_vbs_id,:y], seriestype=:scatter, label="classic VBS", color="black", text= locs[classic_vbs_id,:loc_id], markersize=4,legend=:outertopright)
    for i in classic_vbs_id
        annotate!(
            locs[i,:x], 
            locs[i,:y] + 0.5, 
            Plots.text("$i",8)
        )
    end
    for i in hubs_id
        annotate!(
                locs[i,:x], 
                locs[i,:y] + 0.5, 
                Plots.text("$i",8)
            )
    end
    # For each customer, plot the origin and destination point in the same color
    scatter!(cust[!,:x_o], cust[!,:y_o], markershape=:star5, color=colors[1:size(cust)[1]], label="Customers origin")#label="Cust $i o",legend=:outertopright
    scatter!(cust[!,:x_d], cust[!,:y_d], markershape=:diamond, color=colors[1:size(cust)[1]],label="Customers dest") #label="Cust $i d",legend=:outertopright
    #end  
    plot!(title="VBS Locations and Customer Origins/Destinations",titlefontsize=10)
    return map
end

function plot_obj_time(obj,solvetime,x_values,x_axis)
    # x_axis: string
    plt=plot()
    plot!(x_values,[obj,solvetime], label=["Obj" "Cost"], xlabel=x_axis,legend=:bottom)
    plot!(title="Objective value and solving time",titlefontsize=10)
    return plt
end

function display_KPIs(xi,x,z,tsnetwork,params,I,q,wo,t,locs_id,print_all)
    cust_KPIs_details,cust_KPIs=print_cust_KPIs(xi,x,tsnetwork,params,I,wo,t,print_all)
    veh_KPIs=print_veh_KPIs(x,z,params,tsnetwork,q, locs_id,print_all)
    return cust_KPIs_details,cust_KPIs, veh_KPIs
end

function print_cust_KPIs(xi,x,tsnetwork,params,I,wo,t,print_all)
    Ai=params.Ai
    Ia=params.Ia
    P=params.P
    c=tsnetwork.arccost
    nb_transfers=[]
    waiting_time=[]
    walking_time=[]
    idle_time=[]
    travel_time=[]
    efficiency=[]

    cust_KPIs_details=Dict()
    for i in I
        p_used=[p for p in P[i] if xi[i,p]==1][1]
        o=p_used["o"]
        d=p_used["d"]
        transfer=p_used["transfer"]

        push!(nb_transfers,p_used["transfer"])

        travel= sum(c[a]*x[i,a,p_used] for a in Ai[i])
        push!(travel_time,travel)

        walking= p_used["walking"]
        push!(walking_time,walking)

        wait=sum((getT(a,tsnetwork)-t[i]-p_used["wo"])*x[i,a,p_used] for n in params.O[i][p_used] for a in params.Ai_plus[i][n])
        push!(waiting_time,wait)

        ratio=params.gamma[i]["best_full"]/(travel+walking+wait)
        push!(efficiency,ratio)
        
        if print_all
            println("Customer $i:")
            if transfer==0
                println(" \t Path: from $o to $d without transfer")
            else
                h=p_used["h"]
                println(" \t Path: from $o to $d with transfer at $h")
            end

            println("\t Driving time : ", round(travel))
            println("\t Walking time : ", round(walking), " ,incl ", p_used["wo"], " to pick-up loc")
            println("\t Waiting time : ", round(wait, digits=2))
            println("\t Efficiency : ", round(ratio, digits=2))
        end
        cust_KPIs_details[i]=Dict("travel"=> round(travel), "walking"=> string(round(walking))*" ,incl "*string(p_used["wo"])*" to pick-up loc", "waiting"=> round(wait, digits=2), "efficiency"=> round(ratio, digits=2))
        # Add idle time later
    end
    
    # compute averages
    avg_nb_transfers=round(mean(nb_transfers),digits=2)
    avg_waiting_time=round(mean(waiting_time),digits=2)
    avg_walking_time=round(mean(walking_time),digits=2)
    #avg_idle_time=mean(idle_time)
    avg_travel_time=round(mean(travel_time),digits=2)
    avg_efficiency=round(mean(efficiency),digits=2)

    if print_all
        println("\n Customer KPIs:")
        println("Mean #transfers: ", avg_nb_transfers)
        println("Mean waiting time: ", avg_waiting_time)
        println("Mean walking time: ", avg_walking_time)
        #println("Mean idle time: ", round(avg_idle_time))
        println("Mean travel time: ", avg_travel_time)
        println("Mean efficiency: ", avg_efficiency)
    end

    return cust_KPIs_details, Dict("Mean #transfers"=> avg_nb_transfers, 
                    "Mean waiting time"=> avg_waiting_time, 
                    "Mean walking time"=> avg_walking_time, 
                    "Mean travel time"=> avg_travel_time, 
                    "Mean efficiency"=> avg_efficiency)
end

function cap(q,a,params)
    if length(params.Ia[a])>0
        cap = sum(q[i]*x[i,a,p] for i in params.Ia[a] for p in params.P[i])
    else
        cap =0
    end
    return cap
end

function print_veh_KPIs(x,z,params,tsnetwork,q, locs_id, print_all)
    A_tilde_depot=params.A_tilde_depot
    dist=tsnetwork.dist
    arccost=tsnetwork.arccost

    depots=locs_id.depots
    nb_veh=sum(z[a] for d in depots for a in A_tilde_depot[d])

    distances=[]
    service=[]
    carrying=[]
    capacities=[]

    A_used = [a for a in params.A if z[a]==1]
    A_carrying = [a for a in A_used if (length(params.Ia[a])>0 &&sum(x[i,a,p] for i in params.Ia[a] for p in params.P[i])>=1)]

    travel= sum(dist[a] for a in A_used)
    push!(distances,travel)

    serv_time=sum(arccost[a] for a in A_used)
    push!(service,serv_time)

    carrying_time=sum(arccost[a] for a in A_carrying)
    push!(carrying,carrying_time)

    capacity= mean(cap(q,a,params) for a in A_used)
    push!(capacities,capacity)
    
    avg_distance=round(mean(distances))
    avg_capacity=round(mean(capacities),digits=3)
    avg_service=round(mean(service))
    avg_carrying=round(mean(carrying))

    if print_all
        println("\n Vehicle KPIs:")
        println("# vehicles used: ",nb_veh)
        println("Mean distance: ", avg_distance)
        println("Mean capacity: ", avg_capacity)
        println("Mean service time: ", avg_service)
        println("Mean carrying time: ", avg_carrying)
    end

    return Dict("# Veh used" => nb_veh,
                    "Mean distance"=> avg_distance, 
                    "Mean capacity"=> avg_capacity, 
                    "Mean service time"=> avg_service, 
                    "Mean carrying time"=> avg_carrying)
end

#-----------------------------------------------------------------------------------#
function print_cust_bus_details(params,abbrev,depot_locs)
    q, t, I, _=abbrev;
    for i in I
        load= q[i]
        println("Cust $i, load $load - Pick-up vbs: ", params.vo[i], ", Drop-off vbs: ", params.vd[i], ", \t depart at: ", round(t[i],digits=1), ", arrival before: ", params.deadlines[i])
    end
    print("Bus depot locations: ", depot_locs)# " indexed by :", locs_id.depots)
end

#-------------  
function print_nb_arcs(tsnetwork,params,I)
    println("Initialized time space network with...")
    println("Num nodes (total) = ", tsnetwork.numnodes)
    println("Num arcs (total) = ", tsnetwork.numarcs);
    for i in I
        println("Num arcs for Cust $i = ", length(params.Ai[i]))
    end
end


function print_traveling_arcs(sol,ts,map1,vbs,tsnetwork,params,locs_id,locs_desc,print_all,save,res_file) # display from time ts
    if print_all
        println("Traveling arcs used:")
    end
    if save
        file=res_file*"_traveling_arcs.txt"
        open(file, "w") do io
            println(io, "Traveling arcs used:")
        end
    end
    colors= ["lime","magenta","mediumblue","mintcream","mistyrose","moccasin","navy","olive","chocolate4","coral","cornflowerblue","cornsilk4","cyan","darkblue","darkcyan","darkgoldenrod", "deeppink","deepskyblue","dodgerblue","firebrick","forestgreen","fuchsia","gainsboro","goldenrod","gray"]
    z,x=sol.z,sol.x
    P=params.P
    Ia=params.Ia
    arcs_dict=get_bus_routes(z,tsnetwork,params,locs_id)
    for i in 1:length(locs_id.depots)
        if print_all
            println("-- Bus $i: ")
        end
        if save
            open(file, "a") do io
                println(io, "-- Bus $i: ")
            end
        end
        for t in ts:horizon
            for a in arcs_dict[locs_id.depots[i]]
                a_val=tsnetwork.arcdesc[a]
                start_loc=tsnetwork.nodedesc[a_val[1]][1]
                end_loc=tsnetwork.nodedesc[a_val[2]][1]
                start_time=tsnetwork.nodedesc[a_val[1]][2]
                I_used = [i for i in Ia[a] if sum(x[i,a,p] for p in P[i])>0]
                if start_time==t #&& start_loc!=end_loc
                    viz_start_loc=locs_desc[start_loc]
                    viz_end_loc=locs_desc[end_loc]
                    if print_all
                        if length(I_used)>0
                            println("\t Time $t: $viz_start_loc --> $viz_end_loc, with cust $I_used")
                        else
                            println("\t Time $t: $viz_start_loc --> $viz_end_loc")
                        end
                    end
                    if save
                        open(file, "a") do io
                            if length(I_used)>0
                                println(io, "\t Time $t: $viz_start_loc --> $viz_end_loc, with cust $I_used")
                            else
                                println(io, "\t Time $t: $viz_start_loc --> $viz_end_loc")
                            end
                        end
                    end
                    if !(end_loc in locs_id.sink) # We don't show travel to sink
                    # plot line for physical arc between start_loc and end_loc on plot map1
                        plot!(map1, [vbs[start_loc,:x], vbs[end_loc,:x]],[vbs[start_loc,:y], vbs[end_loc,:y]], color=colors[i], label="") 
                    end
                end
            end
        end
    end
    if save
        savefig(map1,resultfile*"_map.png")
    end
    return map1
end

#-----------------------------------------------------------------------------------#
# to check the arc traveled by a specific cust after a specific time
function arc_traveled(cust,time,A,nodedesc,arcdesc,x,P,K,arccost)
    for a_ind in A
        a=arcdesc[a_ind]
        start_time=nodedesc[a[1]][2]
        if start_time>time && sum(x[cust,a_ind,p,k] for p in P[cust],k in K)==1
            start_loc=nodedesc[a[1]][1]
            end_loc=nodedesc[a[2]][1]
            println("travel from loc $start_loc to $end_loc at time $start_time with cost $(arccost[a_ind])")
        end
    end
end



# -----------------------------------------------------------------------------------#

using Luxor, Colors

function timespaceviz_arcs(drawingname,horizon, tstep, tsn, arclist, locs_id,locs_desc; x_size=1200, y_size=1000)

	#Find coordinates for each time-space node
	nodelist = []
    nb_locs=length(locs_id.all)
	x_size_trimmed, y_size_trimmed = x_size*0.9, y_size*0.9
	k1 = x_size_trimmed/(horizon/tstep + 2) 
	k2 = y_size_trimmed/(nb_locs + 2)
	for i in 1:tsn.numnodes
		ycoord = tsn.nodedesc[i][1]
		xcoord = (tsn.nodedesc[i][2]/tstep)+1

		#Scaling to image size
		tup = (-x_size_trimmed/2 + xcoord*k1, -y_size_trimmed/2 + ycoord*k2)   
		
		push!(nodelist,tup)
	end

	#Create actual points as a Luxor object
	nodePoints = Point.(nodelist)

	#---------------------------------------------------------------------------------------#

	#Arcs for visualization
	#Duplicate for multiple input arc lists with different colors/thickness/dash if you're trying to show m
	arcinfo = []
	for a in arclist
		startPoint = nodePoints[tsn.arcdesc[a][1]]
		endPoint = nodePoints[tsn.arcdesc[a][2]]
		
		#Set arc attributes
		arcColor = (0,0,255) #RGB tuple 
		arcDash = "solid" #"solid", "dashed"			
		arcThickness = 4 
		
		#Add to arcinfo list to be used in the drawing 
		push!(arcinfo, (startPoint, endPoint, arcColor, arcDash, arcThickness))
	end

	#-------------------------------------------------------------------------#

	#Initiailize drawing
	Drawing(x_size, y_size, drawingname)
	origin()
	background("white")

	#Draw arcs
	for i in arcinfo
		
		#Set arc attributes from the arcinfo
		r_val, g_val, b_val = i[3][1]/255, i[3][2]/255, i[3][3]/255
		setcolor(convert(Colors.HSV, Colors.RGB(r_val, g_val, b_val)))  #You can also use setcolor("colorname")
		setdash(i[4])
		setline(i[5])

		#Draw the line from the start node to end node
		line(i[1], i[2] , :stroke)
		
		#Figure out the angle of the arrow head
		theta = atan((i[2][2] - i[1][2])/(i[2][1] - i[1][1]))
		dist = distance(i[1], i[2])
		arrowhead = (1-8/dist)*i[2] + (8/dist)*i[1] #8 pixels from the end node
		
		#Draw the arrow head
		local p = ngon(arrowhead, 5, 3, theta, vertices=true)
		poly(p, :fill,  close=true)
	end

	#Draw node points
	setcolor("black")
	circle.(nodePoints, 4, :fill)

	#Set font size for labels
	fontsize(14)

	#Add location labels
	for l in locs_id.all
		coord = nodePoints[tsn.nodeid[(l,0.0)]]
		label(locs_desc[l], :W , coord)
	end

	#Add time labels
	for t in 0:tstep*2:horizon
		coord = nodePoints[tsn.nodeid[(1,t)]] + Point(0,-30)
		label("t = $t", :N , coord)
	end

	finish()
	preview()

end

function get_bus_routes(z,tsnetwork,params,locs_id)
    depots=locs_id.depots
    routes=Dict()
    for d in depots
        routes[d]=Vector()
        used=false
        end_node=0
        for n in params.N_depot[d]
            for a in tsnetwork.A_plus[n]
                if z[a]==1
                    push!(routes[d],a)
                    end_node=tsnetwork.arcdesc[a][2]
                    used=true
                end
            end
        end
        while used && !(tsnetwork.nodedesc[end_node][1] in locs_id.sink)
            for a in tsnetwork.A_plus[end_node]
                if z[a]==1
                    push!(routes[d],a)
                    end_node=tsnetwork.arcdesc[a][2]
                end
            end
        end
    end
    return routes 
end

function timespaceviz_bus(drawingname,horizon, tstep, tsn, params,z,locs_id; x_size=1200, y_size=700)

	#Find coordinates for each time-space node
	nodelist = []
    nb_locs=length(locs_id.all)
	x_size_trimmed, y_size_trimmed = x_size*0.9, y_size*0.9
	k1 = x_size_trimmed/(horizon/tstep + 2) 
	k2 = y_size_trimmed/(nb_locs + 2)
	for i in 1:tsn.numnodes
		ycoord = tsn.nodedesc[i][1]
		xcoord = (tsn.nodedesc[i][2]/tstep)+1

		#Scaling to image size
		tup = (-x_size_trimmed/2 + xcoord*k1, -y_size_trimmed/2 + ycoord*k2)   
		
		push!(nodelist,tup)
	end

	#Create actual points as a Luxor object
	nodePoints = Point.(nodelist)

	#---------------------------------------------------------------------------------------#
    colors= ["lime","magenta","mediumblue","mintcream","mistyrose","moccasin","navy","olive","chocolate4","coral","cornflowerblue","cornsilk4","cyan","darkblue","darkcyan","darkgoldenrod", "deeppink","deepskyblue","dodgerblue","firebrick","forestgreen","fuchsia","gainsboro","goldenrod","gray"]

	#Arcs for visualization
	#Duplicate for multiple input arc lists with different colors/thickness/dash if you're trying to show m
	arcs_dict=get_bus_routes(z,tsnetwork,params,locs_id)
    arcinfo = []
    for i in 1:length(locs_id.depots)
        arclist = arcs_dict[locs_id.depots[i]]
        for a in arclist
            startPoint = nodePoints[tsn.arcdesc[a][1]]
            endPoint = nodePoints[tsn.arcdesc[a][2]]
            
            #Set arc attributes
            arcColor = colors[i] #(0,0,255) #RGB tuple 
            arcDash = "solid" #"solid", "dashed"			
            arcThickness = 4 
            
            #Add to arcinfo list to be used in the drawing 
            push!(arcinfo, (startPoint, endPoint, arcColor, arcDash, arcThickness))
        end
    end

	#-------------------------------------------------------------------------#

	#Initiailize drawing
	Drawing(x_size, y_size, drawingname)
	origin()
	background("white")

	#Draw arcs
	for i in arcinfo
		#Set arc attributes from the arcinfo
		setcolor(i[3])
        setdash(i[4])
		setline(i[5])

		#Draw the line from the start node to end node
		line(i[1], i[2] , :stroke)
		
		#Figure out the angle of the arrow head
		theta = atan((i[2][2] - i[1][2])/(i[2][1] - i[1][1]))
		dist = distance(i[1], i[2])
		arrowhead = (1-8/dist)*i[2] + (8/dist)*i[1] #8 pixels from the end node
		
		#Draw the arrow head
		local p = ngon(arrowhead, 5, 3, theta, vertices=true)
		poly(p, :fill,  close=true)
	end

	#Draw node points
	setcolor("black")
	circle.(nodePoints, 4, :fill)

	#Set font size for labels
	fontsize(14)

	#Add location labels
	for l in locs_id.all
		coord = nodePoints[tsn.nodeid[(l,0.0)]]
		label(locs_desc[l], :W , coord)
	end

	#Add time labels
	for t in 0:tstep*2:horizon
		coord = nodePoints[tsn.nodeid[(1,t)]] + Point(0,-30)
		label("t = $t", :N , coord)
	end

    # show correspondance between color and bus ids
    #for i in K
    #    coord = Point(-x_size/2+50, -y_size/2+60+20*i)
    #    coord_c = Point(-x_size/2+70, -y_size/2+60+20*i)
      #  setcolor(colors[i])
     #   circle(coord_c, 10, :fill)
      #  label("Bus $i", :W , coord)
    #end

	finish()
	preview()

end


function write_result(resultfile,sol,tsnetwork,params,abbrev,wo,locs_id,print_all)
    q, t, I, K=abbrev;
    xi,x,z,time,objs=sol.xi,sol.x,sol.z,sol.time,sol.objs

    res_file=open(resultfile*"_res.txt","w")
    write(res_file, "\n ------ Objective values ------ \n")
    writedlm(res_file, objs)
    cust_KPIs_details,cust_KPIS,veh_KPIS=display_KPIs(xi,x,z,tsnetwork,params,I,q,wo,t,locs_id,print_all);
    write(res_file, "\n ------ Customer KPIs ------ \n")
    writedlm(res_file, cust_KPIS)
    write(res_file, "\n ------ Vehicle KPIs ------ \n")
    writedlm(res_file, veh_KPIS)
    write(res_file, "\n ------ Solving time ------ \n")
    writedlm(res_file, time)
    write(res_file, "\n ------ Customer KPIs details ------ ")
    for i in I
        write(res_file, "\n Customer "*string(i)*"\n")
        writedlm(res_file, cust_KPIs_details[i])
    end
    close(res_file)
end