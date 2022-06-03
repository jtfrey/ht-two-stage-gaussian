#
# Configure shell variables that are used across the entire
# workflow.
#

# Number of CPUs each Gaussian job should use:
export NPROC=10

# Megabytes of memory per CPU for each Gaussian job:
export MEM_PER_PROC=2048

# What directory contains this file -- that's the base of our workflow
# hierarchy:
export WORKFLOW_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"

# The directory that by-default contains the CHEMICALs we want to study:
export CHEMICALS_DIR="${WORKFLOW_DIR}/0-chemicals"

# The gaseous (discrete molecule) calculations directory:
export GASEOUS_DIR="${WORKFLOW_DIR}/1-gaseous"

# The solvated calculations directory:
export SOLVATED_DIR="${WORKFLOW_DIR}/2-solvated"

# The completed computations directory:
export COMPLETED_DIR="${WORKFLOW_DIR}/3-completed"

# The name of our catalog file:
export CATALOG_FILENAME="job-map.index"

# The maximum number of jobs per sub-directory:
export MAX_JOBS_PER_DIRECTORY=100

