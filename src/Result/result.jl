# License for this file: MIT (expat)
# Copyright 2017-2018, DLR Institute of System Dynamics and Control
#
# This file is part of module 
#   ModiaMath.Result (ModiaMath/Result/_module.jl)
#

#---------------------------- Acessing the time series results (various options)
appendUnit(name, unit) = unit == "" ? string(name) : string(name, " [", unit, "]")

function getStringDictResult(model, res::RawResult)
    nt     = res.nt
    data   = res.data
    result = Dict{AbstractString,Any}()
    for (i, name) in enumerate(res.names)
        result[name] = @view data[1:nt,i]
    end

    return result, nt
end


const StringDictAnyResult = Dict{AbstractString,Any}
resultHeading(result::StringDictAnyResult) = ""

function getSignal(seriesDict::StringDictAnyResult, name::AbstractString)
    if haskey(seriesDict, name)
        sig     = seriesDict[name]
        keyName = name
    else
        if name[end] == ']'
            @static if VERSION >= v"0.7.0-DEV.2005"
                indexRange = something(findlast("[", name), 0:-1)
            else
                indexRange = rsearch(name, "[")
            end
            i = indexRange[1]
            @assert(i >= 2)
            keyName = name[1:i-1]
    
            if haskey(seriesDict, keyName)
                sig2 = seriesDict[keyName]

                # Build AST and evaluate: sig = sig2[:,...]
                ex1 = Meta.parse(name[i:end])
                ex2 = :( $sig2[:] )
                append!(ex2.args, ex1.args)
                sig = @eval $ex2
                if ndims(sig) != 1
                    @static if VERSION >= v"0.7.0-DEV.2005"
                        @warn "ModiaMath.plot: argument name (= $name) does not characterize one array element\nIndex ranges are not yet supported."
                    else
                        warn("ModiaMath.plot: argument name (= $name) does not characterize one array element\nIndex ranges are not yet supported.")
                    end
                    sig = nothing
                end

            else
                @static if VERSION >= v"0.7.0-DEV.2005"
                    @warn "ModiaMath.plot: argument name (= $name) is not correct."
                else
                    warn("\nModiaMath.plot: argument name (= ", name, ") is not correct.")
                end
                sig = nothing
            end  
    
        else
            @static if VERSION >= v"0.7.0-DEV.2005"
                @warn "ModiaMath.plot: argument name (= $name) is not correct or does not identify a signal in the result."
            else
                warn("\nModiaMath.plot: argument name (= ", name, ") is not correct or does not identify a signal in the result.")
            end
            sig = nothing
            keyName = name
        end
    end
    return (sig, keyName, name)
end


"""
    (xsig, xsigLegend, ysig, ysigLegend) = 
           ModiaMath.resultTimeSeries(result, name, xLabel::Bool, xAxis)

For a desired `result` data structure, this function has to be provided
to return the x-vector (`xsig`), the y-vector (`ysig`) and the legend
of the x-vector (`xsigLegend`), and of the y-vector (`ysigLegend`) as Strings, given 
the key of the y-vector (`name`) and the key of the x-vector (`xAxis`).
If `xLabel=false` the legend of the x-vector should be an empty string (`""`).
"""
function resultTimeSeries(result::StringDictAnyResult, name, xLabel::Bool, xAxis)
    # Get x-axis signal
    (xsig, xkeyName, xName) = getSignal(result, string(xAxis))
    if xsig == nothing 
        return (nothing, nothing, nothing, nothing)
    end
    if ndims(xsig) != 1
        @static if VERSION >= v"0.7.0-DEV.2005"
            @warn "ModiaMath.plot: argument xAxis (= $xAxis) does not characterize a signal vector."
        else
            warn("\nModiaMath.plot: argument xAxis (= $xAxis) does not characterize a signal vector.")
        end
        return (nothing, nothing, nothing, nothing)
    end
    xsigLegend = xLabel ? appendUnit(string(xAxis), string(unit(xsig[1]))) : ""
    xsig       = convert.(Float64, ustrip.(xsig))


    # Get y-axis signals
    (ysig, ykeyName, yName) = getSignal(result, string(name))
    
    if ysig == nothing
        return (nothing, nothing, nothing, nothing) 
    end
  
    if ndims(ysig) == 0 
        # ysig is a scalar
        # Construct a constant time series with two points at the first and the last value of the time vector
        ysigLegend = [appendUnit(yName, string(unit(ysig)))]
        xsig = [xsig[1], xsig[end]]
        ysig = [ysig   , ysig     ]
    elseif ndims(ysig) == 1
        # ysig is a vector
        ysigLegend = [appendUnit(yName, string(unit(ysig[1])))]
    elseif ndims(ysig) == 2
        # ysig is a matrix
        nLegend = size(ysig,2)
        @static if VERSION >= v"0.7.0-DEV.2005"
            ysigLegend = Array{String}(undef, nLegend)
        else
            ysigLegend = Array{String}(nLegend)
        end

        for i = 1:nLegend
            ysigLegend[i] = appendUnit(ykeyName*"["*string(i)*"]", string(unit(ysig[1,i])))
        end
    else
        @static if VERSION >= v"0.7.0-DEV.2005"
            @warn "ModiaMath.plot: Variable $ykeyName is not plotted because variables with more as one dimension not yet supported."
        else
            warn("\nModiaMath.plot: Variable $ykeyName is not plotted because variables with more as one dimension not yet supported.")
        end
        return (nothing, nothing, nothing, nothing)
    end

    ysig = convert.(Float64, ustrip.(ysig))


    return (xsig, xsigLegend, ysig, ysigLegend)
end


sizeToString(value::Any)    = string( size(value) ) 
sizeToString(value::Number) = ""

"""
    table = resultTable(result)

Return the variables stored in `result` in form of a DataFrames table
(which can then be printed/showed in various forms).

`Base.show(io, result)` is defined to print `resultTable(result)`,
in case result is of type ModiaMath.ResultWithVariables.

# Examples
```julia
import ModiaMath
using  Unitful

t = range(0.0, stop=10.0, length=100)
result = Dict{AbstractString,Any}()
result["time"] = t * u"s";
result["phi"]  = sin.(t)u"rad";

# Print table of the variables that are stored in result
println("result variables = ", ModiaMath.resultTable(result))

# Results in
result variables =
│ Row │ name   │ elType  │ sizeOrValue   │ unit   │
│     │ String │ String  │ String        │ String │
├─────┼────────┼─────────┼───────────────┼────────┤
│ 1   │ phi    │ Float64 │ (100,)        │ rad    │
│ 2   │ time   │ Float64 │ (100,)        │ s      │

```

"""
function resultTable(result::StringDictAnyResult)
    resultTable = DataFrames.DataFrame(name=String[], elType=String[], sizeOrValue=String[], unit=String[])

    for key in sort( collect( keys(result) ) )
        value = result[key]

        # Determine unit as string (if columns have different units, provide unit per column)
        strippedValue = ustrip.(value) # Strip units from value
        tvalue = typeof( strippedValue )
        tsize  = ndims(value) > 0 ? sizeToString( strippedValue ) : string( strippedValue )
        if tvalue <: Number
            tunit = string( unit(value) )
        elseif tvalue <: AbstractVector || (tvalue <: AbstractMatrix && size(value,2) == 1)
            tunit = string( unit( value[1] ) )
        elseif tvalue <: AbstractMatrix
            tunit = string( unit( value[1] ) )
            columnsHaveSameUnit = true
            for i in 2:size(value,2)
                if string( unit( value[1,i] ) ) != tunit 
                    columnsHaveSameUnit = false
                    break
                end
            end
            if !columnsHaveSameUnit
                tunit = "[" * tunit
                for i in 2:size(value,2)
                     tunit = tunit * ", " * string( unit( value[1,i] ) )
                end
                tunit = tunit * "]"
            end 
        else
            tunit = "???"
        end

        push!(resultTable, [key, string( typeof(strippedValue[1]) ), tsize, tunit] )
    end
    return resultTable
end


"""
    mutable struct ResultWithVariables

Struct that is generated as a result of ModiaMath.simulate!(...),
if the model is a Modia3D.AbstractComponentWithVariables struct.
"""
mutable struct ResultWithVariables
    "Dictionary of time series (elements can be Float64/Int64/Bool Vectors or Matrices)"
    series::StringDictAnyResult 

    "Dictionary of variables (elements are <: ModiaMath.AbstractVariable with required fields value and unit)"
    var::Dict{Symbol,Any}   

    "String used as optional heading of a plot window"                                   
    resultHeading::String

    ResultWithVariables(series, var, resultHeading="") = new(series, var, resultHeading)
end

resultHeading(result::ResultWithVariables) = result.resultHeading


function resultTimeSeries(result::ResultWithVariables, name, xLabel::Bool, xAxis)
    seriesDict = result.series

    # Get x-axis signal
    (xsig, xkeyName, xName) = getSignal(seriesDict, string(xAxis))
    if xsig == nothing 
        return (nothing, nothing, nothing, nothing)
    end
    if ndims(xsig) != 1
        @static if VERSION >= v"0.7.0-DEV.2005"
            @warn "ModiaMath.plot: argument xAxis (= $xAxis) does not characterize a signal vector."
        else
            warn("\nModiaMath.plot: argument xAxis (= $xAxis) does not characterize a signal vector.")
        end
        return (nothing, nothing, nothing, nothing)
    end
    xsigLegend = xLabel ? appendUnit(xName, result.var[Symbol(xkeyName)].unit) : ""


    # Get y-axis signal(s)
    (ysig, ykeyName, yNameAsString) = getSignal(seriesDict, string(name))
    symbol_ykeyName = Symbol(ykeyName)

    if ysig == nothing
        return (nothing, nothing, nothing, nothing) 
    end
    
    yvar = result.var[symbol_ykeyName]
    if ndims(ysig) == 0 
        # ysig is a scalar
        # Construct a constant time series with two points at the first and the last value of the time vector
        ysigLegend = [appendUnit(yNameAsString, yvar.unit)]
        xsig = [xsig[1], xsig[end]]
        ysig = [ysig   , ysig     ]

    elseif ndims(ysig) == 1
        # ysig is a vector
        ysigLegend = [appendUnit(yNameAsString, yvar.unit)]

    else
        # sig has more as one dimension
        @static if VERSION >= v"0.7.0-DEV.2005"
            ysigLegend = Array{String}(undef, length(yvar.value))
        else
            ysigLegend = Array{String}(length(yvar.value))
        end

        for i in eachindex(yvar.value)
            ysigLegend[i] = appendUnit(ModiaMath.indexToString(symbol_ykeyName, yvar.value, i), yvar.unit)
        end
    end
    
    return (xsig, xsigLegend, ysig, ysigLegend)
end


function resultTable(result::ResultWithVariables)
    resultTable = DataFrames.DataFrame(name=String[], elType=String[], sizeOrValue=String[], unit=String[], info=String[])
    series      = result.series
    vars        = result.var

    for key in sort( collect( keys(series) ) )
        value = series[key]
        var   = vars[Symbol(key)]
        tsize = ndims(value) > 0 ? sizeToString( value ) : string( value )
        push!(resultTable, [key, string( typeof(value[1]) ), tsize, var.unit, var.info] )
    end
    return resultTable
end


function Base.show(io::IO, result::ResultWithVariables)
    @static if VERSION >= v"0.7.0-DEV.2005" 
        show(io, resultTable(result), summary=false, splitcols=true)
    else
        show(io, resultTable(result))
    end
end




getHeading(result, heading) = heading != "" ? heading : resultHeading(result)

