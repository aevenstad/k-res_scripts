#!/bin/bash
# Wrapper script to run Clinker
# USAGE: clinker.sh <gff3> -p <out.html> -i <identity>
# Clinker version: 0.0.31

# Container directory
container_dir="/bigdata/Jessin/Softwares/containers"
clinker="clinker_v0.0.31.sif"


Help() {
    echo "Usage: $0 [options] test.gff3 test_2.gff3 ..."
    echo "Options:"
    echo "  -h                Show this help message"
    echo "  -p <out.html>     Specify output HTML file"
    echo "  -i <identity>     Set identity threshold (default: 0.90)"
}

if [[ " $@ " =~ " -h " ]]; then
    Help
    exit 0
fi

while getopts ":h:p:i:" option; do
    case $option in
        h)
            Help
            exit 0
            ;;
        p)  
            output_file="$OPTARG"
            ;;
        i)  
            identity="$OPTARG"  
            ;;
        \?) 
            echo "Invalid option: -$OPTARG" >&2
            exit 1
            ;;
    esac
done


# Set default identity if not provided
if [ -z "$identity" ]; then
    identity=0.90
fi

# Define input files
shift $((OPTIND - 1))
if [ "$#" -lt 2 ]; then
    echo "Error: At least two GFF3 files are required."
    Help
    exit 1
fi

input_files=("$@")

# Set clinker command
clinker_cmd=(clinker "${input_files[@]}" -p "$output_file" -i "$identity")

# Run clinker
singularity exec \
    "$container_dir/$clinker" \
    "${clinker_cmd[@]}"