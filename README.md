## BranchAndBound.jl

#### Jonathan Eckstein, April 2022

`BranchAndBound.jl` provides a simple abstract branch-and-bound optimization search engine for Julia.  Its design is inspired by the the parallel C++ branch-and-bound framework [PEBBL](https://github.com/PEBBL), although it is far simpler, has many fewer features, and has no parallel capabilities.  To create a branch-and-bound solver for a class of problems with `BranchAndBound.jl`, one must define three `mutable struct` datatypes and seven matching methods.  The three datatypes are

1. A solution dataype
2. A problem datatypte
3. A search node datatype

The seven methods are

1.  An `initialGuess` method that finds an initial, heuristic problem solution.  If there is no way to compute such a solution, this method may create a solution whose objective value is infinite.
2.  A `rootNode` method that creates the subproblem at the root of the branch-and-bound search tree.
3.  A `computeBound!` method that finds the bound of a subproblem.
4.  A `getSolution!` method that retrieves a possibly improved problem solution from a search node.
5.  A `terminal` method that determines whether it is necessary to subdivide a search node at one of the leaves of the search tree.
6.  A `separate!` method that determines how to branch a search node.
7.  A `makeChild!` method that creates a specified child node of a search node.

An example of how to create these types and methods is in the  `SimpleKnapsack.jl` example file included in this repository.  This file defines types and methods for the solution of simple binary knapsack problems, using the linear programming relaxation to provide a bound.  It should be emphasized that the purpose of the example is to illustrate the use of `BranchAndBound.jl` and it is *not* intended as an example of an efficient way to solve knapsack problems.  Knapsack cover cut techniques and/or dynamic programming method would be far more efficient.

The `search` function in `BranchAndBound.jl` performs branch-and-bound search.

`BranchAndBound.jl` only uses "best-first" search, in which subproblems are evaluated by order of their bounds, guaranteeing that no subproblems whose parent's bound is worse than the optimal solution is every processed.  This procedure uses a priority queue implemented using the `BinaryMinMaxHeap` constainer from Julia's standard `DataStructures` package.  `BranchAndBound.jl` uses a "lazy" evaluation protocol in which subproblems are placed in the queue using bounds that are typically equal to their parents.  When a subproblem is "popped" from the front of the queue for processing, its bound is computed, and then (if necessary) its children are created and placed in the queue.


### The Solution Type
To apply `BranchAndBound.jl`, one must define a *solution type*.  This `mutable struct` must be a subtype of `BnBSolution` as defined in `BranchAndBound.jl`, and its field definition should start with the macro `@BnBSolutionCore()`.  For the simple knapsack application, the solution type is called `SimpleKnapsackSolution`; see the definition in `SimpleKnapsack.jl`.  The elements of this `struct` are the solution value and a set of knapsack items included in the solution.

### The Problem Type
The *problem type* is a datatype describing a problem instance and holding working variables for the branch-and-bound search procedure.  The problem type should be a subtype of `BnBProblem`.  In the simple knapsack example, this type is called `SimpleKnapsackProblem`.  Its field definitions should start with the macro `@BnBProblemCore(`*solutionType*`)`, where *solutionType* is the solution type.  Thus, in the simple knapsack solver example, the field definitions start with

	@BnBProblemCore(SimpleKnapsackSolution)

The `@BnBProblemCore` macro defines a variety of fields required by `BranchAndBound.jl`, including:

* The `sense` of the optimization problem, which should be set to +1 for minimization and --1 for maximization.
* An `incumbent` object of type *solutionType* object that holds the best solution found so far (including its objective value).  When the branch-and-bound search process completes, this object should hold an optimal or near-optimal solution.
* A parameter sub-structure called `param`.  The members of this parameter block are
	+ `absTol`: an absolute tolerance
	+ `relTol`: a relative tolerance
	+ `printFreq`: the number of subproblem bounds to compute between status printouts during search.  If `printFreq` set to zero, there are no status printouts
	+ `debug`: a `Bool` indicating whether to print debugging information.

The solution produced by the search is guaranteed to be within an additive distance `absTol` *or* a relative distance `relTol` from the optimal one.  

### The Node Type
Finally, one must also define a *node type*, which is the datatype of all the nodes in the branch-and-bound tree.  This `mutable struct` should be a subtype of `BnBNode` and its field definitions should begin with the macro `@BnBNodeCore()`.  Among other things, this macro defines a field `bound` to hold the subproblem bound.  In the simple knapsack example, the node type is called `SimpleKnapsackNode`. 

In the simple knapsack example, each node is characterized by two sets of integers, one specifying "locked in" items that must be included in the soluion, and the other specifying "locked out" items that cannot be included in the solution.


### The `initialGuess` method

This initial guess method has two purposes:  to determine the datatype of the problem solution and to provide an initial, heuristically determined solution.  If the latter is not possible, `initialGuess` may return a solution whose value is positive infinity (for a minimization proble) or negative infinity (for a maximization problem).  The `initialGuess` method should take one argument, a problem instance object of the problem type, and return an object of the solution type.  For the simple knasack example, it is thus defined by 

	function initialGuess(problem::SimpleKnapsackProblem)::SimpleKnapsackSolution

In the simple knapsack case, `initialGuess` uses a simple "greedy" procedure.  Scanning the items in decreasing order of their ratio of value to weight, it inserts each item that will still fit.


###  The `rootNode` Method
The `rootNode` method creates the root node of the branch-and-bound tree.  It should take a single argument of the problem type, and return an object of the node type.  In the simple knapsack example, it takes a `simpleKnapsackProblem` argument and returns a `SimpleKnapsackNode` object with the "locked in" and "locked out" sets both empty.


### The `computeBound!` Method
`BranchAndBound.jl` uses the `computeBound!` method to compute the bounds of subproblems.  This method takes two arguments, the first being the node whose bound is to be computed and the second being the associated problem object.  It should compute the bound of the subproblem and return it as a `Float64`.  In the case of the simple knapsack solver, the function is defined as 

	function computeBound!(node::SimpleKnapsackNode,
                           problem::SimpleKnapsackProblem)::Float64

The `computeBound!` method should also store the newly computed bound in the subproblem's `bound` field (hence it modifies it argument, so its name includes an exclamation mark) by the standard Julia convention.

In the simple knapsack application, `computeBound!` first forces all "locked in" items into the knapsack.  Then, scanning in decreasing order of the ratio of value to weight, it inserts each possible item into the knapsack, ignore those that are "locked out", until it encounters an item that cannot fit.  The bound is then derived by inserting a fraction of this last item so as to exactly fill the knapsack capacity.  This calculation is equivalent to the linear programming relaxation of the knapsack problem.


### The `getSolution!` Method
The `getSolution!` method is called immediately after the `computeBound!` method for nodes that cannot be pruned from the search based on their bounds.  It takes three arguments: the node, the problem, and the current incumbent solution.  If the process of computing the bound yields a solution better than the current incumbent, `getSolution!` could modify the current incumbent to reflect this improved solution.  It should return `nothing`.

In the simple knapsack case, the declaration of the function is 

	getSolution!(node::SimpleKnapsackNode,
                 solution::SimpleKnapsackSolution,
                 problem::SimpleKnapsackProblem)::Nothing

In `SimpleKnapsack.jl`, the `getSolution!` method uses a simple heuristic: continuing to scan in the usual value-to-weight ratio order, it inserts each item that will fit.

 ### The `terminal` method
 
The `terminal` method tells the branch-and-bound searcher whether the subproblem bound calculated by `computeBound!` is exact.  If so, the subproblem need not be subdivided and is a leaf of the search tree.  It takes two arguments, the current subproblem and the current problem, and should return `true` if the bound just computed for the subproblem is exact and the solution retrieved by `getSolution!` is optimal for the subproblem's region of the search space.  Otherwise, it should return `false`.  In the simple knapsack example, the function declaration is 

	function terminal(node::SimpleKnapsackNode,
                      problem::SimpleKnapsackProblem)::Bool

In the simple knapsack case, a subproblem is terminal if the bounding procedure managed to exactly fill the knapsack without subdividing the last item inserted, or if all the knapsack items were either "locked in", "locked out", or scanned by the bounding procedure.


### The `separate!` Method

For subproblem that are neither pruned after bounding nor terminal, the `separate!` method is called after `terminal`.  It should perform any calculations needed to subdivide the search node, and return the `Int32` number of child nodes to be generated.  It takes two arguments, the current subproblem and the current problem instance.

For the simple knapsack example, the declaration of the function is 

	function separate!(node::SimpleKnapsackNode,
                       problem::SimpleKnapsackProblem)::Int32

In the simple knapsack case, two children are created when subdividing a search node, one that "locks in" the item that was partially included when computing the bound, called the "splitting item", and another that "locks it out".  In the example implementation, all the information needed for this subdivision has already been cached, so the method simply returns the integer `2`.  In more complicated applications, some more involved calculation, such as the evaluation of possible branching variables, would be appropriate.

### The `makeChild` Method
After `separate!` is called on a subproblem, the search procedure calls `makeChild` for each child.  This method takes three arguments:

1.  The current subproblem.
2.  An `Int32` specifying which child is desired.  This argument will be between `1` and the value returned by `separate!`, inclusive.
3.  The current problem instance.

The `makeChild` method should return a subproblem object, and the bound of this object should typically be equal to the parent's bound (although in some cases it may be possible to deduce a tighter bound without fully bounding the subproblem).  In the simple knapsack case, the declaration of this function is

	function makeChild(node::SimpleKnapsackNode,
                       whichChild::Int64,
                       problem::SimpleKnapsackProblem)::SimpleKnapsackNode

In the example, child `1` has the splitting item "locked in", and child `2` has the splitting item "locked out".


### Other Example Methods

The `SimpleKnapsack.jl` file contains several additional methods beyond those described above.  These are not directly called by `BranchAndBound.jl` and therefore not required in general, but similar methods might be useful in other applications.

* The `setup!` method provides some initial preprocessing of the a knapsack problem instance, including sorting the items by value-to-weight ratio.
* The `completeGreedy!` method provides some logic that is common the to the `initialGuess` and `getSolution!` methods.
* The `translateSolution` method creates a printable representation of a solution, translating between sorted and original item indexes, and providing item names.
* The `SimpleKnapsackRead` method creates a `SimpleKnapsackProblem` instance by reading a data file.


### The Sample "Driver" Program

The Julia program `SimpleKnapsackDriver.jl` provides an example of a main program applying `BranchAndBound.jl` to a class of application problems:  

1.  It reads a file name from the command line.
2.  It runs `setup!` to preprocess the resulting `SimpleKnapsackProblem` instance.
3.  It sets a search status printout frequency of one one line per 1000 bounded nodes (to suppress status printing, set the `param.printFreq` field to zero).
4.  It runs `search` to find the optimal solution to the problem.
5.  It prints the resulting solution and time taken to compute it.

Problem instances of varying levels of difficulty may be found in the `knapsack-problems` subdirectory.  To solve one of the moderately difficult instances, one issues the Linux command

	julia simpleKnapsackDriver.jl knapsack-problems/test-data.1000.1

or the Windows command

	julia .\simpleKnapsackDriver.jl .\knapsack-problems\test-data.1000.1

