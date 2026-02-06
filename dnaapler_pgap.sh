#!/bin/bash
#
# Wrapper script to run PGAP annotation tool.
# Written to work with output structure from
# aevenstad/assembly_amr Nextflow pipeline
#
# Usage: bash run_pgap.sh -i <input_dir> -s <samplesheet>
#
set -eo pipefail

LOGFILE="run_$(date +%Y%m%d_%H%M%S).log"

log() {
  local level="$1"
  shift
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $*" | tee -a "$LOGFILE"
}

info()  { log INFO  "$@"; }
warn()  { log WARN  "$@"; }
error() { log ERROR "$@"; }

Help() {
  echo "Usage: $0 [options]"
  echo "Options:"
  echo "  -h                     Show this help message"
  echo "  -i <indir>             Specify Nextflow outdir"
  echo "  -p <plasmid list>      List of plasmids to process"
}

if [[ " $@ " =~ " -h " ]]; then
  Help
  exit 0
fi

while getopts ":h:i:p:" option; do
  case $option in
  h)
    Help
    exit 0
    ;;
  i)
    input_dir="$OPTARG"
    ;;
  p)
    plasmids="$OPTARG"
    ;;
  \?)
    echo "Invalid option: -$OPTARG" >&2
    exit 1
    ;;
  esac
done

# Set path for tools
DNAAPLER="/bigdata/Jessin/Softwares/containers/dnaapler_1.2.0--d4882d19d1c147a7.sif"
PGAP="/bigdata/Jessin/Softwares/pgap.py"


info "Starting $0"
info "Input dir: ${input_dir}"
info "Plasmid list: ${plasmids}"
info "DNAAPLER image: ${DNAAPLER}"
info "PGAP script: ${PGAP}"

# Get plasmids from input list
mapfile -t plasmid_ids < "$plasmids"
info "Loaded ${#plasmid_ids[@]} plasmids"

# loop over samples and run pgap
for plasmid in "${plasmid_ids[@]}"; do
  info "----------------------------------------"
  info "Processing plasmid: ${plasmid}"
  # get sample name
  sample_id=${plasmid%_*}
  # get species from rmlst results
  rmlst_species="$(cat ${input_dir}/${sample_id}/rmlst/${sample_id}_species.txt | sed 's/_/ /g')"
  # get plasmid fasta
  plasmid_fasta="${input_dir}/${sample_id}/plasmids/circular/${plasmid}.fasta"

  mkdir -p ${plasmid}
  \cp $plasmid_fasta $plasmid/
  cd ${plasmid}

  plasmid_fasta="${plasmid}.fasta"

  info "Running dnaapler"
  if singularity exec "$DNAAPLER" \
      dnaapler plasmid \
      --input "$plasmid_fasta" \
      --output "${plasmid}_dnaapler" \
      --prefix "${plasmid}" \
      -f \
      &> dnaapler.stdout; then
    info "dnaapler completed successfully"
  else
    error "dnaapler failed for ${plasmid}"
    cd ..
    continue
  fi


  reoriented_fasta="${plasmid}_dnaapler/${plasmid}_reoriented.fasta"

  info "Running PGAP"
  if "$PGAP" \
      -n \
      -o "${plasmid}_pgap" \
      -s "${rmlst_species}" \
      -g ${reoriented_fasta} \
      --prefix "${plasmid}" \
      --docker /usr/bin/singularity \
      --no-internet \
      --ignore-all-errors \
      --cpus 12 \
      > ${plasmid}_pgap_runlog.txt; then
    info "PGAP completed successfully"
    mv "${plasmid}_pgap_runlog.txt" "${plasmid}_pgap/"
  else
    warn "PGAP reported errors for ${plasmid} (see run log)"
  fi

  cd ../
done

info "$0 completed successfully"
