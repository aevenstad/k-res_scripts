# Reorient plasmids

Hybracter does not always reorient plasmids to start at replication initiation proteins. For visualizations such as `clinker` it is preferred to have plasmids start at the same protein.

## Run Dnaapler
The most straightforward option is to run `Dnaapler` on the plasmids to check if this resolves the issue. 

```
singularity exec /bigdata/Jessin/Softwares/containers/dnaapler_1.2.0--d4882d19d1c147a7.sif dnaapler plasmid --input plasmid.fasta --output plasmid_dnaapler --prefix plasmid_reoriented
```

### Run bakta on reoriented plasmids
Annotate the reoriented plasmid:
```
bakta.sh -i plasmid_reoriented.fasta -s plasmid_reoriented
```

If one or more replication proteins is not complete (e.g. dnaapler cannot find start codon) then it will reorient using another protein and the plasmids will not share the same start sequence.

For these plasmids we need to manually set the starting coordinate by first aligning against another plasmid which begins at the rep protein.

## Align the plasmids with MUMmer

First, align agains the reference (correctly oriented plasmid)
```
singularity exec /bigdata/Jessin/Softwares/containers/mummer4_4.0.1--c224edf926f42fac.sif nucmer --prefix alignment ref_plasmid.fasta plasmid.fasta
```

Then get the coordinates:
```
singularity exec /bigdata/Jessin/Softwares/containers/mummer4_4.0.1--c224edf926f42fac.sif show-coords -rcl alignment.delta > coords.txt
```

The output will look like this:
```
NUCMER

    [S1]     [E1]  |     [S2]     [E2]  |  [LEN 1]  [LEN 2]  |  [% IDY]  |  [LEN R]  [LEN Q]  |  [COV R]  [COV Q]  | [TAGS]
===============================================================================================================================
       1    18375  |    26281    44655  |    18375    18375  |   100.00  |    41968    47534  |    43.78    38.66  | plasmid00002	plasmid00004
   15407    16217  |    46101    46911  |      811      811  |    99.88  |    41968    47534  |     1.93     1.71  | plasmid00002	plasmid00004
   18372    41968  |     2684    26280  |    23597    23597  |    99.99  |    41968    47534  |    56.23    49.64  | plasmid00002	plasmid00004
```

Here we need to reorient the plasmid to start at position `26281`:

```
seqkit seq -w 0 plasmid.fasta | awk -v start=26281 '
    /^>/ {print; next}
    {seq=seq $0}
    END {
        rotated = substr(seq, start) substr(seq, 1, start - 1)
        print rotated
    }
' > plasmid_reoriented.fasta 
```

### Annotate with bakta
Again we need to run the annotation on the reoriented plasmid sequence:

```
bakta.sh -i plasmid_reoriented.fasta -s plasmid_reoriented
```

## Vizualize with clinker
When all plasmids are reoriented to start at the rep protein we can run clinker to create the visualization:

```
clinker.sh -p plasmids.html plasmid1.gff plasmid2.gff ...
```

