
#Get a list of physical arcs that start from each location l, stored as P_plus[l] (helpful for shortest path)
function prearcPreproc(physicalarcs, locs_id)

	vbs_locs= locs_id.all_vbs
	P_plus = Dict()
	for l in vbs_locs
		P_plus[l] = []
	end

	for pa in physicalarcs, l in vbs_locs
		if pa[1] == l && pa[2]!=locs_id.sink # we don't consider arcs to sink node
			push!(P_plus[l], (pa[1], pa[2], pa[5])) #(loc1, loc2, rounded travel time)
		end
	end
	
	return P_plus
	
end

#---------------------------------------------------------------------------------------#

function findshortestpath(loc1, loc2, P_plus, locs_id)

	vbs_locs= locs_id.all_vbs
	nb_locs=length(vbs_locs)
	#Initialize shortest path algorithm (Dijkstra's)
	visitednodes = zeros(nb_locs)
	currdistance = repeat([999999.0],outer=[nb_locs])
	currdistance[loc1] = 0
	currloc, nopathexists_flag = loc1, 0

	#Find shortest path from loc1 to loc2
	while (visitednodes[loc2] == 0) & (nopathexists_flag == 0)

		#Assess all neighbors of current node
		for (l1, l2, tt) in P_plus[currloc]
			if (visitednodes[l2] == 0) & (currdistance[currloc] + tt < currdistance[l2] + 1e-4)
				currdistance[l2] = currdistance[currloc] + tt
			end
		end

		#Mark the current node as visited
		visitednodes[currloc] = 1

		#Find a list of unvisited nodes and their current distances 
		currdistance_unvisited = deepcopy(currdistance)
		for l in vbs_locs
			if visitednodes[l] == 1
				currdistance_unvisited[l] = 999999
			end
		end

		#Update the current node 
		currloc = argmin(currdistance_unvisited)

		#If all remaining nodes have tentative distance of 999999 and the algorithm has not terminated, then there is no path from origin to destination
		if minimum(currdistance_unvisited) == 999999
			nopathexists_flag = 1
		end

	end

	#Return shortest path distance or 999999 if no path exists
	return currdistance[loc2]

end

#---------------------------------------------------------------------------------------#

#Solve shortest path problems between all pairs of vbs locations (classic vbs and dupl hubs)
function cacheShortestTravelTimes(physicalarcs, locs_id)
	
	P_plus = prearcPreproc(physicalarcs, locs_id)

	shortestTravelTime = Dict()
	vbs_locs=locs_id.all_vbs
	for loc1 in vbs_locs, loc2 in vbs_locs
		if loc1 == loc2
			shortestTravelTime[loc1, loc2] = 0
		else
			#Find the shortest path from loc1 to loc2 with Djikstra's
			shortestTravelTime[loc1, loc2] = findshortestpath(loc1, loc2, P_plus, locs_id)
		end
	end

	return shortestTravelTime

end

