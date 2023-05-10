import Pkg; Pkg.add("FileIO")
using JuMP, Gurobi, Random, CSV, DataFrames, Statistics, JLD2, FileIO

# TO DO : SPLIT ONE SCRIPT FOR WITH AND ONE SCRIPT FOR WITHOUT K

function solve_with_k(model_inputs,map_inputs)
    
    coefficients=1,1,1,0.01,20,0
    
end

