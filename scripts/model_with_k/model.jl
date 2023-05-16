# ---------- 2nd model - Version of April 29 (with arc reduction heuristic for Ai[i] and Ia[a])
function network_model(Q,abbrev,wo,tsnetwork,params,coefficients,output=1)
    # Create a model
    model = Model(Gurobi.Optimizer)
    set_optimizer_attribute(model, "OutputFlag", output)
    #set_optimizer_attribute(model, "MIPGap", 0.1)
    mu,beta,lambda,alpha1,nu,alpha2=coefficients

    q, t, I, K=abbrev
    A_plus, A_minus, arccost,nodedesc, arcdesc =tsnetwork.A_plus, tsnetwork.A_minus, tsnetwork.arccost,tsnetwork.nodedesc, tsnetwork.arcdesc;
    P, H, O, D, N_vo, N_vd, N_except_vo_vd_H, P_T= params.P, params.H, params.O, params.D, params.N_vo, params.N_vd, params.N_except_vo_vd_H, params.P_T;
    A, Ai, Ai_plus, Ai_minus, Ia, N, N_star, A_tilde_depot=params.A, params.Ai, params.Ai_plus, params.Ai_minus, params.Ia, params.N, params.N_star, params.A_tilde_depot;
    c=arccost #  duration of the arc

    # Create variables
    @variable(model, xi[i in I, p in P[i]], Bin) # 1 if customer i is assigned to path p 
    @variable(model, x[i in I, a in Ai[i], p in P[i], k in K], Bin) #1 if customer i is assigned to arc a with path p 
    @variable(model, z[k in K, a in A], Bin) #1 if arc a is traveled by vehicle k

    # Path constraints
    @constraint(model, [i in I], sum(xi[i,p] for p in P[i]) == 1) #each customer is assigned to exactly one path
    @constraint(model, [i in I], sum(x[i,a,p,k] for p in P[i], n in O[i][p], a in Ai_plus[i][n], k in K) == 1) #each customer is assigned to exactly one arc leaving a pick-up node from the selected path
    @constraint(model, [i in I], sum(x[i,a,p,k] for p in P[i], n in D[i][p], a in Ai_minus[i][n], k in K) == 1) #each customer is assigned to exactly one arc incoming a drop-off node from the selected path
    @constraint(model, [i in I], sum(x[i,a,p,k] for p in P_T[i], n in H[i][p], a in Ai_minus[i][n], k in K) == sum(xi[i,p] for p in P_T[i])) #each customer is assigned to max one arc incoming a transfer node if the selected path is indirect

    # linking constraint x - xi
    @constraint(model, [i in I, p in P[i], a in Ai[i], k in K], x[i,a,p,k] <= xi[i,p])

    # Arc reduction
    #@constraint(model, [i in I, p in P[i], a in notAi[i], k in K], x[i,a,p,k] == 0) # customer can only assigned to arcs of Ai
    
    # Customer flow balance
    @constraint(model, [i in I, p in P[i], n in N_except_vo_vd_H[i][p],k in K], sum(x[i,a,p,k] for a in Ai_minus[i][n]) == sum(x[i,a,p,k] for a in Ai_plus[i][n]))
    @constraint(model, [i in I, p in P[i], n in H[i][p]], sum(x[i,a,p,k] for a in Ai_minus[i][n], k in K) == sum(x[i,a,p,k] for a in Ai_plus[i][n], k in K))
    @constraint(model, [i in I], sum(x[i,a,p,k] for p in P[i], n in N_vo[i], a in Ai_minus[i][n], k in K) == 0) # customer cannot be assigned to an arc incoming one of his pick-up nodes
    @constraint(model, [i in I], sum(x[i,a,p,k] for p in P[i], n in N_vd[i], a in Ai_plus[i][n], k in K) == 0) # customer cannot be assigned to an arc leaving one of his drop-off nodes
    
    # Vehicle flow balance
    @constraint(model, [k in K, n in N_star[k]], sum(z[k,a] for a in A_minus[n]) == sum(z[k,a] for a in A_plus[n]))

    # Vehicle capacity
    @constraint(model, [k in K, a in A], sum(q[i]*x[i,a,p,k] for i in Ia[a], p in P[i]) <= Q*z[k,a])

    # Vehicle network assumptions
    @constraint(model, [k in K, n in N], sum(z[k,a] for a in A_plus[n]) <= 1) #Each vehicle can travel along at most one outgoing arc
    @constraint(model, [k in K], sum(z[k,a] for a in A_tilde_depot[k]) <= 1) #Each vehicle can leave the depot max once
    
    # Linking constraint x - z
    @constraint(model, [i in I, a in Ai[i], p in P[i], k in K], x[i,a,p,k] <= z[k,a])

    ## Objective function
    @expression(model, Walk, sum(p["walking"]*xi[i,p] for i in I, p in P[i]))
    @expression(model, Wait, sum((nodedesc[arcdesc[a][1]][2]-t[i]-wo[i,nodedesc[n][1]])*x[i,a,p,k] for i in I, p in P[i], n in O[i][p], a in Ai_plus[i][n], k in K))
    @expression(model, Traveling, sum(c[a]*x[i,a,p,k] for i in I, p in P[i], a in Ai[i], k in K))
    @expression(model, Tr, sum(p["transfer"]*xi[i,p] for i in I, p in P[i]))
    @expression(model, Veh, sum(c[a]*z[k,a] for a in A, k in K))
    @expression(model, Veh_nb, sum(z[k,a] for k in K, a in A_tilde_depot[k]))
    @expression(model, Unmet, sum((1-sum(xi[i,p] for p in P[i]) for i in I)))

    # Set objective
    @objective(model, Min, mu*Walk + beta*Wait + Traveling + lambda*Tr+
                            alpha1*(Veh+nu*Veh_nb) + 
                            alpha2*Unmet)

    # Solve the model
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
    
    solution = (xi=value.(xi),x=value.(x),z=value.(z), obj=objective_value(model),time=solvetime,objs=objs)

    return solution
end

# ---------- 1st model - Version of April 18
function network_model_OLD(I,K,Q,q,t,wo,tsnetwork,params,coefficients)
    # Create a model
    model = Model(Gurobi.Optimizer)
    set_optimizer_attribute(model, "OutputFlag", 0)
    mu,beta,lambda,alpha1,nu,alpha2=coefficients

    A_plus, A_minus, arccost,nodedesc, arcdesc =tsnetwork.A_plus, tsnetwork.A_minus, tsnetwork.arccost,tsnetwork.nodedesc, tsnetwork.arcdesc;
    P, H, O, D, N_vo, N_vd, N_except_vo_vd_H, P_T, A, N, N_star, A_tilde_depot= params.P, params.H, params.O, params.D, params.N_vo, params.N_vd, params.N_except_vo_vd_H, params.P_T, params.A, params.N, params.N_star, params.A_tilde_depot;
    c=arccost #  duration of the arc

    # Create variables
    @variable(model, xi[i in I, p in P[i]], Bin) # 1 if customer i is assigned to path p 
    @variable(model, x[i in I, a in A, p in P[i], k in K], Bin) #1 if customer i is assigned to arc a with path p 
    @variable(model, z[k in K, a in A], Bin) #1 if arc a is traveled by vehicle k

    # TO CHECK ONLY PASSENGERS MOVES
    #@constraint(model, [k in K, a in A], z[k,a]==0)

    # Path constraints
    @constraint(model, [i in I], sum(xi[i,p] for p in P[i]) == 1) #each customer is assigned to exactly one path
    @constraint(model, [i in I], sum(x[i,a,p,k] for p in P[i], n in O[i][p], a in A_plus[n], k in K) == 1) #each customer is assigned to exactly one arc leaving a pick-up node from the selected path
    @constraint(model, [i in I], sum(x[i,a,p,k] for p in P[i], n in D[i][p], a in A_minus[n], k in K) == 1) #each customer is assigned to exactly one arc incoming a drop-off node from the selected path
    @constraint(model, [i in I], sum(x[i,a,p,k] for p in P_T[i], n in H[i][p], a in A_minus[n], k in K) == sum(xi[i,p] for p in P_T[i])) #each customer is assigned to max one arc incoming a transfer node if the selected path is indirect

    # linking constraint x - xi
    @constraint(model, [i in I, p in P[i], a in A, k in K], x[i,a,p,k] <= xi[i,p])

    # Customer flow balance
    @constraint(model, [i in I, p in P[i], n in N_except_vo_vd_H[i][p],k in K], sum(x[i,a,p,k] for a in A_minus[n]) == sum(x[i,a,p,k] for a in A_plus[n]))
    @constraint(model, [i in I, p in P[i], n in H[i][p]], sum(x[i,a,p,k] for a in A_minus[n], k in K) == sum(x[i,a,p,k] for a in A_plus[n], k in K))
    @constraint(model, [i in I], sum(x[i,a,p,k] for p in P[i], n in N_vo[i], a in A_minus[n], k in K) == 0) # customer cannot be assigned to an arc incoming one of his pick-up nodes
    @constraint(model, [i in I], sum(x[i,a,p,k] for p in P[i], n in N_vd[i], a in A_plus[n], k in K) == 0) # customer cannot be assigned to an arc leaving one of his drop-off nodes
    
    # Vehicle flow balance
    @constraint(model, [k in K, n in N_star[k]], sum(z[k,a] for a in A_minus[n]) == sum(z[k,a] for a in A_plus[n]))

    # Vehicle capacity
    @constraint(model, [k in K, a in A], sum(q[i]*x[i,a,p,k] for i in I, p in P[i]) <= Q*z[k,a])

    # Vehicle network assumptions
    @constraint(model, [k in K, n in N], sum(z[k,a] for a in A_plus[n]) <= 1) #Each vehicle can travel along at most one outgoing arc
    @constraint(model, [k in K], sum(z[k,a] for a in A_tilde_depot[k]) <= 1) #Each vehicle can leave the depot max once
    
    # Linking constraint x - z
    @constraint(model, [i in I, p in P[i], k in K, a in A], x[i,a,p,k] <= z[k,a])

    ## Objective function
    @expression(model, Walk, sum(p["walking"]*xi[i,p] for i in I, p in P[i]))
    @expression(model, Wait, sum((nodedesc[arcdesc[a][1]][2]-t[i]-wo[i,nodedesc[n][1]])*x[i,a,p,k] for i in I, p in P[i], n in O[i][p], a in A_plus[n], k in K))
    @expression(model, Traveling, sum(c[a]*x[i,a,p,k] for i in I, p in P[i], a in A, k in K))
    @expression(model, Tr, sum(p["transfer"]*xi[i,p] for i in I, p in P[i]))
    @expression(model, Veh, sum(sum(c[a]*z[k,a] for a in A) + nu*sum(z[k,a] for a in A_tilde_depot[k]) for k in K))
    @expression(model, Unmet, sum((1-sum(xi[i,p] for p in P[i]) for i in I)))

    # Set objective
    @objective(model, Min, mu*Walk + beta*Wait + Traveling + lambda*Tr+
                            alpha1*Veh + 
                            alpha2*Unmet)

    # Solve the model
    solvetime = @elapsed optimize!(model)
    
    # Print the solution
    println("Objective value: ", objective_value(model))
    objs=Dict("Walk" => round(value.(Walk),digits=2),
        "Wait" => round(value.(Wait),digits=2),
        "Traveling" => round(value.(Traveling),digits=2),
        "Tr" => round(value.(Tr),digits=2),
        "Veh" => round(value.(Veh),digits=2),
        "Unmet" => round(value.(Unmet),digits=2))
    return value.(xi),value.(x),value.(z), objective_value(model),solvetime,objs
end