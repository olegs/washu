import os
import os.path
import argparse
import subprocess
import itertools
import shutil

from glob import glob

PARALLEL_SCRIPTS_PATH = os.path.abspath(os.path.join(os.path.dirname(os.path.realpath(__file__)), "parallel"))


class WritableDirectory(argparse.Action):
    def __call__(self, parser, namespace, values, option_string=None):
        if not os.path.isdir(values):
            raise argparse.ArgumentTypeError("{0} is not a valid path".format(values))
        if os.access(values, os.R_OK + os.W_OK):
            setattr(namespace, self.dest, values)
        else:
            raise argparse.ArgumentTypeError("{0} is not a writable directory".format(values))


def run_bash(script, *params):
    command = " ".join(["bash", os.path.join(PARALLEL_SCRIPTS_PATH, script), *[str(p) for p in params]])
    print(command)
    subprocess.run(command, shell=True)


def run(*params):
    command = " ".join([str(p) for p in params])
    print(command)
    subprocess.run(command, shell=True)


def move_forward(folder, new_folder, what_to_move, copy_only=False):
    # Necessary for correct copy behavior
    os.chdir(folder)
    os.mkdir(new_folder)
    for pattern in itertools.chain.from_iterable(map(glob, what_to_move)):
        shutil.move(pattern, new_folder)
    if not copy_only:
        os.chdir(new_folder)
        return new_folder
    else:
        return folder
