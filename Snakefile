# Main Workflow - MRW Replication
# Contributors: @lachlandeer, @julianlanger, @bergmul

# --- Importing Configuration Files --- #
configfile: "paths.yaml"

# --- Dictionaries --- #
# Identify subset conditions for data
DATA_SUBSET = glob_wildcards(config["src_data_specs"] + "{fname}.json").fname
# Models we want to estimate
MODELS = glob_wildcards(config["src_model_specs"] + "{fname}.json").fname
# tables to generate
TABLES = glob_wildcards(config["src_table_specs"] + "{fname}.json").fname

# --- Main Build Rule --- #
## all            : build paper and slides that are the core of the project
rule all:
    input:
        table = config["out_tables"] + "table_01.tex"


# --- Build Rules --- #
# table: build one table
rule table:
    input:
        script = config["src_tables"] + "regression_table.R",
        spec   = config["src_table_specs"] + "table_01.json",
        models = expand(config["out_analysis"] +
                        "{iModel}.{iSubset}.rds",
                        iModel = MODELS,
                        iSubset = DATA_SUBSET),
    output:
        table = config["out_tables"] + "table_01.tex"
    shell:
        "Rscript {input.script} \
            --spec {input.spec} \
            --out {output.table}"       

## estimate_models  : Helper rule that runs all regression models by expanding wildcards
rule estimate_models:
    input:
        expand(config["out_analysis"] +
                            "{iModel}.{iSubset}.rds",
                            iModel = MODELS,
                            iSubset = DATA_SUBSET)

## models        : Estimate an regression model on MRW data      
rule models:
    input:
        script = config["src_analysis"] + "estimate_ols_model.R",
        data   = config["out_data"] + "mrw_complete.csv",
        model  = config["src_model_specs"] + "{iModel}.json",
        subset = config["src_data_specs"] + "{iSubset}.json"
    output:
        model_est = config["out_analysis"] + "{iModel}.{iSubset}.rds"
    shell:
        "Rscript {input.script} --data {input.data} --model {input.model} \
            --subset {input.subset} --out {output.model_est}"


## gen_regression_vars: creates the set of variables needed to produce MRW results
rule gen_regression_vars:
    input:
        script = config["src_data_mgt"] + "gen_reg_vars.R",
        data   = config["out_data"] + "mrw_renamed.csv"
    output:
        data = config["out_data"] + "mrw_complete.csv",
    params:
        solow_const = 0.05
    shell:
        "Rscript {input.script} --data {input.data} --param {params.solow_const} \
            --out {output.data}"

## rename_vars     : gives meaningful names to variables 
rule rename_vars:
    input:
        script = config["src_data_mgt"] + "rename_variables.R",
        data   = config["src_data"] + "mrw.dta",
    output:
        data = config["out_data"] + "mrw_renamed.csv",
    log:
        config["log"] + "data_cleaning/rename_variables.txt"
    shell:
        "Rscript {input.script} --data {input.data} --out {output.data}"

## dag                : create the DAG as a pdf from the Snakefile
rule dag:
    input:
        "Snakefile"
    output:
        "dag.pdf"
    shell:
        "snakemake --dag | dot -Tpdf > {output}"

## filegraph          : create the file graph as pdf from the Snakefile 
##                     (i.e what files are used and produced per rule)
rule filegraph:
    input:
        "Snakefile"
    output:
        "filegraph.pdf"
    shell:
        "snakemake --filegraph | dot -Tpdf > {output}"

## rulegraph          : create the graph of how rules piece together 
rule rulegraph:
    input:
        "Snakefile"
    output:
        "rulegraph.pdf"
    shell:
        "snakemake --rulegraph | dot -Tpdf > {output}"