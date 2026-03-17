#!/usr/bin/env bash
set -euo pipefail

FASTQ_ROOT="/bigdata/Jessin/Sequencing_projects/illumina_fastq_arkiv"
FASTQ_BIND="/mnt/illumina_fastq_arkiv"
CONTAINER="/bigdata/Jessin/Softwares/containers/nullarbor_2.0.20191013--f47e5b3164e12fa7.sif"

HOST_KRAKEN1_DB="/bigdata/Jessin/Softwares/Database/minikraken_20171013_4GB"
HOST_KRAKEN2_DB="/bigdata/Jessin/Softwares/Database/minikraken2_v1_8GB"

HOST_CENTRIFUGE_DIR="/bigdata/Jessin/Softwares/Database/centrifuge-db"
HOST_CENTRIFUGE_PREFIX="${HOST_CENTRIFUGE_DIR}/p_compressed+h+v"

CONT_KRAKEN1_DB="/db/minikraken_20171013_4GB"
CONT_KRAKEN2_DB="/db/minikraken2_v1_8GB"

CONT_CENTRIFUGE_DIR="/db/centrifuge"
CONT_CENTRIFUGE_PREFIX="${CONT_CENTRIFUGE_DIR}/p_compressed+h+v"

usage() {
  cat <<'EOF'
Usage:
  nullarbor_wrapper.sh -N RUN_NAME -r reference.fasta -o OUTDIR -c CPUS \
    [-s sample1,sample2,... | -S samples.txt] [-- extra nullarbor args]

Options:
  -N  Nullarbor run name
  -r  Reference fasta (must exist; current working directory will be bound)
  -o  Output directory
  -c  CPUs
  -s  Comma-separated sample names
  -S  File with one sample name per line
  -i  Name of generated input table (default: file_list.txt)
  -n  Dry run: only create input table, do not run singularity
  -h  Show this help

Notes:
  - FASTQ files are searched recursively under:
      /bigdata/Jessin/Sequencing_projects/illumina_fastq_arkiv
  - The generated input table is tab-separated with 3 columns:
      samplename    r1    r2
  - Paths written into the input table are container paths under:
      /mnt/illumina_fastq_arkiv
EOF
}

RUN_NAME=""
REFERENCE=""
OUTDIR=""
CPUS=""
INPUT_TSV="file_list.txt"
DRY_RUN=0
SAMPLE_CSV=""
SAMPLE_FILE=""
EXTRA_ARGS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
  -N)
    RUN_NAME="$2"
    shift 2
    ;;
  -r)
    REFERENCE="$2"
    shift 2
    ;;
  -o)
    OUTDIR="$2"
    shift 2
    ;;
  -c)
    CPUS="$2"
    shift 2
    ;;
  -s)
    SAMPLE_CSV="$2"
    shift 2
    ;;
  -S)
    SAMPLE_FILE="$2"
    shift 2
    ;;
  -i)
    INPUT_TSV="$2"
    shift 2
    ;;
  -n)
    DRY_RUN=1
    shift
    ;;
  -h | --help)
    usage
    exit 0
    ;;
  --)
    shift
    EXTRA_ARGS=("$@")
    break
    ;;
  *)
    echo "Unknown option: $1" >&2
    usage
    exit 1
    ;;
  esac
done

[[ -n "$RUN_NAME" ]] || {
  echo "Error: -N is required" >&2
  exit 1
}
[[ -n "$REFERENCE" ]] || {
  echo "Error: -r is required" >&2
  exit 1
}
[[ -n "$OUTDIR" ]] || {
  echo "Error: -o is required" >&2
  exit 1
}
[[ -n "$CPUS" ]] || {
  echo "Error: -c is required" >&2
  exit 1
}
[[ -n "$SAMPLE_CSV" || -n "$SAMPLE_FILE" ]] || {
  echo "Error: provide sample names with -s or -S" >&2
  exit 1
}

if [[ -n "$SAMPLE_CSV" && -n "$SAMPLE_FILE" ]]; then
  echo "Error: use either -s or -S, not both" >&2
  exit 1
fi

if [[ ! -f "$CONTAINER" ]]; then
  echo "Error: container not found: $CONTAINER" >&2
  exit 1
fi

if [[ ! -d "$FASTQ_ROOT" ]]; then
  echo "Error: FASTQ root not found: $FASTQ_ROOT" >&2
  exit 1
fi

for d in "$HOST_KRAKEN1_DB" "$HOST_KRAKEN2_DB" "$HOST_CENTRIFUGE_DIR"; do
  [[ -d "$d" ]] || {
    echo "Error: DB directory not found: $d" >&2
    exit 1
  }
done

if ! compgen -G "${HOST_CENTRIFUGE_PREFIX}*" >/dev/null; then
  echo "Error: DB files not found: ${HOST_CENTRIFUGE_PREFIX}*" >&2
  exit 1
fi

REFERENCE=$(readlink -f "$REFERENCE")
OUTDIR=$(readlink -m "$OUTDIR")
INPUT_TSV=$(readlink -m "$INPUT_TSV")
WORKDIR=$(pwd -P)

[[ -f "$REFERENCE" ]] || {
  echo "Error: reference not found: $REFERENCE" >&2
  exit 1
}

mkdir -p "$(dirname "$INPUT_TSV")" "$(dirname "$OUTDIR")"

map_sample_paths() {
  local host_path="$1"
  if [[ "$host_path" == "$FASTQ_ROOT"/* ]]; then
    printf '%s\n' "${host_path/$FASTQ_ROOT/$FASTQ_BIND}"
  else
    echo "Error: path is not under FASTQ root: $host_path" >&2
    return 1
  fi
}

collect_reads() {
  local sample="$1"
  local read="$2"
  local -n out_arr_ref="$3"
  local -a patterns=()

  if [[ "$read" == "1" ]]; then
    patterns=(
      -iname "${sample}*R1*.fastq.gz" -o
      -iname "${sample}*R1*.fq.gz" -o
      -iname "${sample}*_1.fastq.gz" -o
      -iname "${sample}*_1.fq.gz"
    )
  else
    patterns=(
      -iname "${sample}*R2*.fastq.gz" -o
      -iname "${sample}*R2*.fq.gz" -o
      -iname "${sample}*_2.fastq.gz" -o
      -iname "${sample}*_2.fq.gz"
    )
  fi

  mapfile -t out_arr_ref < <(find "$FASTQ_ROOT" -type f \( "${patterns[@]}" \) | sort -V)
}

join_by_comma() {
  local IFS=','
  echo "$*"
}

get_samples() {
  local -n arr_ref="$1"
  if [[ -n "$SAMPLE_FILE" ]]; then
    mapfile -t arr_ref < <(grep -v '^[[:space:]]*$' "$SAMPLE_FILE" | sed 's/[[:space:]]*$//')
  else
    IFS=',' read -r -a arr_ref <<<"$SAMPLE_CSV"
  fi
}

trim_array() {
  local -n arr_ref="$1"
  local i
  for i in "${!arr_ref[@]}"; do
    arr_ref[$i]="$(echo "${arr_ref[$i]}" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
  done
}

print_cmd() {
  local label="$1"
  shift
  printf '%s' "$label" >&2
  printf ' %q' "$@" >&2
  printf '\n' >&2
}

declare -a samples
get_samples samples
trim_array samples

[[ ${#samples[@]} -gt 0 ]] || {
  echo "Error: no samples provided" >&2
  exit 1
}

{
  for sample in "${samples[@]}"; do
    [[ -n "$sample" ]] || continue

    declare -a r1_files=()
    declare -a r2_files=()
    declare -a r1_mapped=()
    declare -a r2_mapped=()

    collect_reads "$sample" 1 r1_files
    collect_reads "$sample" 2 r2_files

    if [[ ${#r1_files[@]} -eq 0 ]]; then
      echo "Error: no R1 files found for sample: $sample" >&2
      exit 1
    fi
    if [[ ${#r2_files[@]} -eq 0 ]]; then
      echo "Error: no R2 files found for sample: $sample" >&2
      exit 1
    fi
    if [[ ${#r1_files[@]} -ne ${#r2_files[@]} ]]; then
      echo "Warning: sample $sample has ${#r1_files[@]} R1 files and ${#r2_files[@]} R2 files" >&2
    fi

    for f in "${r1_files[@]}"; do
      r1_mapped+=("$(map_sample_paths "$f")")
    done
    for f in "${r2_files[@]}"; do
      r2_mapped+=("$(map_sample_paths "$f")")
    done

    printf '%s\t%s\t%s\n' \
      "$sample" \
      "$(join_by_comma "${r1_mapped[@]}")" \
      "$(join_by_comma "${r2_mapped[@]}")"
  done
} >"$INPUT_TSV"

echo "Wrote input table: $INPUT_TSV"

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "Dry run requested; not starting singularity."
  exit 0
fi

export APPTAINERENV_KRAKEN_DEFAULT_DB="$CONT_KRAKEN1_DB"
export APPTAINERENV_KRAKEN2_DEFAULT_DB="$CONT_KRAKEN2_DB"
export APPTAINERENV_CENTRIFUGE_DEFAULT_DB="$CONT_CENTRIFUGE_PREFIX"

BIND_ARGS=(
  -B "$FASTQ_ROOT:$FASTQ_BIND"
  -B "$HOST_KRAKEN1_DB:$CONT_KRAKEN1_DB"
  -B "$HOST_KRAKEN2_DB:$CONT_KRAKEN2_DB"
  -B "$HOST_CENTRIFUGE_DIR:$CONT_CENTRIFUGE_DIR"
  -B "$WORKDIR:$WORKDIR"
)

OUTDIR_PARENT=$(dirname "$OUTDIR")
if [[ "$OUTDIR_PARENT" != "$WORKDIR" && "$OUTDIR_PARENT" != "$WORKDIR"/* ]]; then
  BIND_ARGS+=(-B "$OUTDIR_PARENT:$OUTDIR_PARENT")
fi

CMD=(
  nullarbor.pl
  --name "$RUN_NAME"
  --ref "$REFERENCE"
  --input "$INPUT_TSV"
  --outdir "$OUTDIR"
  --taxoner kraken2
  --assembler spades
  --cpus "$CPUS"
  --run
  --force
)

if [[ ${#EXTRA_ARGS[@]} -gt 0 ]]; then
  CMD+=("${EXTRA_ARGS[@]}")
fi

print_cmd "Running:" singularity exec "${BIND_ARGS[@]}" "$CONTAINER"
print_cmd "Inside container command:" "${CMD[@]}"

singularity exec "${BIND_ARGS[@]}" "$CONTAINER" "${CMD[@]}"
