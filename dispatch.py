#! /usr/bin/env python

# This file is part of prosoda.  prosoda is free software: you can
# redistribute it and/or modify it under the terms of the GNU General Public
# License as published by the Free Software Foundation, version 2.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
# details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
#
# Copyright 2013 by Siemens AG, Wolfgang Mauerer <wolfgang.mauerer@siemens.com>
# All Rights Reserved.

# Dispatcher for the prosoda analysis based on a configuration file
from config import load_config, load_global_config
from subprocess import *
import argparse
import glob
import os
import sys
from conv import convert_dot_file
from tempfile import NamedTemporaryFile, mkdtemp
from dbManager import dbManager
import shutil

def _abort(msg):
    print(msg + "\n")
    sys.exit(-1)

def executeCommand(cmd, dry_run, ignoreErrors=False):
    if dry_run:
        print("dry-run: {0}".format(" " .join(cmd)))
        return

    try:
        p2 = Popen(cmd, stdout=PIPE)
        res = p2.communicate()[0]
    except OSError:
        _abort("Internal error: Could not execute command '{0}'".
               format(" ".join(cmd)))

    if p2.returncode != 0 and not(ignoreErrors):
        print("\n\n******* Internal error *******")
        print(res)
        print("*******\n\n")
        _abort("Internal error: Command {0} exited with {1}".format(" ".join(cmd),
                                                                    p2.returncode))
    return res


def dispatchAnalysis(args):
    conf = load_config(args.conf)
    global_conf = load_global_config("prosoda.conf")
    dbm = dbManager(global_conf)

    revs = conf["revisions"]
    rcs = conf["rcs"]

    if args.basedir == None:
        basedir = "./"
    else:
        basedir = args.basedir

    print("Processing project '{0}'".format(conf["description"]))
    pid = dbm.getProjectID(conf["project"], conf["tagging"])

    # Fill table release_timeline with the release information
    # known so far (date is not yet available)
    for i in range(len(revs)):
        dbm.doExecCommit("INSERT INTO release_timeline " +
                         "(type, tag, projectId) " +
                         "VALUES (%s, %s, %s)",
                         ("release", revs[i], pid))

    # Analyse all revision ranges
    for i in range(len(revs)-1):
        resdir = os.path.join(args.resdir, conf["project"],
                              conf["tagging"],
                              "{0}-{1}".format(revs[i], revs[i+1]))
        if not(os.path.isabs(resdir)):
            resdir = os.path.abspath(resdir)

        # TODO: Sanity checks (ensure that git repo dir exists)
        if 'proximity' == conf["tagging"]:
            check4ctags()
        
        #######
        # STAGE 1: Commit analysis
        # TODO: Instead of calling an external python script, it
        # would maybe wiser to call a procedure...
        print("  -> Analysing commits {0}..{1}".format(revs[i], revs[i+1]))
        cmd = []
        cmd.append(os.path.join(basedir, "cluster", "cluster.py"))
        cmd.append(os.path.join(args.gitdir, conf["repo"], ".git"))
        cmd.append(args.conf)
        cmd.append(resdir)
        cmd.append(revs[i])
        cmd.append(revs[i+1])

        if rcs[i+1] != None:
            cmd.append("--rc_start")
            cmd.append(rcs[i+1])

        if (not(args.use_db)):
            cmd.append("--create_db")

        executeCommand(cmd, args.dry_run)

        #########
        # STAGE 2: Cluster analysis
        print("  -> Detecting clusters")
        cmd = []
        cmd.append(os.path.join(basedir, "cluster", "persons.r"))
        cmd.append(resdir)
        cmd.append(args.conf)
        executeCommand(cmd, args.dry_run)

        #########
        # STAGE 3: Generate cluster graphs
        print("  -> Generating cluster graphs")
        files = glob.glob(os.path.join(resdir, "*.dot"))
        for file in files:
            out = NamedTemporaryFile(mode="w")
            out.writelines(convert_dot_file(file))
            # Make sure the information does not stall in caches
            # before dot hits the file
            out.flush()

            cmd = []
            cmd.append("dot")
            cmd.append("-Ksfdp")
            cmd.append("-Tpdf")
            cmd.append("-Gcharset=latin1")
            cmd.append("-o{0}.pdf".format(os.path.splitext(file)[0]))
            cmd.append(out.name)
            executeCommand(cmd, args.dry_run)

            # NOTE: Only close the temporary file after the graph has
            # been formatted -- the temp file is destroyed after close
            out.close()

        #########
        # STAGE 4: Report generation
        # Stage 4.1: Report preparation
        print("  -> Generating report")
        report_base = "report-{0}_{1}".format(revs[i], revs[i+1])
        cmd = []
        cmd.append(os.path.join(basedir, "cluster", "create_report.pl"))
        cmd.append(resdir)
        cmd.append("{0}--{1}".format(revs[i], revs[i+1]))

        out = open(os.path.join(resdir, report_base + ".tex"), "w")
        res = executeCommand(cmd, args.dry_run)
        if not(args.dry_run):
            out.write(res)

        out.close()

        # Stage 4.2: Compile report
        cmd = []
        cmd.append("pdflatex")
        cmd.append("-interaction=nonstopmode")
        cmd.append(os.path.join(resdir, report_base + ".tex"))

        # We run pdflatex in a temporary directory so that it's easy to
        # get rid of the log files etc. created during the run that are
        # not relevant for the final result
        orig_wd = os.getcwd()
        tmpdir = mkdtemp()

        os.chdir(tmpdir)
        executeCommand(cmd, args.dry_run, ignoreErrors=True)
        try:
            shutil.copy(report_base + ".pdf", resdir)
        except IOError:
            print("Warning: Could not copy report PDF (missing input data?)")

        os.chdir(orig_wd)

        shutil.rmtree(tmpdir)

    #########
    # Global stage 1: Time series generation
    print("=> Preparing time series data")
    cmd = []
    cmd.append(os.path.join(basedir, "ts.py"))
    cmd.append(args.resdir)
    cmd.append(args.conf)

    executeCommand(cmd, args.dry_run)

    #########
    # Global stage 2: Time series analysis
    print("=> Analysing time series")
    cmd = []
    cmd.append(os.path.join(basedir, "analyse_ts.r"))
    cmd.append(args.resdir)
    cmd.append(args.conf)

    executeCommand(cmd, args.dry_run)

def check4ctags():
    # check if the appropriate ctags is installed on the system
    prog_name    = 'Exuberant Ctags'
    prog_version = 'Exuberant Ctags 5.9~svn20110310'
    cmd = "ctags-exuberant --version".split()
    
    res = executeCommand(cmd, None)
    
    if not(res.startswith(prog_name)):
        print "Fatal Error: program {0} does not exist".format("ctags-exuberant")
        
    if not(res.startswith(prog_version)):
        # TODO: change this to use standard mechanism for error logging
        print "Fatal Error: Ctags version {0} not found".format(prog_version)
        exit()
    
if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument('resdir',
                        help="Base directory to store analysis results in")
    parser.add_argument('gitdir',
                        help="Base directory for git repositories")
    parser.add_argument('conf', help="Project specific configuration file")
    parser.add_argument('--use_db', action='store_true',
                        help="Re-use existing database")
    parser.add_argument('--basedir',
                        help="Base directory where the prosoda infrastructure is found")
    parser.add_argument('--dry-run', action="store_true",
                        help="Just show the commands called, don't perform any work")
    # TODO: Use tag as argument here, not in the configuration file
    # (better include information about signed-off or not in the configuration
    # file)

    args = parser.parse_args()
    dispatchAnalysis(args)
