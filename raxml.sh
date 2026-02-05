#!/bin/bash

# Container directory
container_dir="/bigdata/Jessin/Softwares/containers"
raxml="raxml-ng_1.2.2--fcf1b8f7b41431ee.sif"

Help() {
  echo "Usage: $0 [options]"
  echo "Options:"
  echo "  -h                Show this help message"
  echo "  -p <prefix>       Specify output prefix"
  echo "  -i <file>         Specify location for MSA file (Panaroo output directory)"
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
    prefix="$OPTARG"
    ;;
  i)
    input_dir="$OPTARG"
    ;;
  \?)
    echo "Invalid option: -$OPTARG" >&2
    exit 1
    ;;
  esac
done


# Get absolute path for input directory
if [ -n "$input_dir" ]; then
  input_dir=$(readlink -f "$input_dir")
else
  echo "Error: Directory does not exist." >&2
  exit 1
fi

# Create output directory
output_dir=raxml_out
mkdir -p $output_dir

# Prepare bind arguments for singularity
bind_args=()
bind_args+=("-B" "$input_dir:/data")

# Prepare raxml command
output_dir=raxml_out
threads=12
model="GTR+G"
prefix=${output_dir}/${prefix}
bs_trees=1000
seed=12345
msa="/data/core_gene_alignment_filtered.aln"

raxml_cmd=(raxml-ng --msa $msa --model $model --prefix $prefix --threads $threads --all --bs-trees $bs_trees --seed $seed)

# Run raxml-ng
singularity exec \
  "${bind_args[@]}" \
  "$container_dir/$raxml" \
  "${raxml_cmd[@]}"
