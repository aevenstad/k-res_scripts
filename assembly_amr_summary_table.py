import os
import pandas as pd
import glob
from typing import List


def concat_non_empty(dfs: List[pd.DataFrame]) -> pd.DataFrame:
    """
    Concatenate only non-empty DataFrames from a list.
    Skips None and DataFrames with 0 rows.
    """
    non_empty_dfs = [df for df in dfs if df is not None and not df.empty]
    return pd.concat(non_empty_dfs, ignore_index=True, sort=False) if non_empty_dfs else pd.DataFrame()



hybracter_dfs=[]
for file in glob.glob("*/hybracter/FINAL_OUTPUT/complete/*_per_contig_stats.tsv"):
    df = pd.read_csv(file, sep='\t')
    df['Sample'] = os.path.basename(file).rsplit("_")[0]
    df['Sample'] = df['Sample'].astype(str)
    hybracter_dfs.append(df)


plassembler_dfs=[]
for file in glob.glob("*/hybracter/supplementary_results/plassembler_all_assembly_summary/plassembler_assembly_info.tsv"):
    df = pd.read_csv(file, sep='\t')
    df = df[df['contig'] != 'chromosome']
    df['contig'] = 'plasmid0000' + df['contig'].astype(str)
    df = df.iloc[:, 0:15]
    df['Sample'] = df['Sample'].astype(str)
    plassembler_dfs.append(df)


plasmidfinder_dfs=[]
for file in glob.glob("*/plasmidfinder/*.tsv"):
    df = pd.read_csv(file, sep='\t')
    df['Sample'] = os.path.basename(file).rsplit("_")[0]
    df = df[['Plasmid', 'Identity', 'Query / Template length', 'Contig', 'Sample']]
    df['Contig'] = df['Contig'].astype(str).str.split().str[0]
    plasmidfinder_dfs.append(df)



hybracter_combined = concat_non_empty(hybracter_dfs)
plassembler_combined = concat_non_empty(plassembler_dfs)
plasmidfinder_combined = concat_non_empty(plasmidfinder_dfs)

print(hybracter_combined.head())

results = pd.merge(
    plassembler_combined,
    plasmidfinder_combined,
    how='inner',
    left_on=['Sample', 'contig'],
    right_on=['Sample', 'Contig']
)

#print(results.head())
