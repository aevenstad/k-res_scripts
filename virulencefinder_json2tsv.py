import json
import csv
import sys

input_json = sys.argv[1]
output_tsv = sys.argv[2]

fields_to_extract = ["contig_name",
                    "positions_in_contig",
                    "virulence_gene",
                    "protein_function",
                    "identity",
                    "coverage",
                    "HSP_length",
                    "template_length",
                    "position_in_ref"]

# Extract hits from JSON structure
def find_hits(obj):
    hits = []
    if isinstance(obj, dict):
        if all(field in obj for field in fields_to_extract):
            hits.append(obj)
        else:
            for v in obj.values():
                hits.extend(find_hits(v))
    return hits

# Load JSON and search for hits
with open(input_json, "r") as f:
    full_json = json.load(f)

hits = find_hits(full_json)

# Write results to table
with open(output_tsv, "w", newline="") as tsvfile:
    writer = csv.writer(tsvfile, delimiter="\t")
    writer.writerow(fields_to_extract)  # header
    for hit in hits:
        row = [hit.get(field, "") for field in fields_to_extract]
        writer.writerow(row)

print(f"Found {len(hits)} hits. Saved to {output_tsv}")
