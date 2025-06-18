#!/bin/bash
# Wrapper script to run BAKTA
# USAGE: bakta.sh -s <sample_name> -i <assembly_file>
# BAKTA version: 1.10.4

# Container directory
container_dir="/bigdata/Jessin/Softwares/containers"
bakta="quay.io-biocontainers-bakta-1.10.4--pyhdfd78af_0.img"

# Pull container if it doesn't exist on the system
if [ ! -f "$container_dir/$bakta" ]; then
    echo "Container not found. Pulling from registry..."
    singularity pull --name "$container_dir/$bakta" "docker://quay.io/biocontainers/bakta:1.10.4--pyhdfd78af_0"
    if [ $? -ne 0 ]; then
        exit 1
    fi
fi

# Bakta database
kres_192=/bigdata/Jessin/Softwares/Database/bakta_db/db
kres_130=/bigdata/Jessin/Softwares/bakta_db/db
kres_128=/bigdata/Jessin/Softwares/bakta/db/


if [ -d "$kres_192" ]; then
    bakta_db="$kres_192"
elif [ -d "$kres_130" ]; then
    bakta_db="$kres_130"
elif [ -d "$kres_128" ]; then
    bakta_db="$kres_128"
else
    echo "No valid BAKTA database found. Please check the database path."
    exit 1
fi


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


# Get absolute path for assembly file
if [ -n "$assembly_file" ]; then
    assembly_file=$(readlink -f "$assembly_file")
else
    echo "Error: Assembly file is required." >&2
    exit 1
fi


# Prepare bind arguments for singularity
bind_args=()
bind_args+=("-B" "$assembly_file:/data/assembly.fasta")
bind_args+=("-B" "$bakta_db:/bakta_db")

# Prepare Bakta command
output_dir=${sample}_bakta_out
threads=12
bakta_cmd=(bakta /data/assembly.fasta --output "${output_dir}" --prefix "${sample}" --db /bakta_db --keep-contig-headers --threads "$threads")

# Run BAKTA container
singularity exec \
    "${bind_args[@]}" \
    "$container_dir/$bakta" \
    "${bakta_cmd[@]}"
