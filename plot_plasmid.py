from pycirclize import Circos
from pycirclize.parser import Genbank
import numpy as np
from matplotlib.lines import Line2D
from matplotlib.patches import Patch
import argparse


parser = argparse.ArgumentParser(
    prog="plot_plasmid.py",
    description="Takes a GenBank file and creates a circular plot with annotations using pyCirclize",
)

parser.add_argument("-i", "--input", help = "Genbank annotation file (usually .gbff from bakta)")
parser.add_argument("-o", "--output", help = "Output file in .png format")
parser.add_argument("-t", "--title", help = "Plasmid name (title used in centre of the plot)")
parser.add_argument("--gc_content", action="store_true", help = "Add track for GC content")
parser.add_argument("--gc_skew", action="store_true", help = "Add track for GC skew")

args = parser.parse_args()

# Load GFF file
gbff_file = args.input
gbff = Genbank(gbff_file)

# Initialize circos instance
seqid2size = gbff.get_seqid2size()
space = 0 if len(seqid2size) == 1 else 2
circos = Circos(sectors=seqid2size, space=space)
circos.text(args.title, size=16, r=20)
circos.line(r=100, color="black")
circos.line(r=90, color="black")


seqid2features = gbff.get_seqid2features(feature_type="CDS")
seqid2seq = gbff.get_seqid2seq()
for sector in circos.sectors:
    cds_track = sector.add_track((90, 100))
    cds_track.axis(fc="#EEEEEE", ec="none")

    features = seqid2features[sector.name]
    label_pos_list, labels = [], []
    for feature in features:
        # Plot CDS features
        if feature.location.strand == 1:
            cds_track.genomic_features(feature, plotstyle="arrow", r_lim=(95, 100), fc="olive")
        else:
            cds_track.genomic_features(feature, plotstyle="arrow", r_lim=(90, 95), fc="purple")
        # Extract feature product label & position
        start, end = int(feature.location.start), int(feature.location.end)
        label_pos = (start + end) / 2
        label = feature.qualifiers.get("gene", [""])[0]
        if label == "":
            continue
        # For transposases set label to first element of product description (e.g. IS3, IS6)
        # Comment out section to keep "tnp" as label or select different index to keep more text. 
        elif label == "tnp":
            label = feature.qualifiers.get("product", [""])[0]
            label = label.split()[0]
            cds_track.annotate(label_pos,
                               label,
                               label_size=10,
                               min_r=100,
                               max_r=110,
                               line_kws=(dict(lw=1))
            )
        else:
            cds_track.annotate(label_pos,
                               label,
                               label_size=10,
                               min_r=100,
                               max_r=105,
                               line_kws=(dict(lw=1)),
            )

    # Plot xticks & intervals on inner position
    cds_track.xticks_by_interval(
        interval=5000,
        outer=False,
        label_formatter=lambda v: f"{v/ 1000:.1f} Kb",
        label_orientation="vertical",
        line_kws=dict(ec="grey", lw=2),
        show_bottom_line=False,
        tick_length=4,
        label_margin=2,
    )



    # Add track for GC content 
    if args.gc_content:
        gc_content_track = sector.add_track((50, 65))

        seq = seqid2seq[sector.name]
        label_pos_list, gc_contents = gbff.calc_gc_content(seq=seq)
        gc_contents = gc_contents - gbff.calc_genome_gc_content(seq=gbff.full_genome_seq)
        positive_gc_contents = np.where(gc_contents > 0, gc_contents, 0)
        negative_gc_contents = np.where(gc_contents < 0, gc_contents, 0)
        abs_max_gc_content = np.max(np.abs(gc_contents))
        vmin, vmax = -abs_max_gc_content, abs_max_gc_content
        gc_content_track.fill_between(
            label_pos_list,
            positive_gc_contents,
            0,
            vmin=vmin,
            vmax=vmax,
            color="black"
        )
        gc_content_track.fill_between(
            label_pos_list,
            negative_gc_contents,
            0,
            vmin=vmin,
            vmax=vmax,
            color="grey"
        )


    # Add track for GC skew
    if args.gc_skew:
        gc_skew_track = sector.add_track((35, 50))

        label_pos_list, gc_skews = gbff.calc_gc_skew(seq=seq)
        positive_gc_skews = np.where(gc_skews > 0, gc_skews, 0)
        negative_gc_skews = np.where(gc_skews < 0, gc_skews, 0)
        abs_max_gc_skew = np.max(np.abs(gc_skews))
        vmin, vmax = -abs_max_gc_skew, abs_max_gc_skew
        gc_skew_track.fill_between(
            label_pos_list,
            positive_gc_skews,
            0,
            vmin=vmin,
            vmax=vmax,
            color="olive"
        )
        gc_skew_track.fill_between(
            label_pos_list,
            negative_gc_skews,
            0,
            vmin=vmin,
            vmax=vmax,
            color="purple"
        )


# Draw plot
fig = circos.plotfig()

# Add legends
handles = [
    Patch(color="olive", label="Forward CDS"),
    Patch(color="purple", label="Reverse CDS")
]

if args.gc_content:
    handles.extend([
        Line2D([], [], color="black", label = "Positive GC content", marker ="^", ms=6, ls="None"),
        Line2D([], [], color="grey", label="Negative GC Content", marker="v", ms=6, ls="None"),
    ])

if args.gc_skew:
    handles.extend([
        Line2D([], [], color="olive", label="Positive GC Skew", marker="^", ms=6, ls="None"),
        Line2D([], [], color="purple", label="Negative GC Skew", marker="v", ms=6, ls="None"),
    ])

_ = circos.ax.legend(handles=handles, bbox_to_anchor=(0.5, 0.475), loc="center", fontsize=6)

# Save plot to file
fig.savefig(args.output, dpi=300, bbox_inches="tight")



