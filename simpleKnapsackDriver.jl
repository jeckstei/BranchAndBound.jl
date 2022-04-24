include("SimpleKnapsack.jl")

using Printf

@printf("Reading problem %s\n",ARGS[1])

problem = SimpleKnapsackRead(ARGS[1])

@printf("Read problem with %d items\n",problem.numItems)

setup!(problem)

problem.param.printFreq = 1000
#problem.param.debug = 1

@printf("Setup complete, starting search\n\n")
solution = SimpleKnapsackSolution(0,Set{Int32}())
numBounded = Int64(0)

#solution, numBounded, timeSpent = 
object = @timed(search(problem))

@printf("\nAfter bounding %d subproblems, the result has value %f\n",
        object.value[2], object.value[1].value)
@printf("Time is %f seconds\n",object.time)

# byNumber, byName = translateSolution(solution,problem)
# display(byName)

println("\nSuccessful completion.\n")
