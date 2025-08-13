# Scripts
Collection of scripts to run different tools at K-res


## Bakta
https://github.com/oschwengers/bakta

```
Usage: bakta.sh [options]
Options:
  -h                Show this help message
  -s <sample_name>  Specify sample name (output prefix)
  -i <file>         Specify assembly file (FASTA format)
```
Will run Bakta with the following command:
```
bakta <input_fasta> \
--output <sample_name>_bakta_out \
--prefix <sample_name> \
--db /bakta_db \ # The database is hardcoded in the script
--keep-contig-headers \
--threads 12
```

## Clinker 
https://github.com/gamcil/clinker

```
Usage: clinker.sh [options] test.gff3 test_2.gff3 ...
Options:
  -h                Show this help message
  -p <out.html>     Specify output HTML file
  -i <identity>     Set identity threshold (default: 0.90)
```


## LRE-Finder
https://bitbucket.org/genomicepidemiology/lre-finder/src/master/
```
Usage: lre-finder.sh [options]
Options:
  -h                Show this help message
  -s <sample_name>  Specify sample name (used as output prefix)
  -i <file>         Specify Illumina forward reads
  -I <file>         Specify Illumina reverse reads
  -n <file>         Specify NanoPore long reads
```

This will run LRE-Finder with the following command:
```
LRE-Finder.py \
-o <sample_name> \
-t_db $lre_db \ # Database is provided in the container image
-ID 90 \
-1t1 \
-cge \
-matrix \
# For illumina input
-ipe $read_R1 $read_R2
# For nanopore input
-i $ONT_longread
```

## Reorient plasmids
Workflow for reorienting plasmids before running Clinker


## Virulencefinder json to tsv
Convert json output from virulencefinder to tsv:
```
virulencefinder_json2tsv.py <input.json> <output.tsv>
```


