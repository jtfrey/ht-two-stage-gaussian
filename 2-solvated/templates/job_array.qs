#!/bin/bash -l
#
# Do not alter the --nodes/--ntasks options!
#SBATCH --nodes=1
#SBATCH --ntasks=1
##
## The same parameters we chose for NPROC and MEM_PER_PROC
## in the templating:
##
#SBATCH --cpus-per-task=[{% print(str(NPROC)) %}]
#SBATCH --mem-per-cpu=[{% print(str(NPROC*MEM_PER_PROC)) %}]M
#
#SBATCH --job-name=solvated
#SBATCH --output=./output/slurm-%A_%a.out
#SBATCH --time=2-00:00:00
#SBATCH --export=NONE
#SBATCH --partition=_workgroup_
##
## The array indices will go from one (1) to the highest
## produced by the templating:
##
#SBATCH --array=[{% print('{:d}-{:d}'.format(ARRAY_INDEX_START,ARRAY_INDEX_END)) %}]
#

# Load the workflow configuration:
source ../../config.sh

# Possible override of COMPLETED_DIR:
[{%
try:
    print('export COMPLETED_DIR="$(realpath "{:s}")"'.format(CHOSEN_COMPLETED_DIR))
except:
    pass
%}]

# Which directory corresponds with this index?
DIR_FOR_INDEX="$(grep "^\[${SLURM_ARRAY_TASK_ID}:" "$CATALOG_FILENAME" | sed -r -e 's/^\[[0-9]+://' -e 's/\] \{.*$//')"

# Where's our Slurm output file?
SLURM_OUTPUT_FILE="$(realpath --relative-to="$DIR_FOR_INDEX" "output/slurm-${SLURM_ARRAY_JOB_ID}_${SLURM_ARRAY_TASK_ID}.out")"

# Hop into the indexed directory:
cd "$DIR_FOR_INDEX"

# Symlink the job's Slurm output file into the indexed directory:
ln -s "$SLURM_OUTPUT_FILE" .

# Run the templated job.sh script therein:
./job.sh
exit $?

