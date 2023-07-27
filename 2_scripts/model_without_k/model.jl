# - Model With Max profit objective
function network_model_profit(Q,abbrev,wo,tsnetwork,params,coefficients,output=1)
    # Create a model
    model = Model(Gurobi.Optimizer)
    set_optimizer_attribute(model, "OutputFlag", output)
    set_optimizer_attribute(model, "MIPGap", 0.1)
    alpha2,alpha1,alpha0,mu,beta,delta,lambda=coefficients

    q, t, I, K=abbrev
    A_plus, A_minus, arccost,nodedesc, arcdesc, T =tsnetwork.A_plus, tsnetwork.A_minus, tsnetwork.arccost,tsnetwork.nodedesc, tsnetwork.arcdesc, tsnetwork.times;
    P, P_desc,H, O, D, N_vo, N_vd, N_except_o_d_H, N_except_sink, P_T, H_times= params.P, params.P_desc, params.H, params.O, params.D, params.N_vo, params.N_vd, params.N_except_o_d_H, params.N_except_sink, params.P_T, params.H_times;
    A, Ai, Ai_plus, Ai_minus, Ai_minus_tilde, Ia, N, N_star, A_tilde_depot, Ai_except_H, Ai_except_H_desc=params.A, params.Ai, params.Ai_plus, params.Ai_minus, params.Ai_minus_tilde, params.Ia, params.N, params.N_star, params.A_tilde_depot, params.Ai_except_H, params.Ai_except_H_desc;
    c=arccost #  duration of the arc
    depots=keys(A_tilde_depot)

    # Create variables
    @variable(model, xi[i in I, p in P[i]], Bin) # 1 if customer i is assigned to path p 
    @variable(model, x[i in I, a in Ai[i], p in P[i]], Bin) #1 if customer i is assigned to arc a with path p 
    @variable(model, z[a in A], Bin) #1 if arc a is traveled by a vehicle (max 1 vehicle per arc)

    # PATH CONSTRAINTS
    # 1 Path
    @constraint(model, [i in I], sum(xi[i,p] for p in P[i]) <= 1) #each customer is assigned to max one path
    # Pick-up
    @constraint(model, [i in I, p in P[i]], sum(x[i,a,p] for n in O[i][p], a in Ai_plus[i][n]) == xi[i,p]) #each customer is assigned to max one arc leaving a pick-up node from the selected path
    # Drop-off
    @constraint(model, [i in I, p in P[i]], sum(x[i,a,p] for n in D[i][p], a in Ai_minus[i][n]) == xi[i,p]) #each customer is assigned to exactly one arc incoming a drop-off node from the selected path if he is served
    # Transfer
    @constraint(model, [i in I, p in P_T[i]], sum(x[i,a,p] for p in P_T[i], n in H[i][p], a in Ai_minus_tilde[i][n]) == xi[i,p]) #each customer is assigned to max one arc incoming a transfer node if the selected path is indirect

    # CUST FLOW BALANCE CONSTRAINT
    @constraint(model, [i in I, p in P[i], n in N_except_o_d_H[i][p]], sum(x[i,a,p] for a in Ai_minus[i][n]) == sum(x[i,a,p] for a in Ai_plus[i][n]))
    # Transfer between two hubs parking Simulations
    @constraint(model, [i in I, p in P[i], time in T], sum(x[i,a,p] for n in H_times[i][p][time], a in Ai_minus[i][n]) == sum(x[i,a,p] for n in H_times[i][p][time], a in Ai_plus[i][n]))
    
    # ROUTE CONSTRAINT
    @constraint(model, [i in I], sum(x[i,a,p] for p in P[i], n in N_vo[i], a in Ai_minus[i][n]) == 0) # customer cannot be assigned to an arc incoming one of his pick-up nodes
    @constraint(model, [i in I], sum(x[i,a,p] for p in P[i], n in N_vd[i], a in Ai_plus[i][n]) == 0) # customer cannot be assigned to an arc leaving one of his drop-off nodes
    
    # CAPACITY CONSTRAINT
    @constraint(model, [a in A], sum(q[i]*x[i,a,p] for i in Ia[a], p in P[i]) <= Q*z[a])

    # LINKING CONSTRAINTS
    @constraint(model, [i in I, p in P[i], a in Ai[i]], x[i,a,p] <= xi[i,p])
    @constraint(model, [i in I, p in P[i], a in Ai_except_H[i][p]], x[i,Ai_except_H_desc[i][p][a],p] <= z[Ai_except_H_desc[i][p][a]])

    # DEPOT CONSTRAINTS
    @constraint(model, [d in depots], sum(z[a] for a in A_tilde_depot[d]) <= 1)

    # MAX 1 VEHICLE INCOMING
    @constraint(model, [n in N_except_sink], sum(z[a] for a in A_minus[n]) <= 1)
    # VEHICLE FLOW CONSTRAINT
    @constraint(model, [n in N_star], sum(z[a] for a in A_plus[n]) == sum(z[a] for a in A_minus[n]))

    ## Objective function
    @expression(model, Walk, sum(P_desc[i][p]["walking"]*xi[i,p] for i in I, p in P[i]))
    @expression(model, Wait, sum((nodedesc[arcdesc[a][1]][2]-t[i]-wo[i,nodedesc[n][1]])*x[i,a,p] for i in I, p in P[i], n in O[i][p], a in Ai_plus[i][n]))
    @expression(model, Traveling, sum(c[a]*x[i,a,p] for i in I, p in P[i], a in Ai[i]))
    @expression(model, Tr, sum(P_desc[i][p]["transfer"]*xi[i,p] for i in I, p in P[i]))
    @expression(model, Veh, sum(c[a]*z[a] for a in A))
    @expression(model, Veh_nb, sum(z[a] for d in depots, a in A_tilde_depot[d]))
    @expression(model, Served, sum(xi[i,p] for i in I, p in P[i])) # = 0 if we serve no cust

    # Set objective
    @objective(model, Max, alpha2*Served - alpha1*Veh - alpha0*Veh_nb - mu*Walk - beta*Wait - delta*Traveling - lambda*Tr)
    solvetime = @elapsed optimize!(model)

    # alpha2 = course price 
    # alpha1 = variable service cost (price per min) 
    # alpha0 = fixed service cost (price per vehicle used)
    # mu = Cost of 1min cust walking 
    # beta = Cost of 1min cust waiting 
    # delta = Cost of 1mn cust traveling in bus 
    # lambda = Cost of cust transfers
    
    # Print the solution
    println("Objective value: ", objective_value(model))
    objs=Dict("Walk" => round(value.(Walk),digits=2),
        "Wait" => round(value.(Wait),digits=2),
        "Cust driving" => round(value.(Traveling),digits=2),
        "Tr" => round(value.(Tr),digits=2),
        "Veh driving" => round(value.(Veh),digits=2),
        "Veh_nb" => round(value.(Veh_nb),digits=2),
        "Served" => round(sum(value.(xi)),digits=2))
        
    solution = (xi=value.(xi),x=value.(x),z=value.(z), obj=objective_value(model),time=solvetime,objs=objs)

    return solution
    
end


# ---------------






# ---------------








# ----------------


# - Model without the index k
function network_model(Q,abbrev,wo,tsnetwork,params,coefficients,output=1)
    # Create a model
    model = Model(Gurobi.Optimizer)
    set_optimizer_attribute(model, "OutputFlag", output)
    set_optimizer_attribute(model, "MIPGap", 0.1)
    mu,beta,lambda,alpha1,nu,alpha2=coefficients

    q, t, I, K=abbrev
    A_plus, A_minus, arccost,nodedesc, arcdesc, T =tsnetwork.A_plus, tsnetwork.A_minus, tsnetwork.arccost,tsnetwork.nodedesc, tsnetwork.arcdesc, tsnetwork.times;
    P, P_desc,H, O, D, N_vo, N_vd, N_except_o_d_H, N_except_sink, P_T, H_times= params.P, params.P_desc, params.H, params.O, params.D, params.N_vo, params.N_vd, params.N_except_o_d_H, params.N_except_sink, params.P_T, params.H_times;
    A, Ai, Ai_plus, Ai_minus, Ai_minus_tilde, Ia, N, N_star, A_tilde_depot, Ai_except_H, Ai_except_H_desc=params.A, params.Ai, params.Ai_plus, params.Ai_minus, params.Ai_minus_tilde, params.Ia, params.N, params.N_star, params.A_tilde_depot, params.Ai_except_H, params.Ai_except_H_desc;
    c=arccost #  duration of the arc
    depots=keys(A_tilde_depot)

    # Create variables
    @variable(model, xi[i in I, p in P[i]], Bin) # 1 if customer i is assigned to path p 
    @variable(model, x[i in I, a in Ai[i], p in P[i]], Bin) #1 if customer i is assigned to arc a with path p 
    @variable(model, z[a in A], Bin) #1 if arc a is traveled by a vehicle (max 1 vehicle per arc)

    # PATH CONSTRAINTS
    # 1 Path
    @constraint(model, [i in I], sum(xi[i,p] for p in P[i]) <= 1) #each customer is assigned to max one path
    # Pick-up
    @constraint(model, [i in I, p in P[i]], sum(x[i,a,p] for n in O[i][p], a in Ai_plus[i][n]) == xi[i,p]) #each customer is assigned to max one arc leaving a pick-up node from the selected path
    # Drop-off
    @constraint(model, [i in I, p in P[i]], sum(x[i,a,p] for n in D[i][p], a in Ai_minus[i][n]) == xi[i,p]) #each customer is assigned to exactly one arc incoming a drop-off node from the selected path if he is served
    # Transfer
    @constraint(model, [i in I, p in P_T[i]], sum(x[i,a,p] for p in P_T[i], n in H[i][p], a in Ai_minus_tilde[i][n]) == xi[i,p]) #each customer is assigned to max one arc incoming a transfer node if the selected path is indirect

    # CUST FLOW BALANCE CONSTRAINT
    @constraint(model, [i in I, p in P[i], n in N_except_o_d_H[i][p]], sum(x[i,a,p] for a in Ai_minus[i][n]) == sum(x[i,a,p] for a in Ai_plus[i][n]))
    # Transfer between two hubs parking Simulations
    @constraint(model, [i in I, p in P[i], time in T], sum(x[i,a,p] for n in H_times[i][p][time], a in Ai_minus[i][n]) == sum(x[i,a,p] for n in H_times[i][p][time], a in Ai_plus[i][n]))
    
    # ROUTE CONSTRAINT
    @constraint(model, [i in I], sum(x[i,a,p] for p in P[i], n in N_vo[i], a in Ai_minus[i][n]) == 0) # customer cannot be assigned to an arc incoming one of his pick-up nodes
    @constraint(model, [i in I], sum(x[i,a,p] for p in P[i], n in N_vd[i], a in Ai_plus[i][n]) == 0) # customer cannot be assigned to an arc leaving one of his drop-off nodes
    
    # CAPACITY CONSTRAINT
    @constraint(model, [a in A], sum(q[i]*x[i,a,p] for i in Ia[a], p in P[i]) <= Q*z[a])

    # LINKING CONSTRAINTS
    @constraint(model, [i in I, p in P[i], a in Ai[i]], x[i,a,p] <= xi[i,p])
    @constraint(model, [i in I, p in P[i], a in Ai_except_H[i][p]], x[i,Ai_except_H_desc[i][p][a],p] <= z[Ai_except_H_desc[i][p][a]])

    # DEPOT CONSTRAINTS
    @constraint(model, [d in depots], sum(z[a] for a in A_tilde_depot[d]) <= 1)

    # MAX 1 VEHICLE INCOMING
    @constraint(model, [n in N_except_sink], sum(z[a] for a in A_minus[n]) <= 1)
    # VEHICLE FLOW CONSTRAINT
    @constraint(model, [n in N_star], sum(z[a] for a in A_plus[n]) == sum(z[a] for a in A_minus[n]))

    ## Objective function
    @expression(model, Walk, sum(P_desc[i][p]["walking"]*xi[i,p] for i in I, p in P[i]))
    @expression(model, Wait, sum((nodedesc[arcdesc[a][1]][2]-t[i]-wo[i,nodedesc[n][1]])*x[i,a,p] for i in I, p in P[i], n in O[i][p], a in Ai_plus[i][n]))
    @expression(model, Traveling, sum(c[a]*x[i,a,p] for i in I, p in P[i], a in Ai[i]))
    @expression(model, Tr, sum(P_desc[i][p]["transfer"]*xi[i,p] for i in I, p in P[i]))
    @expression(model, Veh, sum(c[a]*z[a] for a in A))
    @expression(model, Veh_nb, sum(z[a] for d in depots, a in A_tilde_depot[d]))
    @expression(model, Unmet, -sum(xi[i,p] for i in I, p in P[i])) # = 0 if we serve all cust

    # Set objective
    @objective(model, Min, mu*Walk + beta*Wait + Traveling + lambda*Tr+ alpha1*(Veh+nu*Veh_nb) + alpha2*Unmet)
    solvetime = @elapsed optimize!(model)
    
    # Print the solution
    println("Objective value: ", objective_value(model))
    objs=Dict("Walk" => round(value.(Walk),digits=2),
        "Wait" => round(value.(Wait),digits=2),
        "Cust driving" => round(value.(Traveling),digits=2),
        "Tr" => round(value.(Tr),digits=2),
        "Veh driving" => round(value.(Veh),digits=2),
        "Veh_nb" => round(value.(Veh_nb),digits=2),
        "Unmet" => round(sum(1-sum(value.(xi)[i,p] for p in P[i]) for i in I),digits=2))
        
    solution = (xi=value.(xi),x=value.(x),z=value.(z), obj=objective_value(model),time=solvetime,objs=objs)

    return solution
    
end

###------------ Model with z fixed
function network_model_zfixed(Q,abbrev,wo,tsnetwork,params,coefficients,z,output=1)
    # Create a model
    model = Model(Gurobi.Optimizer)
    set_optimizer_attribute(model, "OutputFlag", output)
    #set_optimizer_attribute(model, "MIPGap", 0.1)
    mu,beta,lambda,alpha1,nu,alpha2=coefficients

    q, t, I, K=abbrev
    A_plus, A_minus, arccost,nodedesc, arcdesc, T =tsnetwork.A_plus, tsnetwork.A_minus, tsnetwork.arccost,tsnetwork.nodedesc, tsnetwork.arcdesc, tsnetwork.times;
    P, P_desc,H, O, D, N_vo, N_vd, N_except_o_d_H, N_except_sink, P_T, H_times= params.P, params.P_desc, params.H, params.O, params.D, params.N_vo, params.N_vd, params.N_except_o_d_H, params.N_except_sink, params.P_T, params.H_times;
    A, Ai, Ai_plus, Ai_minus, Ai_minus_tilde, Ia, N, N_star, A_tilde_depot, Ai_except_H, Ai_except_H_desc=params.A, params.Ai, params.Ai_plus, params.Ai_minus, params.Ai_minus_tilde, params.Ia, params.N, params.N_star, params.A_tilde_depot, params.Ai_except_H, params.Ai_except_H_desc;
    c=arccost #  duration of the arc
    depots=keys(A_tilde_depot)

    # Create variables
    @variable(model, xi[i in I, p in P[i]], Bin) # 1 if customer i is assigned to path p 
    @variable(model, x[i in I, a in Ai[i], p in P[i]], Bin) #1 if customer i is assigned to arc a with path p 

    # PATH CONSTRAINTS
    # 1 Path
    @constraint(model, [i in I], sum(xi[i,p] for p in P[i]) <= 1) #each customer is assigned to maximum one path
    # Pick-up
    @constraint(model, [i in I], sum(x[i,a,p] for p in P[i], n in O[i][p], a in Ai_plus[i][n]) <= 1) #each customer is assigned to maximum one arc leaving a pick-up node from the selected path
    # Drop-off
    @constraint(model, [i in I], sum(x[i,a,p] for p in P[i], n in D[i][p], a in Ai_minus[i][n]) == sum(x[i,a,p] for p in P[i], n in O[i][p], a in Ai_plus[i][n])) #each customer is assigned to exactly one arc incoming a drop-off node from the selected path if he is served
    # Transfer
    @constraint(model, [i in I], sum(x[i,a,p] for p in P_T[i], n in H[i][p], a in Ai_minus_tilde[i][n]) == sum(xi[i,p] for p in P_T[i])) #each customer is assigned to max one arc incoming a transfer node if the selected path is indirect

    # CUST FLOW BALANCE CONSTRAINT
    @constraint(model, [i in I, p in P[i], n in N_except_o_d_H[i][p]], sum(x[i,a,p] for a in Ai_minus[i][n]) == sum(x[i,a,p] for a in Ai_plus[i][n]))
    # Transfer between two hubs parking Simulations
    @constraint(model, [i in I, p in P[i], time in T], sum(x[i,a,p] for n in H_times[i][p][time], a in Ai_minus[i][n]) == sum(x[i,a,p] for n in H_times[i][p][time], a in Ai_plus[i][n]))
    
    # ROUTE CONSTRAINT
    @constraint(model, [i in I], sum(x[i,a,p] for p in P[i], n in N_vo[i], a in Ai_minus[i][n]) == 0) # customer cannot be assigned to an arc incoming one of his pick-up nodes
    @constraint(model, [i in I], sum(x[i,a,p] for p in P[i], n in N_vd[i], a in Ai_plus[i][n]) == 0) # customer cannot be assigned to an arc leaving one of his drop-off nodes
    
    # CAPACITY CONSTRAINT
    @constraint(model, [a in A], sum(q[i]*x[i,a,p] for i in Ia[a], p in P[i]) <= Q*z[a])

    # LINKING CONSTRAINTS
    @constraint(model, [i in I, p in P[i], a in Ai[i]], x[i,a,p] <= xi[i,p])
    @constraint(model, [i in I, p in P[i], a in Ai_except_H[i][p]], x[i,Ai_except_H_desc[i][p][a],p] <= z[Ai_except_H_desc[i][p][a]])

    # DEPOT CONSTRAINTS
    @constraint(model, [d in depots], sum(z[a] for a in A_tilde_depot[d]) <= 1)

    # MAX 1 VEHICLE
    @constraint(model, [n in N_except_sink], sum(z[a] for a in A_minus[n]) <= 1)
    # VEHICLE FLOW CONSTRAINT
    @constraint(model, [n in N_star], sum(z[a] for a in A_plus[n]) == sum(z[a] for a in A_minus[n]))

    ## Objective function
    @expression(model, Walk, sum(P_desc[i][p]["walking"]*xi[i,p] for i in I, p in P[i]))
    @expression(model, Wait, sum((nodedesc[arcdesc[a][1]][2]-t[i]-wo[i,nodedesc[n][1]])*x[i,a,p] for i in I, p in P[i], n in O[i][p], a in Ai_plus[i][n]))
    @expression(model, Traveling, sum(c[a]*x[i,a,p] for i in I, p in P[i], a in Ai[i]))
    @expression(model, Tr, sum(P_desc[i][p]["transfer"]*xi[i,p] for i in I, p in P[i]))
    @expression(model, Veh, sum(c[a]*z[a] for a in A))
    @expression(model, Veh_nb, sum(z[a] for d in depots, a in A_tilde_depot[d]))
    @expression(model, Unmet, sum((1-sum(xi[i,p] for p in P[i]) for i in I)))

    # Set objective
    @objective(model, Min, mu*Walk + beta*Wait + Traveling + lambda*Tr+
                            alpha1*(Veh+nu*Veh_nb) + 
                            alpha2*Unmet)
    solvetime = @elapsed optimize!(model)
    
    # Print the solution
    println("Objective value: ", objective_value(model))
    objs=Dict("Walk" => round(value.(Walk),digits=2),
        "Wait" => round(value.(Wait),digits=2),
        "Cust driving" => round(value.(Traveling),digits=2),
        "Tr" => round(value.(Tr),digits=2),
        "Veh driving" => round(value.(Veh),digits=2),
        "Veh_nb" => round(value.(Veh_nb),digits=2),
        "Unmet" => round(value.(Unmet),digits=2))
        
    solution = (xi=value.(xi),x=value.(x),z, obj=objective_value(model),time=solvetime,objs=objs)

    return solution
    
end
