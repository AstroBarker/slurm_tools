#!/bin/bash
#SBATCH -A snaphu
#SBATCH -N 1  # num nodes
#SBATCH -n 16 # num_cores
#SBATCH -C NOAUTO:amd20
#SBATCH --mem=16GB
#SBATCH --time=00:01:30
#SBATCH -o slurm-%j.out
#SBATCH -e slurm-%j.err
  
# =============================================================================
# Based on PBS scripts from https://tinyurl.com/selfrestart 
# Modified for SLURM
# =============================================================================

# =============================================================================
#  Self resubmitting SLURM bash script:
#
#  * Submits a followon job before executing the current job.  The followon 
#    job will be in the "H"eld state until the current job completes
#
#  * Assumes program being run is checkpointing at regular intervals and is
#    able to resume execution from a checkpoint
#
#  * Does not assume the program will complete within the requested time
#
#  * Uses an environment variable (NJOBS) to limit the total number of 
#    resubmissions in the sequence of jobs
#
#  * Allows the early termination of the sequence of jobs - just create/touch
#    the file STOP_SEQUENCE in the jobs working directory.  This may be done 
#    by the executable program when it has completed the "whole" job or by hand 
#    if there is a problem
#
#  * This script may be renamed anything (<15 characters) but if you use the -N 
#    option to qsub you must edit the qsub line below to give the script name 
#    explicitly
#
#  * To use: 
#         - make appropriate changes to the SBATCH options above and to the 
#           execution and file manipulation lines belo
#         - submit the job with the appropriate value of NJOBS, eg:
#                    sbatch --export=NJOBS=5 <scriptname>
#         - specify  environment variable FRESH=1 if it is the first run 
#                    (e.g., not a restart)
#
#  * To kill a job sequence, either touch the file STOP_SEQUENCE or qdel
#    the held job followed by the running job
#
#  * To test, try  "sleep 100"  as your executable line
#
# ===============================================================================

ECHO=/bin/echo

#
# These variables are assumed to be set:
#   NJOBS is the total number of jobs in a sequence of jobs (defaults to 1)
#   NJOB is the number of the previous job in the sequence (defaults to 0)
#   FRESH (0 or 1) indicates a fresh run (defaults to 1: not a restart)
#
  
if [[ X$NJOBS == X ]]; then
    $ECHO "NJOBS (total number of jobs in sequence) is not set - defaulting to 1"
    export NJOBS=1
fi
  
if [[ X$NJOB == X ]]; then
    $ECHO "NJOB (previous job number in sequence) is not set - defaulting to 0"
    export NJOB=0
fi

if [[ X$FRESH == X ]]; then
    $ECHO "FRESH not set -- assuming fresh run"
    export FRESH=1
fi

#
# Quick termination of job sequence - look for a specific file 
#  (the filename could be a qsub -v argument)
#
if [[ -f STOP_SEQUENCE ]]; then
    $ECHO  "Terminating sequence after $NJOB jobs"
    exit 0
fi

#
# Increment the counter to get current job number
#
NJOB=$((NJOB+1))

#
# Are we in an incomplete job sequence - more jobs to run ?
#
if [[ $NJOB -lt $NJOBS ]]; then
    #
    # Now submit the next job
    # (Assumes -N option not used to change job name.)
    #
    NEXTJOB=$((NJOB+1))
    $ECHO "Submitting job number $NEXTJOB in sequence of $NJOBS jobs"
    sbatch --dependency=afterok:"$SLURM_JOBID" "$SLURM_JOB_NAME"
else
    $ECHO "Running last job in sequence of $NJOBS jobs"
fi


#
# File manipulation prior to job commencing, eg. clean up previous output files,
# check for consistency of checkpoint files, ...
#
if [[ $NJOB -gt 1 ]]; then
    echo " "
    # .... USER INSERTION HERE 
fi


#
# Now run the job ...
#

#===================================================
# .... USER INSERTION OF EXECUTABLE LINE HERE 
#===================================================

echo "$FRESH"
if [[ $FRESH == 1 ]]; then
    # fresh run (no restart)
    cd "${SLURM_SUBMIT_DIR}" || exit
    python helloworld.py
    export FRESH=0 # false -- restarts
else
    # restart command
    cd "${SLURM_SUBMIT_DIR}" || exit
    python helloworld2.py
fi
export FRESH=0 # false -- restarts


#
# Not expected to reach this point in general but if we do, check that all 
# is OK.  If the job command exited with an error, terminate the job
#
errstat=$?
if [[ $errstat -ne 0 ]]; then
    # A brief nap so SBATCH kills us in normal termination. Prefer to 
    # be killed by SBATCH if SBATCH detected some resource excess
    sleep 5  
    $ECHO "Job number $NJOB returned an error status $errstat - stopping job sequence."
    touch STOP_SEQUENCE
    exit $errstat
fi
