import matplotlib
from enum import Enum
import numpy as np
import pandas as pd
from scripts.util import *
from sklearn import preprocessing
from sklearn.decomposition import PCA
from sklearn.linear_model import LogisticRegression

# Force matplotlib to not use any Xwindows backend.
matplotlib.use('Agg')
import matplotlib.pyplot as plt  # nopep8
import seaborn as sns  # nopep8

# Explicitly setup style
plt.style.use('seaborn-darkgrid')


def signal_pca(x0,
               title,
               groups=None,
               scaled=False):
    if groups is None:
        groups = [OLD if is_od(r) else YOUNG for r in x0.index]
    # Use scaled PCA if required
    x = preprocessing.scale(x0) if scaled else x0
    pca = PCA(n_components=2)
    x_r = pca.fit_transform(x)
    for g in set(groups):
        group_filter = np.asarray([g == n for n in groups])
        plt.scatter(x_r[group_filter, 0], x_r[group_filter, 1],
                    color=g.color, alpha=.8, label=g.name)

    for g, label, x, y in zip(groups, [age(n) for n in x0.index], x_r[:, 0], x_r[:, 1]):
        plt.annotate(g.prefix + label,
                     xy=(x, y),
                     xytext=(5, 0),
                     color=g.color,
                     textcoords='offset points',
                     ha='right', va='bottom')
    plt.title(title)
    plt.xlabel('PC1 {}%'.format(int(pca.explained_variance_ratio_[0] * 100)))
    plt.ylabel('PC2 {}%'.format(int(pca.explained_variance_ratio_[1] * 100)))

    # Try to fit logistic regression and test
    y = [0 if g == YOUNG else 1 for g in groups]
    lr = LogisticRegression()
    lr.fit(x_r, y)
    p_y = [1 if x[0] < 0.5 else 0 for x in lr.predict_proba(x_r)]
    error = np.sum(np.abs(np.subtract(y, p_y)))
    return error


def signal_pca_all(x, title, groups=None):
    """Plot all the scaled variants of PCA, returns Logistic regression fit error"""
    plt.figure(figsize=(20, 5))
    plt.subplot(1, 4, 1)
    e = signal_pca(x, title, groups=groups)
    plt.subplot(1, 4, 2)
    e_scaled = signal_pca(x, 'SCALED {}'.format(title), groups=groups, scaled=True)
    plt.subplot(1, 4, 3)
    e_log = signal_pca(np.log1p(x), 'LOG {}'.format(title), groups=groups)
    plt.subplot(1, 4, 4)
    e_scaled_log = signal_pca(np.log1p(x), 'SCALED LOG {}'.format(title),
                              groups=groups, scaled=True)
    return e, e_scaled, e_log, e_scaled_log


class Plot(Enum):
    SCATTER = 1
    HISTOGRAM = 2
    MA = 3


def mean_regions(df, title, ax, plot_type):
    """Plots for mean values over OD and YD"""
    ods = [c for c in df.columns if is_od(c)]
    yds = [c for c in df.columns if is_yd(c)]

    signal = pd.DataFrame()
    signal["ODS"] = df[ods].mean(axis=1)
    signal["YDS"] = df[yds].mean(axis=1)

    if plot_type == Plot.MA:
        signal["M"] = np.log1p(signal["ODS"]) - np.log1p(signal["YDS"])
        signal["A"] = 0.5 * (np.log1p(signal["ODS"]) + np.log1p(signal["YDS"]))
        ax.scatter(signal["A"], signal["M"], alpha=.3, s=1)
        ax.set_xlabel("A")
        ax.set_ylabel("M")

        xmin = np.min(ax.get_xlim())
        xmax = np.max(ax.get_xlim())
        ax.plot([xmin, xmax], [0, 0], c="red", alpha=0.75, lw=1, ls='dotted')
        ax.set_xlim([xmin, xmax])

    elif plot_type == Plot.HISTOGRAM:
        signal["ODS"] = np.log1p(signal["ODS"]) / np.log(10)
        signal["YDS"] = np.log1p(signal["YDS"]) / np.log(10)

        ax.hist(signal["ODS"], color=OLD.color, bins=100, alpha=0.3, label="ODS")
        ax.hist(signal["YDS"], color=YOUNG.color, bins=100, alpha=0.3, label="YDS")
        ax.legend()
    else:
        ax.scatter(signal["ODS"], signal["YDS"], alpha=.3, s=1)
        ax.set_xlabel("mean ODS")
        ax.set_ylabel("mean YDS")
        # x = y
        lims = [
            np.min([ax.get_xlim(), ax.get_ylim()]),  # min of both axes
            np.max([ax.get_xlim(), ax.get_ylim()]),  # max of both axes
        ]
        # now plot both limits against eachother
        ax.plot(lims, lims, 'r-', alpha=0.75, lw=1, ls='dotted')
        ax.set_aspect('equal')
        ax.set_xlim(lims)
        ax.set_ylim(lims)

    ax.set_title(title)


def mean_boxplots(df, title, ax):
    """Plot mean values for individual donors"""
    signal = df.mean(axis=1).to_frame("value")
    signal.index = [age(n) for n in signal.index]
    signal["age"] = "ODS"
    signal.loc[signal.index.str.startswith("y"), "age"] = "YDS"

    age_labels = list(reversed(sorted(set(signal['age']))))
    sns.boxplot(x="age", y="value", data=signal, palette="Set3",
                linewidth=1.0, order=age_labels, ax=ax)
    sns.swarmplot(x="age", y="value", data=signal, color=".25", order=age_labels, ax=ax)

    for i, age_label in enumerate(age_labels):
        age_data = signal[signal['age'] == age_label]
        for j, label in enumerate(age_data.index):
            ax.annotate(label, xy=(i, age_data.iloc[j, :]['value']),
                        xytext=(5, 0),
                        color=OLD.color if age_label == "YDS" else YOUNG.color,
                        textcoords='offset points')

    ax.set_title(title)
    return signal


def visualize(f, name):
    try:
        print(f)
        df = pd.read_csv(f, sep='\t')
        od_inputs = [c for c in df.columns.values if is_od_input(c)]
        yd_inputs = [c for c in df.columns.values if is_yd_input(c)]
        if od_inputs and yd_inputs:
            signal = df.drop(['chr', 'start', 'end', od_inputs[0], yd_inputs[0]], axis=1)
        else:
            signal = df.drop(['chr', 'start', 'end'], axis=1)
        plt.figure(figsize=(20, 5))
        mean_regions(df, title=name, ax=plt.subplot(1, 4, 1),
                     plot_type=Plot.SCATTER)
        mean_regions(df, title='MA {}'.format(name), ax=plt.subplot(1, 4, 2),
                     plot_type=Plot.MA)
        mean_regions(df, title='LOG {}'.format(name), ax=plt.subplot(1, 4, 3),
                     plot_type=Plot.HISTOGRAM)
        means = mean_boxplots(signal.T, title=name, ax=plt.subplot(1, 4, 4))
        plt.savefig(re.sub('.tsv', '.png', f))
        plt.close()

        # Save means signal to df
        pd.DataFrame(means['value']).to_csv(re.sub('.tsv', '_data.csv', f),
                                            index=True, header=None)

        e, e_scaled, e_log, e_scaled_log = signal_pca_all(signal.T, name)
        plt.savefig(re.sub('.tsv', '_pca.png', f))
        plt.close()

        # Save pca fit errors to file
        pd.DataFrame(data=[[e, e_scaled, e_log, e_scaled_log]]). \
            to_csv(re.sub('.tsv', '_pca_fit_error.csv', f), index=None, header=False)

    except FileNotFoundError as e:
        print(e)


def process(work_dir, id):
    print('Visualize', work_dir, id)
    for signal_type in ['raw', 'rpm', 'rpkm', 'rpm_peaks', 'rpkm_peaks', 'scores', 'scores_tmm']:
        visualize(os.path.join(work_dir, id, '{0}_{1}.tsv'.format(id, signal_type)), signal_type)


def main():
    argv = sys.argv
    opts, args = getopt.getopt(argv[1:], "h", ["help"])
    if len(args) != 2:
        print("ARGUMENTS:  <work_dir> <id>\n"
              "CONVENTION: signal data is saved <folder>/<id>\n\n"
              "ARGS: " + ",".join(args))
        sys.exit(1)

    work_dir = args[0]
    id = args[1]

    process(work_dir, id)


if __name__ == "__main__":
    main()
