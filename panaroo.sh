#!/bin/bash

# Container directory
container_dir="/bigdata/Jessin/Softwares/containers"
panaroo="panaroo_1.5.2--4ef90a1e6f47ef1c.sif"


Help() {
  echo "Usage: $0 [options]"
  echo "Options:"
  echo "  -h                Show this help message"
  echo "  -i <file>         Specify input file (tsv)"
}

if [[ " $@ " =~ " -h " ]]; then
  Help
  exit 0
fi

while getopts ":h:i:o:" option; do
  case $option in
  h)
    Help
    exit 0
    ;;
  i)
    input="$OPTARG"
    ;;
  o)
    outdir="$OPTARG"
    ;;
  \?)
    echo "Invalid option: -$OPTARG" >&2
    exit 1
    ;;
  esac
done


# Get absolute path for input directory
if [ -n "$input" ]; then
  input=$(readlink -f "$input")
else
  echo "Error: File does not exist." >&2
  exit 1
fi


# Set panaroo command
alignment="core"
clean_mode="sensitive"
threshold=0.99
core_threshold=0.95
threads=24

panaroo_cmd=(
  panaroo --input $input \
  --out_dir $outdir \
  --alignment $alignment \
  --clean-mode $clean_mode \
  --remove-invalid-genes \
  --merge_paralogs \
  --threshold $threshold \
  --core_threshold $core_threshold \
  --threads $threads
)


# Run panaroo
singularity exec \
  "$container_dir/$panaroo" \
  "${panaroo_cmd[@]}"
