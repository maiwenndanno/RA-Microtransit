""" Normal Benders """
function solve_benders_profit(Q,abbrev,data,tsnetwork,params,coefficients,
    verbose::Bool = true,
    time_limit::Int = 180,
    optimality_gap::Float64 = 1e-3)

    """Solve problem using multi-cut Benders decomposition, giving the optimal z"""

    # Model parameters
    alpha2,alpha1,alpha0,mu,beta,delta,lambda=coefficients

    #Data
    q, t, I, K=abbrev
    A_plus, A_minus, arccost,nodedesc, arcdesc, T =tsnetwork.A_plus, tsnetwork.A_minus, tsnetwork.arccost,tsnetwork.nodedesc, tsnetwork.arcdesc, tsnetwork.times;
    P, P_desc, H, O, D, N_vo, N_vd, N_except_o_d_H, N_except_sink, P_T, H_times= params.P, params.P_desc, params.H, params.O, params.D, params.N_vo, params.N_vd, params.N_except_o_d_H, params.N_except_sink, params.P_T, params.H_times;
    A, Ai, Ai_plus, Ai_minus, Ai_minus_tilde, Ia, N, N_star, A_tilde_depot, Ai_except_H, Ai_except_H_desc=params.A, params.Ai, params.Ai_plus, params.Ai_minus, params.Ai_minus_tilde, params.Ia, params.N, params.N_star, params.A_tilde_depot, params.Ai_except_H, params.Ai_except_H_desc;
    c=arccost #  duration of the arc
    depots=keys(A_tilde_depot)

    """ Get z0 in int(conv(F)) for Pareto cuts """
    println("Looking for a core point z0...")
    z0=get_feasible_z(params,tsnetwork,data)
    println("Core point found !")

    """ Define Master Problem (variables z, theta) """
    MP = Model(Gurobi.Optimizer);
    set_optimizer_attributes(MP, 
        "TimeLimit" => time_limit, 
        "MIPGap" => optimality_gap, 
        "OutputFlag" => 0,)

    # MP variables
    @variable(MP, z[a in A], Bin) #1 if arc a is traveled by a vehicle (max 1 vehicle per arc)
    @variable(MP, θ)

    # MP constraints
    @constraint(MP, [d in depots], sum(z[a] for a in A_tilde_depot[d]) <= 1)
    @constraint(MP, [n in N_except_sink], sum(z[a] for a in A_minus[n]) <= 1)
    @constraint(MP, [n in N_star], sum(z[a] for a in A_plus[n]) - sum(z[a] for a in A_minus[n])==0)

    # MP objective
    @expression(MP, Veh, sum(c[a]*z[a] for a in A))
    @expression(MP, Veh_nb, sum(z[a] for d in depots, a in A_tilde_depot[d]))
    
    @objective(MP, Max, - alpha1*Veh -alpha0*Veh_nb + θ)

    # alpha1 = variable service cost (price per min) 
    # alpha0 = fixed service cost (price per vehicle used)
    
    lower_bound_all = []
    upper_bound_all = []
    z_MP_all, x_SP_all, xi_SP_all =[], [], []
    MP_time = []
    SP_time = []
    n_opt=0;
    n_it=0;
    xi_sol=nothing;x_sol=nothing;objs=nothing;z_MP=nothing;

    eta = 0.00001;

    while n_it < 5#true
        println("\n Iteration ",n_it+1)

        # Solve main problem
        push!(MP_time, @elapsed optimize!(MP))
        upper_bound_new = objective_value(MP)
        push!(upper_bound_all, upper_bound_new)
        z_MP = value.(MP[:z])
        push!(z_MP_all,z_MP)

        """ Define Sub Problem (variables x,xi) """
        obj_SP = nothing
        
        SP_primal = Model(Gurobi.Optimizer)
        @suppress set_optimizer_attributes(
            SP_primal, 
            "MIPGap" => optimality_gap, 
            "InfUnbdInfo" => 1, 
            "DualReductions" => 0, 
            "OutputFlag" => 0,)

        # SP variables
        @variable(SP_primal,xi[i in I, p in P[i]]>=0) # 1 if customer i is assigned to path p 
        @variable(SP_primal, x[i in I, a in Ai[i], p in P[i]]>=0) #1 if customer i is assigned to arc a with path p 

        # SP objective
        @expression(SP_primal, Walk, sum(P_desc[i][p]["walking"]*xi[i,p] for i in I, p in P[i]))
        @expression(SP_primal, Wait, sum((nodedesc[arcdesc[a][1]][2]-t[i]-data.wo[i,nodedesc[n][1]])*x[i,a,p] for i in I, p in P[i], n in O[i][p], a in Ai_plus[i][n]))
        @expression(SP_primal, Traveling, sum(c[a]*x[i,a,p] for i in I, p in P[i], a in Ai[i]))
        @expression(SP_primal, Tr, sum(P_desc[i][p]["transfer"]*xi[i,p] for i in I, p in P[i]))
        @expression(SP_primal, Served, sum(xi[i,p] for i in I, p in P[i]))

        @objective(SP_primal, Max, alpha2*Served - mu*Walk - beta*Wait -delta*Traveling - lambda*Tr)
        # alpha2 = course price 
        # mu = Cost of 1min cust walking 
        # beta = Cost of 1min cust waiting 
        # delta = Cost of 1mn cust traveling in bus 
        # lambda = Cost of cust transfers

        # SP constraints
        # 1 Path
        @constraint(SP_primal, onepath[i in I], sum(xi[i,p] for p in P[i]) <= 1 + eta) #each customer is assigned to max one path
        # Linking constraint x-xi        
        @constraint(SP_primal, [i in I, p in P[i], a in Ai[i]], x[i,a,p] - xi[i,p]<=0)
        # Pick-up
        @constraint(SP_primal, pick_up[i in I, p in P[i]], sum(x[i,a,p] for n in O[i][p], a in Ai_plus[i][n]) - xi[i,p]==0) #each customer is assigned to max one arc leaving a pick-up node from the selected path
        # Drop-off
        @constraint(SP_primal, [i in I, p in P[i]], sum(x[i,a,p] for n in D[i][p], a in Ai_minus[i][n]) - xi[i,p]==0) #each customer is assigned to exactly one arc incoming a drop-off node from the selected path if he is served
        # Transfer
        @constraint(SP_primal, [i in I, p in P_T[i]], sum(x[i,a,p] for n in H[i][p], a in Ai_minus_tilde[i][n]) - xi[i,p]==0) #each customer is assigned to max one arc incoming a transfer node if the selected path is indirect
        # CUST FLOW BALANCE CONSTRAINT
        @constraint(SP_primal, [i in I, p in P[i], n in N_except_o_d_H[i][p]], sum(x[i,a,p] for a in Ai_minus[i][n]) - sum(x[i,a,p] for a in Ai_plus[i][n])==0)
        # Transfer between two hubs parkings
        @constraint(SP_primal, [i in I, p in P[i], time in T], sum(x[i,a,p] for n in H_times[i][p][time], a in Ai_minus[i][n]) - sum(x[i,a,p] for n in H_times[i][p][time], a in Ai_plus[i][n])==0)
        # ROUTE CONSTRAINT
        @constraint(SP_primal, [i in I], sum(x[i,a,p] for p in P[i], n in N_vo[i], a in Ai_minus[i][n]) == 0) # customer cannot be assigned to an arc incoming one of his pick-up nodes
        @constraint(SP_primal, [i in I], sum(x[i,a,p] for p in P[i], n in N_vd[i], a in Ai_plus[i][n]) == 0) # customer cannot be assigned to an arc leaving one of his drop-off nodes
        # CAPACITY CONSTRAINT
        #@constraint(SP_primal, capacity[a in A], sum(q[i]*x[i,a,p] for i in Ia[a], p in P[i]) <= Q*z_MP[a])
        @constraint(SP_primal, capacity[a in A], sum(q[i]*x[i,a,p] for i in Ia[a], p in P[i]) <= Q*(z_MP[a]+eta*z0[a]))
        # LINKING CONSTRAINT x - z
        #@constraint(SP_primal, link_z[i in I, p in P[i], a in Ai_except_H[i][p]], x[i,Ai_except_H_desc[i][p][a],p] <= z_MP[Ai_except_H_desc[i][p][a]])
        @constraint(SP_primal, link_z[i in I, p in P[i], a in Ai_except_H[i][p]], x[i,Ai_except_H_desc[i][p][a],p] <= z_MP[Ai_except_H_desc[i][p][a]]+eta*z0[Ai_except_H_desc[i][p][a]])


        # Solve Subproblem
        timeSP=@elapsed optimize!(SP_primal)
        push!(SP_time, timeSP)

        obj_SP_primal = objective_value(SP_primal)
        objs_SP_primal=Dict("Walk" => round(value.(SP_primal[:Walk]),digits=2),
                        "Wait" => round(value.(SP_primal[:Wait]),digits=2),
                        "Cust driving" => round(value.(SP_primal[:Traveling]),digits=2),
                        "Tr" => round(value.(SP_primal[:Tr]),digits=2),
                        "Veh driving" => round(value.(MP[:Veh]),digits=2),
                        "Veh_nb" => round(value.(MP[:Veh_nb]),digits=2),
                        "Served" => round(sum(value.(SP_primal[:xi])),digits=2))
                        
        push!(x_SP_all,value.(SP_primal[:x]))
        push!(xi_SP_all,value.(SP_primal[:xi]))

        # Get dual variables that appear in dual objective
        lambda_val = Dict{Tuple{Int,Int,Int},Float64}()
        iota_val = Dict{Int,Float64}()
        epsilon_val = Dict{Int,Float64}()
        for i in I
            iota_val[i] = - dual(onepath[i])
            for p in P[i]
                for a in Ai_except_H[i][p]
                    lambda_val[i,p,a] = - dual(link_z[i,p,a])
                end
            end
        end
        for a in A
            epsilon_val[a] = - dual(capacity[a])
        end

        println("-------------------")
        # Sparsity count
        sparsity_lambda=count_nonzeros(lambda_val)
        length_lambda=length(lambda_val)
        #println("sparsity_lambda ",sparsity_lambda/length_lambda)
        println("sum lambda ", sum(values(lambda_val)))

        sparsity_epsilon=count_nonzeros(epsilon_val)
        length_epsilon=length(epsilon_val)
        #println("sparsity_epsilon ",sparsity_epsilon/length_epsilon)
        println("sum epsilon ", sum(values(epsilon_val)))

        length_iota=length(iota_val)
        sparsity_iota=count_nonzeros(iota_val)
        #println("sparsity_iota ",sparsity_iota/length_iota)
        println("sum iota ", sum(values(iota_val)))
        
        # If subproblem is bounded and solves to optimality, add optimality cut
        if termination_status(SP_primal) == MOI.OPTIMAL
            @constraint(MP, 
                θ <= sum(values(iota_val)) + sum(Q*epsilon_val[a] * z[a] for a in A) + sum(lambda_val[i,p,a]*z[Ai_except_H_desc[i][p][a]] for i in I, p in P[i], a  in Ai_except_H[i][p]))

            # check duality
            #obj_SP_dual = (1+eta)*sum(values(iota_val)) + sum(Q*epsilon_val[a] * z_MP[a] for a in A) + sum(lambda_val[i,p,a] * z_MP[Ai_except_H_desc[i][p][a]] for i in I for p in P[i] for a in Ai_except_H[i][p])
            obj_SP_dual = (1+eta)*sum(values(iota_val)) + sum(Q*epsilon_val[a] * (z_MP[a]+eta*z0[a]) for a in A) + sum(lambda_val[i,p,a] * (z_MP[Ai_except_H_desc[i][p][a]]+eta*z0[Ai_except_H_desc[i][p][a]]) for i in I for p in P[i] for a in Ai_except_H[i][p])

            if verbose
                round_obj_SP_primal=round(obj_SP_primal,digits=2)
                round_obj_SP_dual=round(obj_SP_dual,digits=2)
                println("SP primal obj $round_obj_SP_primal, SP dual obj $round_obj_SP_dual")
                println(objs_SP_primal)
            end
            n_opt += 1
        end

        # Update solve time metrics, upper bound
        obj_SP=obj_SP_primal
        lower_bound_new = obj_MP_profit_veh(z_MP,A,c,A_tilde_depot,alpha1,alpha0) + obj_SP
        push!(lower_bound_all, lower_bound_new)
        if verbose
            @printf("Sol: %.2f - Upper Bound: %.2f \n", lower_bound_all[end], upper_bound_all[end])
            print("\n")
        end

        xi_sol=value.(SP_primal[:xi])
        x_sol=value.(SP_primal[:x])
        objs=objs_SP_primal
        n_it+=1
        # Termination criteria
        if sum(MP_time) + sum(SP_time) ≥ time_limit 
            println("Time limit reached")
            break
        elseif abs((upper_bound_new - lower_bound_new) / lower_bound_new) < optimality_gap
            println("Optimality gap reached")
            break
        end
    end
    # Print the solution
    println("Objective value: ", lower_bound_all[end])
    
    solution = (xi=xi_sol,x=x_sol,z=z_MP, obj=upper_bound_all[end],time=sum(MP_time)+sum(SP_time),objs=objs)
    benders_prop=Dict("MP_time"=>MP_time,"SP_time"=>SP_time,"upper_bound_all"=>upper_bound_all,"lower_bound_all"=>lower_bound_all, "n_opt" =>n_opt, "n_it"=>n_it, "z_MP_all" => z_MP_all, "x_SP_all" => x_SP_all, "xi_SP_all" => xi_SP_all)
    return solution,benders_prop
end







""" Fixing z after 1st iteration """



function solve_benders_profit_zfix(direct_z,Q,abbrev,data,tsnetwork,params,coefficients,
    verbose::Bool = true,
    time_limit::Int = 180,
    optimality_gap::Float64 = 1e-3)

    """Solve problem using multi-cut Benders decomposition, giving the optimal z"""

    # Model parameters
    alpha2,alpha1,alpha0,mu,beta,delta,lambda=coefficients

    #Data
    q, t, I, K=abbrev
    A_plus, A_minus, arccost,nodedesc, arcdesc, T =tsnetwork.A_plus, tsnetwork.A_minus, tsnetwork.arccost,tsnetwork.nodedesc, tsnetwork.arcdesc, tsnetwork.times;
    P, P_desc, H, O, D, N_vo, N_vd, N_except_o_d_H, N_except_sink, P_T, H_times= params.P, params.P_desc, params.H, params.O, params.D, params.N_vo, params.N_vd, params.N_except_o_d_H, params.N_except_sink, params.P_T, params.H_times;
    A, Ai, Ai_plus, Ai_minus, Ai_minus_tilde, Ia, N, N_star, A_tilde_depot, Ai_except_H, Ai_except_H_desc=params.A, params.Ai, params.Ai_plus, params.Ai_minus, params.Ai_minus_tilde, params.Ia, params.N, params.N_star, params.A_tilde_depot, params.Ai_except_H, params.Ai_except_H_desc;
    c=arccost #  duration of the arc
    depots=keys(A_tilde_depot)

    """ Get z0 in int(conv(F)) for Pareto cuts """
    println("Looking for a core point z0...")
    z0=get_feasible_z(params,tsnetwork,data)
    println("Core point found !")

    """ Define Master Problem (variables z, theta) """
    MP = Model(Gurobi.Optimizer);
    set_optimizer_attributes(MP, 
        "TimeLimit" => time_limit, 
        "MIPGap" => optimality_gap, 
        "OutputFlag" => 0,)

    # MP variables
    @variable(MP, z[a in A], Bin) #1 if arc a is traveled by a vehicle (max 1 vehicle per arc)
    @variable(MP, θ)

    # MP constraints
    @constraint(MP, [d in depots], sum(z[a] for a in A_tilde_depot[d]) <= 1)
    @constraint(MP, [n in N_except_sink], sum(z[a] for a in A_minus[n]) <= 1)
    @constraint(MP, [n in N_star], sum(z[a] for a in A_plus[n]) - sum(z[a] for a in A_minus[n])==0)

    # MP objective
    @expression(MP, Veh, sum(c[a]*z[a] for a in A))
    @expression(MP, Veh_nb, sum(z[a] for d in depots, a in A_tilde_depot[d]))
    
    @objective(MP, Max, - alpha1*Veh -alpha0*Veh_nb + θ)

    # alpha1 = variable service cost (price per min) 
    # alpha0 = fixed service cost (price per vehicle used)
    
    lower_bound_all = []
    upper_bound_all = []
    z_MP_all, x_SP_all, xi_SP_all =[], [], []
    MP_time = []
    SP_time = []
    n_opt=0;
    n_it=0;
    xi_sol=nothing;x_sol=nothing;objs=nothing;z_MP=nothing;

    eta = 0.00001;

    while true
        println("\n Iteration ",n_it+1)

        # Solve main problem
        push!(MP_time, @elapsed optimize!(MP))
        upper_bound_new = objective_value(MP)
        push!(upper_bound_all, upper_bound_new)
        z_MP = value.(MP[:z])
        push!(z_MP_all,z_MP)

        """ Define Sub Problem (variables x,xi) """
        obj_SP = nothing
        
        SP_primal = Model(Gurobi.Optimizer)
        @suppress set_optimizer_attributes(
            SP_primal, 
            "MIPGap" => optimality_gap, 
            "InfUnbdInfo" => 1, 
            "DualReductions" => 0, 
            "OutputFlag" => 0,)

        # SP variables
        @variable(SP_primal,xi[i in I, p in P[i]]>=0) # 1 if customer i is assigned to path p 
        @variable(SP_primal, x[i in I, a in Ai[i], p in P[i]]>=0) #1 if customer i is assigned to arc a with path p 

        # SP objective
        @expression(SP_primal, Walk, sum(P_desc[i][p]["walking"]*xi[i,p] for i in I, p in P[i]))
        @expression(SP_primal, Wait, sum((nodedesc[arcdesc[a][1]][2]-t[i]-data.wo[i,nodedesc[n][1]])*x[i,a,p] for i in I, p in P[i], n in O[i][p], a in Ai_plus[i][n]))
        @expression(SP_primal, Traveling, sum(c[a]*x[i,a,p] for i in I, p in P[i], a in Ai[i]))
        @expression(SP_primal, Tr, sum(P_desc[i][p]["transfer"]*xi[i,p] for i in I, p in P[i]))
        @expression(SP_primal, Served, sum(xi[i,p] for i in I, p in P[i]))

        @objective(SP_primal, Max, alpha2*Served - mu*Walk - beta*Wait -delta*Traveling - lambda*Tr)
        # alpha2 = course price 
        # mu = Cost of 1min cust walking 
        # beta = Cost of 1min cust waiting 
        # delta = Cost of 1mn cust traveling in bus 
        # lambda = Cost of cust transfers

        # SP constraints
        # 1 Path
        @constraint(SP_primal, onepath[i in I], sum(xi[i,p] for p in P[i]) <= 1 + eta) #each customer is assigned to max one path
        # Linking constraint x-xi        
        @constraint(SP_primal, [i in I, p in P[i], a in Ai[i]], x[i,a,p] - xi[i,p]<=0)
        # Pick-up
        @constraint(SP_primal, pick_up[i in I, p in P[i]], sum(x[i,a,p] for n in O[i][p], a in Ai_plus[i][n]) - xi[i,p]==0) #each customer is assigned to max one arc leaving a pick-up node from the selected path
        # Drop-off
        @constraint(SP_primal, [i in I, p in P[i]], sum(x[i,a,p] for n in D[i][p], a in Ai_minus[i][n]) - xi[i,p]==0) #each customer is assigned to exactly one arc incoming a drop-off node from the selected path if he is served
        # Transfer
        @constraint(SP_primal, [i in I, p in P_T[i]], sum(x[i,a,p] for n in H[i][p], a in Ai_minus_tilde[i][n]) - xi[i,p]==0) #each customer is assigned to max one arc incoming a transfer node if the selected path is indirect
        # CUST FLOW BALANCE CONSTRAINT
        @constraint(SP_primal, [i in I, p in P[i], n in N_except_o_d_H[i][p]], sum(x[i,a,p] for a in Ai_minus[i][n]) - sum(x[i,a,p] for a in Ai_plus[i][n])==0)
        # Transfer between two hubs parkings
        @constraint(SP_primal, [i in I, p in P[i], time in T], sum(x[i,a,p] for n in H_times[i][p][time], a in Ai_minus[i][n]) - sum(x[i,a,p] for n in H_times[i][p][time], a in Ai_plus[i][n])==0)
        # ROUTE CONSTRAINT
        @constraint(SP_primal, [i in I], sum(x[i,a,p] for p in P[i], n in N_vo[i], a in Ai_minus[i][n]) == 0) # customer cannot be assigned to an arc incoming one of his pick-up nodes
        @constraint(SP_primal, [i in I], sum(x[i,a,p] for p in P[i], n in N_vd[i], a in Ai_plus[i][n]) == 0) # customer cannot be assigned to an arc leaving one of his drop-off nodes
        # CAPACITY CONSTRAINT
        #@constraint(SP_primal, capacity[a in A], sum(q[i]*x[i,a,p] for i in Ia[a], p in P[i]) <= Q*z_MP[a])
        @constraint(SP_primal, capacity[a in A], sum(q[i]*x[i,a,p] for i in Ia[a], p in P[i]) <= Q*(z_MP[a]+eta*z0[a]))
        # LINKING CONSTRAINT x - z
        #@constraint(SP_primal, link_z[i in I, p in P[i], a in Ai_except_H[i][p]], x[i,Ai_except_H_desc[i][p][a],p] <= z_MP[Ai_except_H_desc[i][p][a]])
        @constraint(SP_primal, link_z[i in I, p in P[i], a in Ai_except_H[i][p]], x[i,Ai_except_H_desc[i][p][a],p] <= z_MP[Ai_except_H_desc[i][p][a]]+eta*z0[Ai_except_H_desc[i][p][a]])


        # Solve Subproblem
        timeSP=@elapsed optimize!(SP_primal)
        push!(SP_time, timeSP)

        obj_SP_primal = objective_value(SP_primal)
        objs_SP_primal=Dict("Walk" => round(value.(SP_primal[:Walk]),digits=2),
                        "Wait" => round(value.(SP_primal[:Wait]),digits=2),
                        "Cust driving" => round(value.(SP_primal[:Traveling]),digits=2),
                        "Tr" => round(value.(SP_primal[:Tr]),digits=2),
                        "Veh driving" => round(value.(MP[:Veh]),digits=2),
                        "Veh_nb" => round(value.(MP[:Veh_nb]),digits=2),
                        "Served" => round(sum(value.(SP_primal[:xi])),digits=2))
                        
        push!(x_SP_all,value.(SP_primal[:x]))
        push!(xi_SP_all,value.(SP_primal[:xi]))

        # Get dual variables that appear in dual objective
        lambda_val = Dict{Tuple{Int,Int,Int},Float64}()
        iota_val = Dict{Int,Float64}()
        epsilon_val = Dict{Int,Float64}()
        for i in I
            iota_val[i] = - dual(onepath[i])
            for p in P[i]
                for a in Ai_except_H[i][p]
                    lambda_val[i,p,a] = - dual(link_z[i,p,a])
                end
            end
        end
        for a in A
            epsilon_val[a] = - dual(capacity[a])
        end

        println("-------------------")
        # Sparsity count
        sparsity_lambda=count_nonzeros(lambda_val)
        length_lambda=length(lambda_val)
        #println("sparsity_lambda ",sparsity_lambda/length_lambda)
        println("sum lambda ", sum(values(lambda_val)))

        sparsity_epsilon=count_nonzeros(epsilon_val)
        length_epsilon=length(epsilon_val)
        #println("sparsity_epsilon ",sparsity_epsilon/length_epsilon)
        println("sum epsilon ", sum(values(epsilon_val)))

        length_iota=length(iota_val)
        sparsity_iota=count_nonzeros(iota_val)
        #println("sparsity_iota ",sparsity_iota/length_iota)
        println("sum iota ", sum(values(iota_val)))
        
        # If subproblem is bounded and solves to optimality, add optimality cut
        if termination_status(SP_primal) == MOI.OPTIMAL
            @constraint(MP, 
                θ <= sum(values(iota_val)) + sum(Q*epsilon_val[a] * z[a] for a in A) + sum(lambda_val[i,p,a]*z[Ai_except_H_desc[i][p][a]] for i in I, p in P[i], a  in Ai_except_H[i][p]))
            @constraint(MP, [a in A], z[a] == direct_z[a])

            # check duality
            #obj_SP_dual = (1+eta)*sum(values(iota_val)) + sum(Q*epsilon_val[a] * z_MP[a] for a in A) + sum(lambda_val[i,p,a] * z_MP[Ai_except_H_desc[i][p][a]] for i in I for p in P[i] for a in Ai_except_H[i][p])
            obj_SP_dual = (1+eta)*sum(values(iota_val)) + sum(Q*epsilon_val[a] * (z_MP[a]+eta*z0[a]) for a in A) + sum(lambda_val[i,p,a] * (z_MP[Ai_except_H_desc[i][p][a]]+eta*z0[Ai_except_H_desc[i][p][a]]) for i in I for p in P[i] for a in Ai_except_H[i][p])

            if verbose
                round_obj_SP_primal=round(obj_SP_primal,digits=2)
                round_obj_SP_dual=round(obj_SP_dual,digits=2)
                println("SP primal obj $round_obj_SP_primal, SP dual obj $round_obj_SP_dual")
                println(objs_SP_primal)
            end
            n_opt += 1
        end

        # Update solve time metrics, upper bound
        obj_SP=obj_SP_primal
        lower_bound_new = obj_MP_profit_veh(z_MP,A,c,A_tilde_depot,alpha1,alpha0) + obj_SP
        push!(lower_bound_all, lower_bound_new)
        if verbose
            @printf("Sol: %.2f - Upper Bound: %.2f \n", lower_bound_all[end], upper_bound_all[end])
            print("\n")
        end

        xi_sol=value.(SP_primal[:xi])
        x_sol=value.(SP_primal[:x])
        objs=objs_SP_primal
        n_it+=1
        # Termination criteria
        if sum(MP_time) + sum(SP_time) ≥ time_limit 
            println("Time limit reached")
            break
        elseif abs((upper_bound_new - lower_bound_new) / lower_bound_new) < optimality_gap
            println("Optimality gap reached")
            break
        end
    end
    # Print the solution
    println("Objective value: ", lower_bound_all[end])
    
    solution = (xi=xi_sol,x=x_sol,z=z_MP, obj=upper_bound_all[end],time=sum(MP_time)+sum(SP_time),objs=objs)
    benders_prop=Dict("MP_time"=>MP_time,"SP_time"=>SP_time,"upper_bound_all"=>upper_bound_all,"lower_bound_all"=>lower_bound_all, "n_opt" =>n_opt, "n_it"=>n_it, "z_MP_all" => z_MP_all, "x_SP_all" => x_SP_all, "xi_SP_all" => xi_SP_all)
    return solution,benders_prop
end


function obj_MP_profit_veh(z, A, c, A_tilde_depot, alpha1, alpha0)
    res = - alpha1 * sum(c[a] * z[a] for a in A) - alpha0* sum(z[a] for d in keys(A_tilde_depot) for a in A_tilde_depot[d])
    return res
end

function obj_MP_veh(z, A, c, A_tilde_depot, alpha1, nu)
    res = alpha1 * (sum(c[a] * z[a] for a in A) + nu * sum(z[a] for d in keys(A_tilde_depot) for a in A_tilde_depot[d]))
    return res
end

function count_nonzeros(ab)
    count=0
    for i in eachindex(ab)
        if ab[i]!=0
            count+=1
        end
    end
    return count
end

function generate_route_depot(d, params, ts, locs_id, arcs_list, visited_nodes)
    # get the list of the arcs of the generated route
    
    # Pick a starting arc
    start_arc = params.A_tilde_depot[d][rand(1:end)]
    push!(arcs_list, start_arc)

    current_node = get_n2(start_arc,ts)
    current_loc = getL(current_node,ts)
    push!(visited_nodes,current_node)
    
    it=0
    while current_loc != locs_id[:sink]
        good_arc_found=false
        new_arc=nothing
        # Random pick of new arc from current node

        while !good_arc_found
            new_arc=ts.A_plus[current_node][rand(1:end)]
            arrival_node = get_n2(new_arc,ts)
        
            if !(new_arc in arcs_list) && !(arrival_node in visited_nodes) # check that the arc is not already selected
                good_arc_found = true
                
            end
        end
        push!(arcs_list, new_arc)
        current_node = get_n2(new_arc,ts)
        current_loc = getL(current_node,ts)
        if current_loc != locs_id[:sink]
            push!(visited_nodes,current_node)
        end

        it+=1
    end
    return arcs_list,visited_nodes
end

function get_feasible_z(params,tsnetwork,data)
    arcs_list,visited_nodes = [], []
    for d in data.locs_id[:depots]
        # generate two routes per depot loc
        arcs_list,visited_nodes=generate_route_depot(d, params, tsnetwork, data.locs_id, arcs_list, visited_nodes)
        arcs_list,visited_nodes=generate_route_depot(d, params, tsnetwork, data.locs_id, arcs_list, visited_nodes)
    end

    artif_pb = Model(Gurobi.Optimizer)
    set_optimizer_attributes(artif_pb,"OutputFlag" => 0,)
    # Solve artificial problem to define z correctly
    @variable(artif_pb, 0<=z[a in params.A]<=1) #1 if arc a is traveled by a vehicle (max 1 vehicle per arc)
    @constraint(artif_pb,fix[a in arcs_list], z[a] == 0.5)
    @objective(artif_pb, Min,sum(z)) # put 0 on other arcs
    optimize!(artif_pb)
    
    z_feas=value.(artif_pb[:z])
    return z_feas
end


