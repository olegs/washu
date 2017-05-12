#!/usr/bin/env python
from pipeline_utils import run_bash, move_forward
from reports.macs2_logs import process_macs2_logs

__author__ = 'oleg.shpynov@jetbrains.com'

import getopt
import os
import re
import sys
from bed.bedtrace import run

help_message = '''
Usage:

python util.py find_input <file>
    Finds input given the file name. Heuristics: among all the files within folder find file with "input" substring and
    most common subsequence with initial file.

python util.py effective_genome_fraction <genome> <chrom.sizes.path>
    Computes effective genome size, required for SICER.
'''


def usage():
    print(help_message)


def lcs(x, y):
    """
    Finds longest common subsequence
    Code adopted from https://en.wikibooks.org/wiki/Algorithm_Implementation/Strings/Longest_common_subsequence#Python
    """
    m = len(x)
    n = len(y)
    # An (m+1) times (n+1) matrix
    c = [[0] * (n + 1) for _ in range(m + 1)]
    for i in range(1, m + 1):
        for j in range(1, n + 1):
            if x[i - 1] == y[j - 1]:
                c[i][j] = c[i - 1][j - 1] + 1
            else:
                c[i][j] = max(c[i][j - 1], c[i - 1][j])

    def back_track(i, j):
        if i == 0 or j == 0:
            return ""
        elif x[i - 1] == y[j - 1]:
            return back_track(i - 1, j - 1) + x[i - 1]
        else:
            if c[i][j - 1] > c[i - 1][j]:
                return back_track(i, j - 1)
            else:
                return back_track(i - 1, j)

    return len(back_track(m, n))


def find_input(bam):
    filename = os.path.basename(bam)
    if 'input' in filename:
        return ''

    # Find all the files within folder
    dir_path = os.path.dirname(bam)
    f = []
    for (_, _, name) in os.walk(dir_path):
        f.extend(name)
        break

    def sort_function(x):
        return lcs(filename, x)

    inputs = [x for x in f if re.match('.*input.*\\.bam$', x)]
    if len(inputs) > 0:
        return max(inputs, key=sort_function)
    else:
        return ''


def run_macs2(work_dir, genome, chrom_sizes, name, *params):
    folder = '{}_macs_{}'.format(work_dir, name)
    print('Processing', folder)
    if not os.path.exists(folder):
        # -B produces bedgraph for signal
        if os.path.exists(chrom_sizes):
            params += ('-B',)
        run_bash("macs2.sh", work_dir, genome, chrom_sizes, name, *[str(p) for p in params])
        move_forward(work_dir, folder, ["*{}*".format(name)], copy_only=True)
        process_macs2_logs(folder)


def effective_genome_fraction(genome, chrom_sizes_path):
    """From MACS2 documentation:
    The default hs 2.7e9 is recommended for UCSC human hg18 assembly.
    Here are all precompiled parameters for effective genome size:
    hs: 2.7e9
    mm: 1.87e9
    ce: 9e7
    dm: 1.2e8"""
    chrom_length = int(run([['cat', chrom_sizes_path],
                            ['grep', '-v', 'chr_'],
                            ['awk', '{ print L+=$2 } END {print L}']])[0].decode('utf-8').strip())
    if genome.startswith('mm'):
        size = 1.87e9
    elif genome.startswith('hg'):
        size = 2.7e9
    else:
        raise StandardError('Unknown species {}'.format(genome))
    return size / chrom_length


def main():
    argv = sys.argv
    opts, args = getopt.getopt(argv[1:], "h", ["help"])
    # Process help
    for o, a in opts:
        if o in ("-h", "--help"):
            usage()
            return
    # find_input option
    if len(args) == 2 and args[0] == 'find_input':
        print(find_input(args[1]))

    # effective_genome_fraction option
    if len(args) == 3 and args[0] == 'effective_genome_fraction':
        print(effective_genome_fraction(args[1], args[2]))


if __name__ == "__main__":
    main()