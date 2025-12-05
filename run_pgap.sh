#!/bin/bash
#
# Wrapper script to run PGAP annotation tool.
# Written to work with output structure from
# aevenstad/assembly_amr Nextflow pipeline
#
# Usage: bash run_pgap.sh -i <input_dir> -s <samplesheet>
#
set -eo pipefail

Help() {
  echo "Usage: $0 [options]"
  echo "Options:"
  echo "  -h                Show this help message"
  echo "  -i <indir>         Specify Nextflow outdir"
  echo "  -s <samplesheet>      Nextflow samplesheet"
}

if [[ " $@ " =~ " -h " ]]; then
  Help
  exit 0
fi

while getopts ":h:i:s:" option; do
  case $option in
  h)
    Help
    exit 0
    ;;
  i)
    input_dir="$OPTARG"
    ;;
  s)
    samplesheet="$OPTARG"
    ;;
  \?)
    echo "Invalid option: -$OPTARG" >&2
    exit 1
    ;;
  esac
done

# Get sample identifiers from Nextflow samplesheet
sample_ids=$(cut -d"," -f1 ${samplesheet} | sed '1d')

echo
echo "Starting $0: $(date)"
echo " - Number of assemblies to annotate: ${#sample_ids}"
echo "------------------------------------------------------------------"
echo

# loop over samples and run pgap
for sample in ${sample_ids}; do
  # get species from rmlst results
  rmlst_species="$(cat ${input_dir}/${sample}/rmlst/${sample}_species.txt | sed 's/_/ /g')"
  # get assembly fasta from hybracter
  final_fasta="${input_dir}/${sample}/hybracter/FINAL_OUTPUT/${sample}_final.fasta"

  # Check if pgap has finished successfully and run if no output exists
  if [[ ! -f "${sample}_out/annot.gff" ]]; then

    echo "Starting annotation for ${sample} ("$rmlst_species")"

    ./pgap.py -n \
      -o "${sample}_out" \
      -s "${rmlst_species}" \
      -g ${final_fasta} \
      --docker /usr/bin/singularity \
      --no-internet \
      --ignore-all-errors \
      >${sample}_pgap_runlog.txt

    mv ${sample}_pgap_runlog.txt "${sample}_out"/

    echo " - PGAP finished successfully"

    cd "${sample}_out"

    head -n3 annot.gff >gff_header.tmp
    grep -v "#" annot.gff | cut -f1 | sort -u >contig_ids.tmp

    for i in $(cat contig_ids.tmp); do
      grep -A1 "##sequence-region ${i}" annot.gff >contig_header.tmp
      grep "^${i}" annot.gff >annotations.tmp
      cat gff_header.tmp contig_header.tmp annotations.tmp >${i}_annot.gff
      rm annotations.tmp contig_header.tmp

      sed -n "/${i}/,/^\/\/$/p" annot.gbk >"${i}_annot.gbk"
    done

    rm *.tmp
    cd ../

    echo " - Creating annotation files per contig"
    echo "-----------------------------------------"
    echo

  else
    echo "PGAP already finished for ${sample}"
    echo "-----------------------------------------"
    echo
  fi
done

echo "$0 completed: $(date)"
exit 0
