#!/bin/bash

# Source conda
source /bigdata/Jessin/Softwares/anaconda3/etc/profile.d/conda.sh

# Usage: ./wrapper.sh /path/to/run_dir
input_dir="$1"

# Check if input_dir exists
if [[ ! -d "$input_dir" ]]; then
  echo "Input directory does not exist!"
  exit 1
fi

# Find the fastq_pass folder
fastq_pass_dir=$(find "$input_dir" -type d -name "fastq_pass" | head -n 1)

if [[ -z "$fastq_pass_dir" ]]; then
  echo "No fastq_pass folder found in $input_dir"
  exit 1
fi

# Create output directory
mkdir -p fastq

# Loop over barcodes
for i in barcode{01..24}; do
  conda run -n seqkit seqkit seq "$fastq_pass_dir/$i"/*fastq.gz -o fastq/$i.fastq.gz
done

echo "All barcodes processed."
