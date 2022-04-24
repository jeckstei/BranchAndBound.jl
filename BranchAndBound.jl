using DataStructures
using Printf

# Abstract type for branch-and-bound problems
abstract type BnBSolution end
abstract type BnBProblem  end
abstract type BnBNode     end


mutable struct BnBParams
    absTol::Float64
    relTol::Float64
    printFreq::Int32
    debug::Bool
    BnBParams() = new(0.0,1e-7,100,false)   # Default values of parameters
end


# Macro that generates the common elements of every branch-and-bound solution
macro BnBSolutionCore()
    return esc(quote
        value::Float64
    end)
end


# Macro that generates the common elements of every branch-and-bound problem
macro BnBProblemCore(SolutionType)
    return esc(quote
        sense::Float64                    # +1 for min and -1 for max
        incumbent::$SolutionType
        param::BnBParams
    end)
end


# Macro that generates the common elements of every branch and bound node
macro BnBNodeCore()
    return esc(quote
        bound::Float64
        id::Int64
        depth::Int32
    end)
end


#  Decide whether a bound is good enough to prune a node
function Fathom(bound::Float64, problem::BnBProblem)::Bool
    incVal = problem.incumbent.value
    absDiff = (incVal - bound)*problem.sense
    if absDiff <= 0 || absDiff < problem.param.absTol
        return true
    end
    scaleFactor = abs(bound)
    if scaleFactor == 0
        scaleFactor = abs(incVal)
    end
    return absDiff <= scaleFactor*problem.param.relTol
end


# Gives minimum bound if whichEnd is +1, the maximum bound if it's -1
function endBound(queue::BinaryMinMaxHeap{T},
                  whichEnd::Float64)::Float64 where {T<:BnBNode}
    if whichEnd >= 0.0
        return minimum(queue).bound
    else
        return maximum(queue).bound
    end
end


# Pops the minimum queue element if whichEnd is +1, the maximum bound if it's -1
function endPop!(queue::BinaryMinMaxHeap{T},
                 whichEnd::Float64)::T where {T<:BnBNode}
    if whichEnd >= 0.0
        return popmin!(queue)
    else
        return popmax!(queue)
    end
end



# Branch and Bound search
function search(problem::BnBProblem)
    problem.incumbent = initialGuess(problem)
    if problem.param.debug > 0
        @printf("Initial solution value is %f\n",problem.incumbent.value)
    end
    currentIncVal = problem.incumbent.value
    root = rootNode(problem)
    idCounter = 1
    root.id = idCounter
    root.depth = 0
    queue = BinaryMinMaxHeap{typeof(root)}()
    push!(queue, root)
    numBounded::Int64 = 0
    while length(queue) > 0
        # Retrieve the "best" subproblem on the heap
        subproblem = endPop!(queue,problem.sense)
        spBound = computeBound!(subproblem,problem)
        if problem.param.debug > 0
            @printf("Got bound of %f for node %d\n", spBound, subproblem.id)
        end
        numBounded += 1
        if !Fathom(spBound, problem)
            getSolution!(subproblem,problem.incumbent,problem)
            if problem.sense * (problem.incumbent.value - currentIncVal) < 0
                # Got an improved solution:  make it a new incumbent and
                # prune the heap.  The "-" in the call to endBound makes it find
                # the bound of the worst subproblem in the heap
                currentIncVal = problem.incumbent.value
                while length(queue) > 0 && 
                      Fathom(endBound(queue,-problem.sense), problem)
                    endPop!(queue,-problem.sense)
                end
                if problem.param.debug > 0
                    @printf(
                        "New incumbent value of %f, pruned queue to size %d\n",
                        currentIncVal,length(queue)
                    )
                end
            end
            if !terminal(subproblem,problem)
                if problem.param.debug > 0
                    @printf("Separating the subproblem\n")
                end
                numChildren = separate!(subproblem,problem)
                for i = 1:numChildren
                    child = makeChild(subproblem, i, problem)
                    idCounter += 1
                    child.id = idCounter
                    if problem.param.debug > 0
                        @printf(
                            "Made child %d with id=%d, with bound %f\n",
                            i,
                            idCounter,
                            child.bound
                        )
                    end
                    if !Fathom(child.bound, problem)
                        child.depth = subproblem.depth + 1
                        push!(queue, child)
                        if problem.param.debug > 0
                            @printf("Put it in the queue\n")
                        end
                    end
                end      # Putting children in queue
            end          # Subproblem not terminal
        end              # if the subproblem was not fathomed
        if problem.param.printFreq > 0 &&
           numBounded % problem.param.printFreq == 0 &&
           length(queue) > 0
            globalBound = endBound(queue,problem.sense)
            incVal = problem.incumbent.value
            scaleFactor = abs(globalBound)
            if scaleFactor == 0
                scaleFactor = abs(incVal)
            end
            if scaleFactor > 0
                gap = problem.sense*(incVal - globalBound)/scaleFactor
            else
                gap = 0.0
            end
            @printf(
                "Bounded=%d Pool=%d Bound=%f Inc=%f Gap=%.4f%%\n",
                numBounded,
                length(queue),
                globalBound,
                incVal,
                100*gap
            )
        end
    end                      # while the queue is nonempty
    return problem.incumbent, numBounded
end


# Overload that allow the heap to work

function Base.:isless(x::BnBNode, y::BnBNode)
    return x.bound < y.bound
end
