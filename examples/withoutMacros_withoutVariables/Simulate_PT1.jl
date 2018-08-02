################################################
#
# Simulate model\PT1
#
# Author: Martin Otter, DLR-SR
#         (first version: Nov. 19, 2016)
#
################################################

"""
    Simulate_PT1 - Simulate PT1 model
"""
module Simulate_PT1

include(joinpath("models","PT1.jl"))
import .PT1
import ModiaMath

model  = PT1.Model(T=2.0, x0=1.5)
result = ModiaMath.simulate!(model, stopTime=10.0; log=true) 

ModiaMath.plot(result, ["x[1]", "der(x[1])"], heading = "PT1 model (T*der(x) + x = 0; T = " * string(model.T) * ")")

end