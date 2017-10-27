import os
import sys
from pathlib import Path
import pandas as pd
from itertools import chain
import datetime

# Force matplotlib to not use any Xwindows backend.
import matplotlib
matplotlib.use('Agg')

from matplotlib.backends.backend_pdf import PdfPages  # nopep8

parent_dir = os.path.dirname(os.path.realpath(__file__))
project_root = os.path.abspath(os.path.join(parent_dir) + "/..")
sys.path.insert(0, project_root)

from reports.bed_metrics import plot_metric_heatmap, bed_metric_table, \
    label_converter_donor_and_tool, color_annotator_chain, \
    color_annotator_outlier, color_annotator_age  # nopep8


def process_hist_mod(peaks_root, outliers_df, threads, golden, pdf_printer):
    assert golden, "Zinbra paths not supported yet"

    all_peaks_root = peaks_root / "bed_all"

    peaks_paths = list(chain(all_peaks_root.glob("*Peak"),
                             all_peaks_root.glob("*-island.bed")))

    hist_mod = peaks_root.name
    res_prefix = "{}_intersection".format(hist_mod)
    df_path = peaks_root / "{}.csv".format(res_prefix)
    if df_path.exists():
        # df = pd.read_csv(str(df_path))
        df = pd.DataFrame.from_csv(str(df_path))
    else:
        df = bed_metric_table(peaks_paths, peaks_paths, threads=threads)
        df.to_csv(str(df_path))
        print("Metrics results saved to:", str(df_path))

    anns = [color_annotator_age]
    if hist_mod in outliers_df.columns:
        anns.append(color_annotator_outlier(outliers_df, mod_dir.name))
    annotator = color_annotator_chain(*anns)

    # print to pdf:
    plot_metric_heatmap(
        "Intersection metric: All donors {}".format(hist_mod),
        df,
        save_to=pdf_printer,
        row_cluster=True, col_cluster=True,
        row_color_annotator=annotator,
        col_color_annotator=annotator,
        row_label_converter=label_converter_donor_and_tool,
        col_label_converter=label_converter_donor_and_tool
    )


outliers_path = "/mnt/stripe/bio/experiments/aging/Y20O20.outliers.csv"
outliers_df = pd.read_csv(outliers_path, delimiter="\t", skiprows=1,
                          index_col="donor")

golden_root = Path("/mnt/stripe/bio/experiments/aging/peak_calling")
result_plot_path = golden_root / "intersection.pdf"
with PdfPages(str(result_plot_path)) as pdf:
    for mod_dir in golden_root.glob("H*"):
        if mod_dir.is_dir():
            process_hist_mod(Path(mod_dir), outliers_df,
                             threads=30, golden=True,
                             pdf_printer=pdf)

    d = pdf.infodict()
    d['Title'] = 'Report: Intersection metric for outliers detection'
    d['Author'] = 'JetBrains Research BioLabs'
    d['Subject'] = 'outliers'
    # d['Keywords'] = 'outliers jetbrains aging'
    d['CreationDate'] = datetime.datetime.today()
    d['ModDate'] = datetime.datetime.today()

print("Metrics plot saved to:", str(result_plot_path))

# if __name__ == "__main__":
