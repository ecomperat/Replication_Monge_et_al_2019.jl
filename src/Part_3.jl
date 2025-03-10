# This file is dedicated to replicate the results of the part 3 of the article.

# It contains : 
# Figure 4 
# Table 3 
# Table 4
# Table 5

using DataFrames
using DataFramesMeta
using StatFiles
using Statistics
using CSV
using Plots
using PrettyTables
using Weave

# We are going to use the array benchmark_76 of the common file.
include("country_samples.jl")

### Figure 4 

# First, I merge the pwt data with the author's calculated NRR shares.

df_phi = DataFrame(load("src/data/MSS_NRshares.dta"))
df_pwt = DataFrame(load("output/pwt_data_0.csv"))

# Selecting the total phiNR variable:

df_phi_NR = select(df_phi, :country, :year, :phi_NR)

# Merging this onto pwt:

data_fig4 = leftjoin(df_pwt, df_phi_NR, on=[:country, :year])

# Next I restrict to the sample size in the figure.
# I also assume that we are looking at the previous sample of countires, though
# this is not explicitly mentioned in the paper.

data_fig4 = filter(row -> row.country in benchmark_76 && (1970 <= row.year <= 2005), data_fig4)

CSV.write("output/data_fig4.csv", data_fig4)

# Testing that we obtain the correct number of years and countries:

num_countries = length(unique(data_fig4.country))
unique_years = length(unique(data_fig4.year))

if num_countries !== 76
    @error("The expected number of unique countries is 76.")
end
if  unique_years !== 36
    @error("Expected unique years (order matters) is wrong.")
end

# Next, we compute QMKP and VMPK as described in sections II and III of the paper:

data_fig4.QMPK = (1 .- data_fig4.labsh .- data_fig4.phi_NR) .* (data_fig4.rgdpo ./ data_fig4.ck)
data_fig4.VMPK = data_fig4.QMPK .* (data_fig4.pl_gdpo ./ data_fig4.pl_k)

# We briefly test that the comuputed MPK variables are indeed present in the dataset:

columns_to_check = ["QMPK", "VMPK"]
for col in columns_to_check
    if col ∉ names(data_fig4)
        @error("Column $col is missing in data_fig4.")
    end
end

# We can now proceed to plotting.

# First, we need to calculate the percentiles and ranges as displayed in Figure 4:


function summarize(df, column)
    grouped = groupby(df, :year)
    years = unique(df.year)
    
    # Initialize vectors to store the results
    medians = Float64[]
    iqr_25 = Float64[]
    iqr_75 = Float64[]
    pct_10 = Float64[]
    pct_90 = Float64[]
    pct_5 = Float64[]
    pct_95 = Float64[]

    # Looping
    for group in grouped
        data = group[!, column]  # Extract the relevant column
        
        push!(medians, median(data))
        push!(iqr_25, quantile(data, 0.25))
        push!(iqr_75, quantile(data, 0.75))
        push!(pct_10, quantile(data, 0.1))
        push!(pct_90, quantile(data, 0.9))
        push!(pct_5, quantile(data, 0.05))
        push!(pct_95, quantile(data, 0.95))
    end

    # Create the resulting DataFrame
    return DataFrame(
        Year = years,
        Median = medians,
        IQR_25 = iqr_25,
        IQR_75 = iqr_75,
        Percentile_10 = pct_10,
        Percentile_90 = pct_90,
        Percentile_5 = pct_5,
        Percentile_95 = pct_95
    )
end

# Summarize QMPK and VMPK
qmpk_summary = summarize(data_fig4, :QMPK)
vmpk_summary = summarize(data_fig4, :VMPK)

# Finally, we can proceed to plotting:

function plot_fig4(data, variable, title, ylabel; ylim_range=(0, 0.5), background_color=:white)
    # Define shading levels like in the paper
    shading_levels = [
        (:IQR_25, :IQR_75, :darkblue, 0.5),
        (:Percentile_10, :Percentile_90, :blue, 0.3),
        (:Percentile_5, :Percentile_95, :lightblue, 0.2)
    ]

    # Plot the largest percentile range as the base
    plot_obj = plot(
        data.Year, data[!, :Percentile_5],
        ribbon=(data[!, :Percentile_95] .- data[!, :Percentile_5]),
        label="", lw=0, color=:lightblue, alpha=0.5,
        title=title, xlabel="Year", ylabel=ylabel,
        ylim=ylim_range, background_color=background_color
    )

    # Add the remaining layers
    for (lower, upper, color, alpha) in shading_levels[1:2]
        plot!(
            plot_obj,
            data.Year, data[!, lower],
            ribbon=(data[!, upper] .- data[!, lower]),
            label="", lw=0, color=color, alpha=alpha
        )
    end

    # Add the median line
    plot!(
        plot_obj,
        data.Year, data[!, :Median],
        label="", color=:white, lw=2
    )

    # Return the plot object
    return plot_obj
end


plot_qmpk = plot_fig4(qmpk_summary, :QMPK, "Panel A. QMPK", "Quantity MPK", ylim_range=(0, 0.5),background_color=:white)
plot_vmpk = plot_fig4(vmpk_summary, :VMPK, "Panel B. VMPK", "Value MPK", ylim_range=(0, 0.5),background_color=:white)

# display(plot_qmpk)
# display(plot_vmpk)

"""
The function `create_figure_4()` creates a `png` containing the replication result of the Figure 4.

The `png` file is created within an `output` folder.
"""
function create_figure_4()
    fig4_repl = plot(plot_qmpk,
                        plot_vmpk,
                        layout=(1, 2),
                        size=(1000, 450),
                        subtitle="Figure 4: Global Evolution of MPKs") # Plot is cut off ? fix later
    savefig(fig4_repl, "output/figure_4.png")
end
"""
The function `delete_figure_4()` deletes the `png` file containing
the replication result of Figure 4, if the present working directory has a folder `output` containing it.
"""
function delete_figure_4()
    rm("output/figure_4.png")
end


### Table 3 :

# Computing logs
data_fig4[:, :log_QMPK] = log.(data_fig4.QMPK)
data_fig4[:, :log_VMPK] = log.(data_fig4.VMPK)
data_fig4[:, :log_phi] = log.(1 .- data_fig4.labsh .- data_fig4.phi_NR)
data_fig4[:, :log_Y_div_K] = log.(data_fig4.rgdpo ./ data_fig4.ck)
data_fig4[:, :log_PY_div_PK] = log.(data_fig4.pl_gdpo ./ data_fig4.pl_k)

grouped = groupby(data_fig4, :year)

covariances = DataFrame(year=unique(data_fig4.year))

# List of covariance pairs
cov_pairs = [
    (:log_phi, :log_Y_div_K, :Cov_phi_Y_div_K),
    (:log_Y_div_K, :log_PY_div_PK, :Cov_Y_div_K_PY_div_PK),
    (:log_phi, :log_PY_div_PK, :Cov_phi_PY_div_PK),
    (:log_QMPK, :log_PY_div_PK, :Cov_QMPK_PY_div_PK)
]

# Computing variances
variances = combine(grouped, 
    :log_QMPK => var => :Var_QMPK,
    :log_VMPK => var => :Var_VMPK,
    :log_phi => var => :Var_phi,
    :log_Y_div_K => var => :Var_Y_div_K,
    :log_PY_div_PK => var => :Var_PY_div_PK
)

# Computing covariances

for (var1, var2, name) in cov_pairs
    values = Float64[]
    for group in grouped
        x = group[!, var1]
        y = group[!, var2]
        push!(values, cov(x, y))
    end
    covariances[:, name] = values
end

# Merge variances and covariances
data_tab3 = leftjoin(variances, covariances, on=:year)

# I check whether our computed results match the manual computation using the variance formulae provided
# in the paper. This is to test that there are no larger computational discrepancies or errors in our data.

manual_varQMPK = var(data_fig4[!, :log_phi]) +
                 var(data_fig4[!, :log_Y_div_K]) +
                 2 * cov(data_fig4[!, :log_phi], data_fig4[!, :log_Y_div_K])

manual_varVMPK = var(data_fig4[!, :log_QMPK]) +
                 var(data_fig4[!, :log_PY_div_PK]) + 
                 2 * cov(data_fig4[!, :log_QMPK], data_fig4[!, :log_PY_div_PK]) 

computed_varQMPK = var(data_fig4[!, :log_QMPK])
computed_varVMPK = var(data_fig4[!, :log_VMPK])

if false == isapprox(computed_varQMPK, manual_varQMPK)
    println("Error: VarQMPK does not match the manual computation.")
    println("Computed VarQMPK: $computed_varQMPK")
    println("Manual VarQMPK: $manual_varQMPK")
end

if false == isapprox(computed_varVMPK, manual_varVMPK)
    println("Error: VarVMPK does not match the manual computation.")
    println("Computed VarVMPK: $computed_varVMPK")
    println("Manual VarVMPK: $manual_varVMPK")
end

# Back to building Table 3.
# Restricting attention to decades like in the paper:

years_of_interest = [1970, 1980, 1990, 2000]
data_tab3 = filter(row -> row.year in years_of_interest, data_tab3)

CSV.write("output/table3_repl.csv", data_tab3)

# Function to create and save the HTML table

#function create_table_3(tab3_csv_path::String, tab3_html_path::String)
#
#    data = CSV.read(tab3_csv_path, DataFrame)
#    html_table = pretty_table(data; backend = Val(:html), standalone = true)
#    
#    # Save the HTML table to a file
#    open(tab3_html_path, "w") do file
#        write(file, html_table)
#    end
#
#    println("HTML table saved to $output_html_path")
#end

#tab3_csv = "output/table3_repl.csv"  
#tab3_html = "output/table3_repl.html"  
#create_table_3(tab3_csv, tab3_html)

# Rounding : 
rounded_data_tab_3 = round.(data_tab3, digits=3)

# Changing the names so that it is smaller : 

# names(rounded_data_tab_3)[1] 
# names(rounded_data_tab_3)[2] 
# names(rounded_data_tab_3)[3] 
# names(rounded_data_tab_3)[4] 
# names(rounded_data_tab_3)[5] 
# names(rounded_data_tab_3)[6] 
# 
# names(rounded_data_tab_3)[7]
# names(rounded_data_tab_3)[8]
# names(rounded_data_tab_3)[9] 
# names(rounded_data_tab_3)[10]
# Doing it in one command : 
rename!(rounded_data_tab_3, Dict(
    :year => "Year",
    :Var_QMPK => "Var_1",
    :Var_VMPK => "Var_2",
    :Var_phi => "Var_3",
    :Var_Y_div_K => "Var_4",
    :Var_PY_div_PK => "Var_5",
    :Cov_phi_Y_div_K => "Cov_1",
    :Cov_Y_div_K_PY_div_PK => "Cov_2",
    :Cov_phi_PY_div_PK => "Cov_3",
    :Cov_QMPK_PY_div_PK => "Cov_4"
))

# rounded_data_tab_3

# Display the result
# println(latex_output)
# Can we find a way to export this into the output folder?
# Yes :

"""
The function `create_table_3()` creates a `pdf` containing the replication result of the Figure 3.

The `pdf` file is created within an `output` folder.

"""
function create_table_3()

    write("output/table_3.jmd", """
---
title: "Table 3"
author: CHAMBON L., COMPERAT E., GUGELMO CAVALHEIRO DIAS P.
date: 2024-01-06
output: pdf_document
---
This file presents the table 3 obtained from our replication attempt.

We changed he names of the columns for presentation convenience.

```{julia}
using PrettyTables
using Replication_Monge_et_al_2019
using Markdown
using Latexify
```

```{julia}
Replication_Monge_et_al_2019.rounded_data_tab_3
```

""")

    weave("output/table_3.jmd"; doctype = "md2pdf", out_path = "output")    
end


"""
The function `delete_table_3()` deletes the `pdf` file and oher building blocks containing
the replication result of Table 3, if the present working directory has a folder `output` containing it.
"""
function delete_table_3()
    rm("output/table_3.aux")
    rm("output/table_3.jmd")
    rm("output/table_3.log")
    rm("output/table_3.out")
    rm("output/table_3.pdf")
    rm("output/table_3.tex")
end

### Table 4 & 5

# Now, we move on to the final tables of this section. To do so, we need data on the Sachs & Warner indicator as cited in the 
# paper. However, this is not available in the replication package, so I use a .csv file from: https://www.bristol.ac.uk/depts/Economics/Growth/sachs.htm

sw_indicator = CSV.read("src/data/open.csv", DataFrame)

# Standardizing variable names:
 
rename!(sw_indicator, Dict(:OPEN => :open))
rename!(sw_indicator, Dict(:YEAR => :year))
rename!(sw_indicator, Dict(:COUNTRY => :country))
sw_indicator.country = lowercase.(sw_indicator.country)
data_fig4.country = lowercase.(data_fig4.country)  

# Performing the join as before: 

df_open = select(sw_indicator, :country, :year, :open)
data_tab4and5 = leftjoin(data_fig4, df_open, on=[:country, :year])

# Finally:

CSV.write("output/data_tab4and5.csv", data_tab4and5)

# Checking:

num_countries_bis = length(unique(data_tab4and5.country))
unique_years_bis = length(unique(data_tab4and5.year))

if num_countries_bis !== 76
    @error("The expected number of unique countries is 76.")
end
if  unique_years_bis !== 36
    @error("Expected unique years (order matters) is wrong.")
end

# Now, we can build Tables 4 and 5. I cannot be sure whether the indicator data I added is identical to the data used by
# the authors, but I first proceed by filtering mising values and coding the open variable as a binary one:

data_tab4and5 = filter(row -> !ismissing(row.open) && row.open in [0.00, 1.00], data_tab4and5)


data_tab4and5.open .= Int.(data_tab4and5.open .== 1.0)

# Next, computing relevant output:

# First, creating bins like in the paper

function create_year_bins(year)
    if year >= 1970 && year <= 1975
        return "1970–1975"
    elseif year >= 1976 && year <= 1980
        return "1976–1980"
    elseif year >= 1981 && year <= 1985
        return "1981–1985"
    elseif year >= 1986 && year <= 1990
        return "1986–1990"
    elseif year >= 1991 && year <= 1995
        return "1991–1995"
    elseif year >= 1996 && year <= 2000
        return "1996–2000"
    else
        return "Outside Range"
    end
end

data_tab4and5.year_bin = map(create_year_bins, data_tab4and5.year)

# Grouped by SW indicator

grouped_tab4 = groupby(data_tab4and5, [:year_bin, :open]) 

stats_tab4 = combine(grouped_tab4, 
    :QMPK => mean => :QMPK_mean,
    :VMPK => mean => :VMPK_mean,
    :QMPK => std => :QMPK_std,
    :VMPK => std => :VMPK_std,
    :QMPK => length => :count
)

stats_tab4_open = filter(row -> row.open == 1, stats_tab4)
stats_tab4_closed = filter(row -> row.open == 0, stats_tab4)

tab4 = innerjoin(stats_tab4_open, stats_tab4_closed, on=:year_bin, makeunique=true)

# Writing a function to compute t-stats:

function compute_t_stat(mean1, mean2, n1, n2, std1, std2)
    return (mean1 - mean2) / sqrt((std1^2 / n1) + (std2^2 / n2))
end

tab4.QMPK_t_stat = map(row -> compute_t_stat(
    row.QMPK_mean, row.QMPK_mean_1,
    row.count, row.count_1,
    row.QMPK_std, row.QMPK_std_1
), eachrow(tab4))

tab4.VMPK_t_stat = map(row -> compute_t_stat(
    row.VMPK_mean, row.VMPK_mean_1,
    row.count, row.count_1,
    row.VMPK_std, row.VMPK_std_1
), eachrow(tab4))

select!(tab4, Not([:open, :open_1, :QMPK_std, :QMPK_std_1, :VMPK_std, :VMPK_std_1]))

# Renaming columns for clarity:

rename!(tab4, Dict(
    :QMPK_mean => :QMPK_open,
    :VMPK_mean => :VMPK_open,
    :count => :Obervations_open,
    :QMPK_mean_1 => :QMPK_closed,
    :VMPK_mean_1 => :VMPK_closed,
    :count_1 => :Observations_closed
))

# Reordering columns like in the paper:

desired_order = [:QMPK_open, :QMPK_closed, :QMPK_t_stat, :VMPK_open, :VMPK_closed, :VMPK_t_stat, :Obervations_open, :Observations_closed]

# Reorder columns
tab4_repl = select(tab4, desired_order...)

# println(tab4_repl)
CSV.write("output/table4_repl.csv", tab4_repl)

# Here, we should have : 
rounded_data_tab_4 = round.(tab4_repl, digits=3)
names(rounded_data_tab_4)

rename!(rounded_data_tab_4, Dict(
    :QMPK_open => "QMPK_1",
    :QMPK_closed => "QMPK_2",
    :QMPK_t_stat => "QMPK_3",
    :VMPK_open => "VMPK_1",
    :VMPK_closed => "VMPK_2",
    :VMPK_t_stat => "VMPK_3",
    :Obervations_open => "Obs_1",
    :Observations_closed => "Obs_2"
))

"""
The function `create_table_4()` creates a `pdf` containing the replication result of the Figure 3.

The `pdf` file is created within an `output` folder.

"""
function create_table_4()
    write("output/table_4.jmd", """
---
title: "Table 4"
author: CHAMBON L., COMPERAT E., GUGELMO CAVALHEIRO DIAS P.
date: 2024-01-06
output: pdf_document
---
This file presents the table 4 obtained from our replication attempt.

We changed he names of the columns for presentation convenience.

```{julia}
using PrettyTables
using Replication_Monge_et_al_2019
using Markdown
using Latexify
```

```{julia}
Replication_Monge_et_al_2019.rounded_data_tab_4
```

""")
    weave("output/table_4.jmd"; doctype = "md2pdf", out_path = "output")
end


"""
The function `delete_table_4()` deletes the `pdf` file and oher building blocks containing
the replication result of Table 4, if the present working directory has a folder `output` containing it.
"""
function delete_table_4()
    rm("output/table_4.aux")
    rm("output/table_4.jmd")
    rm("output/table_4.log")
    rm("output/table_4.out")
    rm("output/table_4.pdf")
    rm("output/table_4.tex")
end


# For the last table of Section III, we repeat the exercise for factor shares, output-to-capital ratios, and relative prices:

# First, adding variables of interest:

data_tab5 = copy(data_tab4and5)
data_tab5[:, :phi] = 1 .- data_tab5.labsh .- data_tab5.phi_NR  
data_tab5[:, :Y_div_K] = data_tab5.rgdpo ./ data_tab5.ck       
data_tab5[:, :P_Y_div_P_K] = data_tab5.pl_gdpo ./ data_tab5.pl_k  

grouped_tab5 = groupby(data_tab5, [:year_bin, :open])

stats_tab5 = combine(grouped_tab5,
    :phi => mean => :phi_mean,
    :phi => std => :phi_std,
    :Y_div_K => mean => :Y_div_K_mean,
    :Y_div_K => std => :Y_div_K_std,
    :P_Y_div_P_K => mean => :P_Y_div_P_K_mean,
    :P_Y_div_P_K => std => :P_Y_div_P_K_std,
    :phi => length => :count
)


stats_tab5_open = filter(row -> row.open == 1, stats_tab5)
stats_tab5_closed = filter(row -> row.open == 0, stats_tab5)

tab5 = innerjoin(stats_tab5_open, stats_tab5_closed, on=[:year_bin], makeunique=true)

# Next, adding t-stats:

tab5.phi_t_stat = map(row -> compute_t_stat(
    row.phi_mean, row.phi_mean_1,
    row.count, row.count_1,
    row.phi_std, row.phi_std_1
), eachrow(tab5))

tab5.Y_div_K_t_stat = map(row -> compute_t_stat(
    row.Y_div_K_mean, row.Y_div_K_mean_1,
    row.count, row.count_1,
    row.Y_div_K_std, row.Y_div_K_std_1
), eachrow(tab5))

tab5.P_Y_div_P_K_t_stat = map(row -> compute_t_stat(
    row.P_Y_div_P_K_mean, row.P_Y_div_P_K_mean_1,
    row.count, row.count_1,
    row.P_Y_div_P_K_std, row.P_Y_div_P_K_std_1
), eachrow(tab5))

# Finally, puttting everything together:

tab5_repl = DataFrame(
    Year = tab5.year_bin,
    phi_Open = tab5.phi_mean,
    phi_Closed = tab5.phi_mean_1,
    phi_t_stat = tab5.phi_t_stat,
    Y_div_K_Open = tab5.Y_div_K_mean,
    Y_div_K_Closed = tab5.Y_div_K_mean_1,
    Y_div_K_t_stat = tab5.Y_div_K_t_stat,
    P_Y_div_P_K_Open = tab5.P_Y_div_P_K_mean,
    P_Y_div_P_K_Closed = tab5.P_Y_div_P_K_mean_1,
    P_Y_div_P_K_t_stat = tab5.P_Y_div_P_K_t_stat
)

rename!(tab5_repl, Dict(
    :phi_Open => "φ (Open)", :phi_Closed => "φ (Closed)", :phi_t_stat => "φ t-stat",
    :Y_div_K_Open => "Y/K (Open)", :Y_div_K_Closed => "Y/K (Closed)", :Y_div_K_t_stat => "Y/K t-stat",
    :P_Y_div_P_K_Open => "P_Y/P_K (Open)", :P_Y_div_P_K_Closed => "P_Y/P_K (Closed)", :P_Y_div_P_K_t_stat => "P_Y/P_K t-stat"
))

println(tab5_repl)
CSV.write("output/table5_repl.csv", tab5_repl)

# Rounding : 
rounded_data_5 = copy(tab5_repl)
rounded_data_5[:,2:end] = round.(tab5_repl[:,2:end], digits = 3)
rounded_data_5

# Shortening names : 
names(rounded_data_5)
rename!(rounded_data_5, Dict(
    :"φ (Open)" => "phi 1", :"φ (Closed)" => "phi 2", :"φ t-stat" => "phi 3",
    :"Y/K (Open)" => "Y/K 1", :"Y/K (Closed)" => "Y/K 2", :"Y/K t-stat" => "Y/K 3",
    :"P_Y/P_K (Open)" => "Py/Pk 1", :"P_Y/P_K (Closed)" => "Py/Pk 2", :"P_Y/P_K t-stat" => "Py/Pk 3"
))

"""
The function `create_table_5()` creates a `pdf` containing the replication result of the Figure 5.

The `pdf` file is created within an `output` folder.

"""
function create_table_5()
    write("output/table_5.jmd", """
---
title: "Table 5"
author: CHAMBON L., COMPERAT E., GUGELMO CAVALHEIRO DIAS P.
date: 2024-01-06
output: pdf_document
---
This file presents the table 5 obtained from our replication attempt.

We changed he names of the columns for presentation convenience.

```{julia}
using PrettyTables
using Replication_Monge_et_al_2019
using Markdown
using Latexify
```

```{julia}
Replication_Monge_et_al_2019.rounded_data_
```

""")
    weave("output/table_5.jmd"; doctype = "md2pdf", out_path = "output")
end

"""
The function `delete_table_5()` deletes the `pdf` file and oher building blocks containing
the replication result of Table 5, if the present working directory has a folder `output` containing it.
"""
function delete_table_5()
    rm("output/table_5.aux")
    rm("output/table_5.jmd")
    rm("output/table_5.log")
    rm("output/table_5.out")
    rm("output/table_5.pdf")
    rm("output/table_5.tex")
end
