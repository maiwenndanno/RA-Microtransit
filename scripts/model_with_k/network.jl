#Create the time-space nodes, returning the number, ids, and descriptions
function createtimespacenodes(nb_locs, horizon, tstep)

	nodeid, nodedesc = Dict(), Dict()

	index = 1
	for t in 0:tstep:horizon
		for l in 1:nb_locs+1 # Add sink node
			nodeid[(l,t)] = index
			nodedesc[index] = (l,t)
			index += 1
		end	
	end
	
	numnodes = length(nodeid)
	times = [t for t in 0:tstep:horizon]

	return numnodes, nodeid, nodedesc, times

end

#-----------------------------------------------------------------------------------#

#Read the list of arcs from the arc file (including arcs to sink)
function getphysicalarcs(arcs, tstep)
	
	physicalarcs = []

	for a in 1:size(arcs)[1]
		l1, l2 = arcs[a,1], arcs[a,2]
		arcdistance = arcs[a,4]
		arclength_raw = arcs[a,3]
		arclength_discretized = tstep * ceil(arclength_raw / tstep)
		push!(physicalarcs, (l1, l2, arcdistance, arclength_raw, arclength_discretized))
	end

	return physicalarcs

end

#-----------------------------------------------------------------------------------#

#Create the time-space network arcs, returning the number, ids, descriptions, and cost of each arc
function createtimespacearcs(physicalarcs, nb_locs, numnodes, nodeid)

	arcid, arcdesc, A_plus, A_minus, arccost, dist = Dict(), Dict(), Dict(), Dict(), [],[]
	
	for node in 1:numnodes
		A_plus[node] = []
		A_minus[node] = []
	end

	stationaryarcs = []
	for l in 1:nb_locs+1 # Add sink node
		push!(stationaryarcs, (l, l, 0, tstep, tstep))
	end

	index = 1
	for arc in union(physicalarcs, stationaryarcs)
	
		for t in 0:tstep:horizon-arc[5]
			startnode = nodeid[(arc[1],t)]
			endnode = nodeid[(arc[2],t+arc[5])]
			arcid[(startnode,endnode)] = index
			arcdesc[index] = (startnode,endnode)
			
			push!(A_plus[startnode], index)
			push!(A_minus[endnode], index)

			push!(arccost, arc[4])
			push!(dist, arc[3])

			index += 1
		end
	end

	numarcs = length(arcid)

	return numarcs, arcid, arcdesc, A_plus, A_minus, arccost,dist

end

#-----------------------------------------------------------------------------------#

#Build the full time-space network
function createfullnetwork(locations, arcs, nb_locs, horizon, tstep)

	#Build network
	loccoords = hcat(locations[:,2], locations[:,3])
	numnodes, nodeid, nodedesc, times = createtimespacenodes(nb_locs, horizon, tstep)
	physicalarcs = getphysicalarcs(arcs, tstep)
	numarcs, arcid, arcdesc, A_plus, A_minus, arccost,dist = createtimespacearcs(physicalarcs, nb_locs, numnodes, nodeid)

	#Create a NamedTuple with all the useful network data/parameters
	tsnetwork = (loccoords=loccoords, numnodes=numnodes, nodeid=nodeid, nodedesc=nodedesc, times=times, numarcs=numarcs, arcid=arcid, arcdesc=arcdesc, A_plus=A_plus, A_minus=A_minus, arccost=arccost,dist=dist)

	return tsnetwork,physicalarcs

end