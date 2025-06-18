#!/bin/bash

# Wrapper script to run standalone LRE-Finder
# Takes either Illumina or NanoPore input files


Help() {
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  -h                Show this help message"
    echo "  -s <sample_name>  Specify sample name"
    echo "  -i <file>         Specify Illumina forward reads"
    echo "  -I <file>         Specify Illumina reverse reads"
    echo "  -n <file>         Specify NanoPore long reads"
    echo "  -o <dir>          Specify output directory (default: current directory)"
}

if [[ " $@ " =~ " -h " ]]; then
    Help
    exit 0
fi

while getopts ":h:i:I:n:o:" option; do
    case $option in
        h)
            Help
            exit 0
            ;;
        s)  
            sample="$OPTARG"
            ;;
        i)  illumina=true
            forward_reads="$OPTARG"
            ;;
        I)  illumina=true
            reverse_reads="$OPTARG"
            ;;
        n)  nanopore=true
            longreads="$OPTARG"
            ;;
        \?) echo "Invalid option: -$OPTARG" >&2
            exit 1
            ;;
    esac
done

# LRE-Finder container path 
lre_finder=/bigdata/Jessin/Softwares/containers/lre-finder_v1.0.0.sif

# Get absolute path for input files
if [ -n "$forward_reads" ]; then
    forward_reads=$(readlink -f "$forward_reads")
fi
if [ -n "$reverse_reads" ]; then
    reverse_reads=$(readlink -f "$reverse_reads")
fi
if [ -n "$longreads" ]; then
    longreads=$(readlink -f "$longreads")
fi


bind_args=()
if [ -n "$forward_reads" ]; then
    bind_args+=(--bind "$forward_reads:/data/forward_reads.fastq")
fi
if [ -n "$reverse_reads" ]; then
    bind_args+=(--bind "$reverse_reads:/data/reverse_reads.fastq")
fi
if [ -n "$longreads" ]; then
    bind_args+=(--bind "$longreads:/data/longreads.fastq")
fi


lre_cmd=(LRE-Finder.py -o "$sample")

if [ -n "$forward_reads" ] && [ -n "$reverse_reads" ]; then
    lre_cmd+=(-ipe /data/forward_reads.fastq /data/reverse_reads.fastq)
elif [ -n "$longreads" ]; then
    lre_cmd+=(-n /data/longreads.fastq)
fi


singularity exec \
    "${bind_args[@]}" \
    $lre_finder \
    "${lre_cmd[@]}" \
    -t_db /lre-finder/elmDB/elm \
    -ID 90 -1t1 -cge -matrix |\
    html2text > "${sample}/LRE-Finder_out.txt"
