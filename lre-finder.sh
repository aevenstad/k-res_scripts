#!/bin/bash

# Wrapper script to run LRE-Finder
# Takes either Illumina or NanoPore input files


# LRE-Finder container 
lre_finder=/bigdata/Jessin/Softwares/containers/lre-finder_v1.0.0.sif


Help() {
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  -h                Show this help message"
    echo "  -s <sample_name>  Specify sample name (used as output prefix)"
    echo "  -i <file>         Specify Illumina forward reads"
    echo "  -I <file>         Specify Illumina reverse reads"
    echo "  -n <file>         Specify NanoPore long reads"
}

if [[ " $@ " =~ " -h " ]]; then
    Help
    exit 0
fi

while getopts ":h:s:i:I:n:" option; do
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


# Set bind arguments for input files
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


# Set command for LRE-Finder
identity=90
lre_db=/lre-finder/elmDB/elm

lre_cmd=(LRE-Finder.py -o "${sample}" -t_db "$lre_db" -ID "$identity" -1t1 -cge -matrix)

## Add input files to command
if [ -n "$forward_reads" ] && [ -n "$reverse_reads" ]; then
    lre_cmd+=(-ipe /data/forward_reads.fastq /data/reverse_reads.fastq)
elif [ -n "$longreads" ]; then
    lre_cmd+=(-i /data/longreads.fastq)
fi


# run LRE-Finder container
singularity exec \
    "${bind_args[@]}" \
    "$lre_finder" \
    "${lre_cmd[@]}" \
    | html2text > "${sample}_LRE_out.txt"
