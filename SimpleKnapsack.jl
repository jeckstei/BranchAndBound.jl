include("BranchAndBound.jl")


mutable struct SimpleKnapsackSolution<:BnBSolution
    @BnBSolutionCore()
    items::Set{Int32}
    SimpleKnapsackSolution() = new(0,Set{Int32}())        # Default constructor
    SimpleKnapsackSolution(v::Int64,items::Set{Int32}) = 
                                   new(v,copy(items))     # Better constructor
end


mutable struct SimpleKnapsackProblem<:BnBProblem
    @BnBProblemCore(SimpleKnapsackSolution)
    capacity::Int64
    numItems::Int32
    names::Vector{String}
    rawValue::Vector{Int32}
    rawWeight::Vector{Int32}
    perm::Vector{Int64}       # Sort permutation
    value::Vector{Int32}      # Sorted by value/weight
    weight::Vector{Int32}     # Sorted by value/weight
    currentItems::Set{Int32}  # Res are working variables for bounding etc.
    currentVal::Int64
    currentWeight::Int64
    spaceLeft::Int64
    itemIndex::Int32

    SimpleKnapsackProblem(capacity_::Int64,               # Constructor
                          names_::Vector{String},
                          rawValue_::Vector{Int32},
                          rawWeight_::Vector{Int32}) =
        new(-1,                             # Sense
            SimpleKnapsackSolution(),       # Empty solution
            BnBParams(),
            capacity_,
            length(rawValue_),
            names_,
            rawValue_,
            rawWeight_,
            [],[],[],Set{Int32}(),0,0,0)
end


mutable struct SimpleKnapsackNode<:BnBNode
    @BnBNodeCore()
    lockedIn::Set{Int32}
    lockedOut::Set{Int32}
end


function setup!(problem::SimpleKnapsackProblem)::Nothing
    ratios = Vector{Float64}(problem.rawValue)./problem.rawWeight
    problem.perm = sortperm(ratios,rev=true)
    problem.value = problem.rawValue[problem.perm]
    problem.weight = problem.rawWeight[problem.perm]
    problem.param.absTol = max(problem.param.absTol,gcd(problem.value))
    return nothing
end


function completeGreedy!(problem::SimpleKnapsackProblem,
                         currentItem::Int32,
                         currentValue::Int64,
                         alreadyIn::Set{Int32},
                         spaceLeft::Int64,
                         ignore1::Set{Int32},
                         ignore2::Set{Int32},
                         solution::SimpleKnapsackSolution)::Nothing
    inItems = copy(alreadyIn)
    for i = currentItem:problem.numItems
        if !in(i,ignore1) && !in(i,ignore2) && problem.weight[i] <= spaceLeft
            spaceLeft -= problem.weight[i]
            currentValue += problem.value[i]
            push!(inItems,i)
         end
        if spaceLeft == 0
            break
        end
    end
    if problem.sense * (currentValue - solution.value) < 0
        solution.value = currentValue
        solution.items = inItems
    end
    return nothing
end


function initialGuess(problem::SimpleKnapsackProblem)::SimpleKnapsackSolution
    firstSol = SimpleKnapsackSolution(0,Set{Int32}())
    completeGreedy!(problem,
                    Int32(1),           # Start at first item
                    0,                  # No value yet
                    Set{Int32}(),       # Nothing already in knapsack
                    problem.capacity,   # All the space remains unused
                    Set{Int32}(),       # Don't exclude anything
                    Set{Int32}(),       # Ditto
                    firstSol)
    return firstSol
end


function rootNode(problem::SimpleKnapsackProblem)::SimpleKnapsackNode
    return SimpleKnapsackNode(0,0,0,Set{Int32}(),Set{Int32}())
end


function computeBound!(node::SimpleKnapsackNode,
                       problem::SimpleKnapsackProblem)::Float64
    problem.currentItems = copy(node.lockedIn)
    problem.spaceLeft = problem.capacity
    problem.currentVal = 0
    for i in problem.currentItems
        problem.spaceLeft -= problem.weight[i]
        problem.currentVal += problem.value[i]
    end
    if problem.spaceLeft < 0
        node.bound = -Inf
        return -Inf
    end
    i = Int32(1)
    while i <= problem.numItems
        if !in(i,node.lockedIn) && !in(i,node.lockedOut)
            if problem.weight[i] <= problem.spaceLeft
                push!(problem.currentItems,i)
                problem.spaceLeft -= problem.weight[i]
                problem.currentVal += problem.value[i]
            else
                break
            end
        end
        i += 1
    end
    node.bound = problem.currentVal
    problem.itemIndex = i
    if i <= problem.numItems
        node.bound += problem.value[i] * 
                          (Float64(problem.spaceLeft)/problem.weight[i])
    end
    return node.bound
end
        

function getSolution!(node::SimpleKnapsackNode,
                      solution::SimpleKnapsackSolution,
                      problem::SimpleKnapsackProblem)::Nothing
    completeGreedy!(problem,
                    problem.itemIndex,
                    problem.currentVal,
                    problem.currentItems,
                    problem.spaceLeft,
                    node.lockedIn,
                    node.lockedOut,
                    solution)
    return nothing
end


function terminal(node::SimpleKnapsackNode,
                  problem::SimpleKnapsackProblem)::Bool
    return problem.spaceLeft == 0 ||
           problem.itemIndex > problem.numItems
end


function separate!(node::SimpleKnapsackNode,
                   problem::SimpleKnapsackProblem)::Int32
    return 2
end


function makeChild(node::SimpleKnapsackNode,
                   whichChild::Int64,
                   problem::SimpleKnapsackProblem)::SimpleKnapsackNode
    if whichChild == 1
        newLockedIn = copy(node.lockedIn)
        push!(newLockedIn,problem.itemIndex)
        return SimpleKnapsackNode(node.bound,
                                  0,              # Filled in by searcher
                                  0,              # Filled in by searcher
                                  newLockedIn,
                                  node.lockedOut)
    elseif whichChild == 2        newLockedOut = copy(node.lockedOut)
        push!(newLockedOut,problem.itemIndex)
        return SimpleKnapsackNode(node.bound,
                                  0,              # Filled in bysearcher
                                  0,              # Filled in by searcher
                                  node.lockedIn,
                                  newLockedOut)
    else
        error(string(i, " is not a valid child number"))
    end
end


function translateSolution(solution::SimpleKnapsackSolution,
                           problem::SimpleKnapsackProblem)
    n = length(solution.items)
    itemVector = Vector{Int32}(undef,n)
    j = Int32(1)
    for i in solution.items
        itemVector[j] = problem.perm[i]
        j += 1
    end
    byNumber = sort(itemVector)
    byName = Vector{String}(undef,n)
    for i = 1:n
        byName[i] = problem.names[byNumber[i]]
    end
    return byNumber, byName
end


function SimpleKnapsackRead(filename::String)::SimpleKnapsackProblem
    counter = Int32(0)
    names = Vector{String}()
    rawWeights = Vector{Int32}()
    rawValues  = Vector{Int32}()
    capacity = Int64(-1)
    for line in eachline(filename)
        tokens = split(line)
        if counter > 0
            push!(names,tokens[1])
            push!(rawWeights,parse(Int32,tokens[2]))
            push!(rawValues,parse(Int32,tokens[3]))
        else
            capacity = parse(Int64,tokens[1])
        end
        counter += 1
    end
    return SimpleKnapsackProblem(capacity,names,rawValues,rawWeights)
end
