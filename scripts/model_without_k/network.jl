include("shortestpath.jl")
#Create the time-space nodes, returning the number, ids, and descriptions
function createtimespacenodes(locs, horizon, tstep)

	nodeid, nodedesc = Dict(), Dict()

	index = 1
	for t in 0:tstep:horizon
		for l in locs.id
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

#Read the list of arcs from the arc file
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
function createtimespacearcs(physicalarcs, nb_locs, numnodes, nodeid, horizon, tstep)

	arcid, arcdesc, A_plus, A_minus, arccost, dist = Dict(), Dict(), Dict(), Dict(), [],[]
	
	for node in 1:numnodes
		A_plus[node] = []
		A_minus[node] = []
	end

	stationaryarcs = []
	for l in 1:nb_locs
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
function createfullnetwork(locs, arcs, horizon, tstep)

	#Build network
	#loccoords = hcat(locs[:,2], locs[:,3])
	numnodes, nodeid, nodedesc, times = createtimespacenodes(locs, horizon, tstep)
	physicalarcs = getphysicalarcs(arcs, tstep)
	numarcs, arcid, arcdesc, A_plus, A_minus, arccost,dist = createtimespacearcs(physicalarcs, size(locs)[1], numnodes, nodeid, horizon, tstep)
	shortest_time=cacheShortestTravelTimes(physicalarcs,locs_id)

	#Create a NamedTuple with all the useful network data/parameters
	tsnetwork = (numnodes=numnodes, nodeid=nodeid, nodedesc=nodedesc, times=times, numarcs=numarcs, arcid=arcid, arcdesc=arcdesc, A_plus=A_plus, A_minus=A_minus, arccost=arccost,dist=dist, physicalarcs=physicalarcs, shortest_time=shortest_time)

	return tsnetwork

end