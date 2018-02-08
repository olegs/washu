import datetime
import sys
import tempfile
from pathlib import Path

__author__ = 'petr.tsurinov@jetbrains.com'
help_data = """
Usage: peak_metrics.py [peaks folder] [output pdf path] [top peaks count (optional)]

Script creates pdf report with ChIP-seq consensus statistics:
 1) peak consensus (15%, 20%, 33%, 50%, 66%, 80%, 85%, 100%) venn diagram
 2) peak consensus (15%, 20%, 33%, 50%, 66%, 80%, 85%, 100%) bar plot
"""


def _cli():
    args = sys.argv

    if len(args) < 2:
        print(help_data)
        sys.exit(1)

    folder_path = Path(args[1])
    paths = sorted([str(f) for f in folder_path.iterdir() if regions_extension(f.name)])
    tmp_dir = Path(tempfile.gettempdir())
    filtered_paths = []

    if len(args) == 4:
        for bed_path in paths:
            tmp_path = tmp_dir / "{}_{}.bed".format(Path(bed_path).stem, args[3])
            with open(str(tmp_path), 'w') as f:
                run((["sort", "-k9nr", str(bed_path)], ["head", "-n", args[3]]), stdout=f)
                filtered_paths.append(tmp_path.name)
    else:
        filtered_paths = paths

    tracks_paths = sorted({path for path in filtered_paths if is_od_or_yd(path)})
    od_paths_map = {donor(track_path): track_path for track_path in tracks_paths
                    if regions_extension(track_path) and is_od(track_path)}
    yd_paths_map = {donor(track_path): track_path for track_path in tracks_paths
                    if regions_extension(track_path) and is_yd(track_path)}

    with PdfPages(args[2]) as pdf:
        # Code for different consensuses investigation
        for percent in [100, 85, 80, 66, 50, 33, 20, 15]:
            od_consensus_bed, yd_consensus_bed, yd_od_int_bed = \
                calc_consensus_file(list(od_paths_map.values()), list(yd_paths_map.values()),
                                    percent=percent)
            venn_consensus(od_consensus_bed, yd_consensus_bed, percent, pdf)
            bar_consensus(od_paths_map, yd_paths_map, od_consensus_bed, yd_consensus_bed,
                          yd_od_int_bed, num_of_threads, pdf)

        desc = pdf.infodict()
        desc['Title'] = 'Report: Consensus plots for data investigation'
        desc['Author'] = 'JetBrains Research BioLabs'
        desc['Subject'] = 'consensus'
        desc['CreationDate'] = datetime.datetime.today()
        desc['ModDate'] = datetime.datetime.today()


if __name__ == "__main__":
    # Force matplotlib to not use any Xwindows backend.
    import matplotlib
    matplotlib.use('Agg')

    from matplotlib.backends.backend_pdf import PdfPages
    from downstream.aging import regions_extension, donor, is_od, is_yd, is_od_or_yd
    from bed.bedtrace import run
    from downstream.peak_metrics import calc_consensus_file, venn_consensus, bar_consensus

    num_of_threads = 30
    _cli()
