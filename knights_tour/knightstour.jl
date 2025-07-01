using JuMP
import HiGHS

#Initializing model
model = JuMP.Model(HiGHS.Optimizer)

n = 64

@variable(model, z[i in 1:n, j in 1:n], Bin)
#=z[i, j] = 1 implies knight travels from square i -> square j
n = 1 is A1, n = 2 is A2,...,n = 9 is B1, and so on until n = 64 which is H8
https://en.wikipedia.org/wiki/Algebraic_notation_(chess)=#

#=We will create a matrix legal such that legal[i, j] = 1
iff a knight can legally move from square i to square j=#
legal = zeros(Int, n, n)

for i in 1:n
    xi, yi = divrem(i - 1, 8)
    #This is so that i = 1-8 (A) -> xi = 0, i = 9-16 (B) -> xi = 1 and so on

    #Increment to normalize coordinates to A-H (1-8), 1-8 system
    xi += 1
    yi += 1


    for j in 1:n
        
        #Same principle as above
        xj, yj = divrem(j - 1, 8)
        xj += 1
        yj += 1
        
        #Knight moves in 'L' shape, i.e. Δx = 2 && Δy = 1 || Δx = 1 && Δy = 2
        dx = abs(xi - xj)
        dy = abs(yi - yj)
        if (dx == 2 && dy == 1) || (dx == 1 && dy == 2)
            legal[i, j] = 1
        end
    end
end

#Every square needs an incoming edge
@constraint(model, one_incoming_edge[j in 1:n], sum(z[i, j] for i in 1:n if i != j) == 1)

#=Every square needs outgoing edge
(last square visited can be assumed to loop back to first square)=#
@constraint(model, one_outgoing_edge[i in 1:n], sum(z[i, j] for j in 1:n if i != j) == 1)

#Ensuring that all edges declared in decision matrix z are legal for a knight in chess
@constraint(model, [i=1:n, j=1:n], z[i, j] <= legal[i, j])

#Miller-Tucker-Zemlin Subtour Elimination Constraint
@variable(model, 1 <= place[1:n] <= n)
@constraint(model, mtz[i in 1:n, j in 1:n; i != j && j != 1], n * (1 - z[i, j]) + place[i] >= place[j] + 1)

#=As this is a feasibility problem and not an optimization problem,
an objective function is not required=#
optimize!(model)

#Function to convert Int index of a given square to its name in algebraic notation
#eg. index2chess(49) returns "G1"
function index2chess(n::Int)
    alphas = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H']
    x, y = divrem(n - 1, 8)
    return "$(alphas[x + 1])$(y+1)"
end

function find(i::Int64, z)
    for j in [1:(i-1); (i+1):n]
        if value(z[i, j]) ≈ 1
            return j
        end
    end
end

function extractOrder(z)
    #We want to start in g1 which corresponds to index 49
    arr = [49]
    i = 49
    while true
        k = find(i, z)
        push!(arr, k)
        i = k

        if i == 49
            break
        end
    end

    return arr[1:64]
end

order = extractOrder(z)
natural_order = [index2chess(i) for i in order]

using Plots

# Prepare chessboard grid
board = zeros(Int, 8, 8)
for idx in 1:64
    x, y = divrem(order[idx] - 1, 8)
    board[x + 1, y + 1] = idx
end

# Plotting
heatmap(
    1:8, 1:8, board',
    c=:blues, aspect_ratio=1, legend=false,
    xticks=(1:8, ['A','B','C','D','E','F','G','H']),
    yticks=(1:8, 1:8),
    xlabel="File", ylabel="Rank",
    title="Knight's Tour"
)

# Draw the path
x_coords = Int[]
y_coords = Int[]
for idx in order
    x, y = divrem(idx - 1, 8)
    push!(x_coords, x + 1)
    push!(y_coords, y + 1)
end

scatter!([x_coords[1]], [y_coords[1]], c=:green, marker=:circle, ms=8, label="Start")
scatter!([x_coords[end]], [y_coords[end]], c=:green, marker=:circle, ms=8, label="End")
plot!(x_coords, y_coords, lw=2, c=:red, marker=:circle, ms=4)

