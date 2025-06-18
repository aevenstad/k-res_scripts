#!/bin/bash

# Wrapper script to run standalone BAKTA

Help() {
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  -h                Show this help message"
    echo "  -s <sample_name>  Specify sample name (output prefix)"
    echo "  -i <file>         Specify assembly file (FASTA format)"
}

if [[ " $@ " =~ " -h " ]]; then
    Help
    exit 0
fi

while getopts ":h:s:i:o:" option; do
    case $option in
        h)
            Help
            exit 0
            ;;
        s)  
            sample="$OPTARG"
            ;;
        i)  
            assembly_file="$OPTARG"
            ;;
        \?) 
            echo "Invalid option: -$OPTARG" >&2
            exit 1
            ;;
    esac
done


# BAKTA container
bakta_container=/bigdata/Jessin/Softwares/containers/bakta_1.10.4--53910f4b13200439.sif

# Get absolute path for assembly file
if [ -n "$assembly_file" ]; then
    assembly_file=$(readlink -f "$assembly_file")
else
    echo "Error: Assembly file is required." >&2
    exit 1
fi


# Prepare bind arguments for singularity
bind_args=()
bind_args+=("-B" "$(dirname "$assembly_file"):/data")
bind_args+=("-B" "/bigdata/Jessin/Softwares/Database/bakta_db/db/:/bakta_db")

# Run BAKTA using singularity
singularity exec "${bind_args[@]}" "$bakta_container" \
    bakta \
    $assembly_file \
    --output "${sample}_bakta" \
    --db /bakta_db \
    --keep-contig-headers \
    --threads 12
