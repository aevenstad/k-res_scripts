#!/bin/bash

input_list=$1

singularity exec \
  /bigdata/Jessin/Softwares/containers/panaroo_1.5.2--4ef90a1e6f47ef1c.sif \
  panaroo \
  -i $input_list \
  -o panaroo_out \
  --clean-mode sensitive \
  -a core \
  --remove-invalid-genes \
  --merge_paralogs \
  --threshold 0.99 \
  --threads 24
