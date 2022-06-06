#!/bin/bash
#
# This script is used to generate a solvated job array hierarchy.
# The available_chemicals program is used to generate the list of
# available CHEMICAL species that will be combined with the list
# of desired SOLVENTS.
#
# The job_array.qs script that will submit the array is generated
# based on the templates/job_array.qs file.
#

# Basic configuration options:
source ../config.sh
shopt -s extglob

# Command-line options:
VERBOSITY=""
AVAILABLE_CHEMICALS_OPTS=()
SOLVENTS=""
CHOSEN_COMPLETED_DIR=""
while [ $# -gt 0 ]; do
    case "$1" in
        -h|--help)
            cat <<EOT
usage:

    $0 {options} <SOLVENT-LIST> ..

  options:

    -h, --help              show this help text
    -v                      increase information printed by job-templating-tool
    -D, --completed-dir <directory>
                            directory containing completed 1-gaseous job data
                            (default: $COMPLETED_DIR)

    One or more <SOLVENT-LIST> values should be provided, each being a
    comma-separated list of Gaussian SCRF solvent names:

        Water,Hexane,DiethylEther

    All other options are those that are understood by the available-chemicals
    program:

EOT
            ./available-chemicals --help
            exit 0
            ;;
        -+(v))
            VERBOSITY="$VERBOSITY $1"
            ;;
        --completed-dir=*)
            AVAILABLE_CHEMICALS_OPTS+=("$1")
            CHOSEN_COMPLETED_DIR="${1#--completed-dir=}"
            ;;
        -D|--completed-dir)
            AVAILABLE_CHEMICALS_OPTS+=("$1")
            if [ $# -eq 1 ]; then
                printf "ERROR:  no value provided with option %s\n" "$1" 1>&2
                exit 22
            fi
            shift
            AVAILABLE_CHEMICALS_OPTS+=("$1")
            CHOSEN_COMPLETED_DIR="${1}"
            ;;
        -s|--short-circuit)
            AVAILABLE_CHEMICALS_OPTS+=("$1")
            ;;
        --base-list=*)
            AVAILABLE_CHEMICALS_OPTS+=("$1")
            ;;
        -b|--base-list)
            AVAILABLE_CHEMICALS_OPTS+=("$1")
            if [ $# -eq 1 ]; then
                printf "ERROR:  no value provided with option %s\n" "$1" 1>&2
                exit 22
            fi
            shift
            AVAILABLE_CHEMICALS_OPTS+=("$1")
            ;;
        --exclude=*|--exclude-regex=*|--exclude-pattern=*)
            AVAILABLE_CHEMICALS_OPTS+=("$1")
            ;;
        -e|-r|-p|--exclude|--exclude-regex|--exclude-pattern)
            AVAILABLE_CHEMICALS_OPTS+=("$1")
            if [ $# -eq 1 ]; then
                printf "ERROR:  no value provided with option %s\n" "$1" 1>&2
                exit 22
            fi
            shift
            AVAILABLE_CHEMICALS_OPTS+=("$1")
            ;;
        --include=*|--include-regex=*|--include-pattern=*)
            AVAILABLE_CHEMICALS_OPTS+=("$1")
            ;;
        -i|-R|-P|--include|--include-regex|--include-pattern)
            AVAILABLE_CHEMICALS_OPTS+=("$1")
            if [ $# -eq 1 ]; then
                printf "ERROR:  no value provided with option %s\n" "$1" 1>&2
                exit 22
            fi
            shift
            AVAILABLE_CHEMICALS_OPTS+=("$1")
            ;;
        -l|-j|--name-list|--json-name-list)
            AVAILABLE_CHEMICALS_OPTS+=("$1")
            if [ $# -eq 1 ]; then
                printf "ERROR:  no value provided with option %s\n" "$1" 1>&2
                exit 22
            fi
            shift
            AVAILABLE_CHEMICALS_OPTS+=("$1")
            ;;
        --name-list=*|--json-name-list=*)
            AVAILABLE_CHEMICALS_OPTS+=("$1")
            ;;
        -*)
            echo "ERROR:  unknown command line flag:  $1"
            exit 22
            ;;
        *)
            if [ -z "$SOLVENTS" ]; then
                SOLVENTS="$1"
            else
                SOLVENTS="$SOLVENTS,$1"
            fi
            ;;
    esac
    shift
done

# Did we get a list of solvents?
if [ -z "$SOLVENTS" ]; then
    printf "ERROR:  no solvent names provided\n" 1>&2
    exit 1
fi

# Generate the list of CHEMICAL species:
CHEMICALS="$(./available-chemicals "${AVAILABLE_CHEMICALS_OPTS[@]}")"
if [ $? -ne 0 -o -z "$CHEMICALS" ]; then
    printf "ERROR:  no chemical species available in $COMPLETED_DIR\n" 1>&2
    exit 1
fi

# Job directory and catalog file:
JOBS_DIR="./jobs-$(date +%Y%m%d-%H%M)"
JOB_MAP_INDEX="${JOBS_DIR}/${CATALOG_FILENAME}"
JOB_OUTPUT_DIR="${JOBS_DIR}/output"
if [ -d "$JOBS_DIR" ]; then
    echo "ERROR:  the $JOBS_DIR directory is already present; please remove before running this script"
    exit 1
fi
if [ -d "$JOB_OUTPUT_DIR" ]; then
    echo "ERROR:  the $JOB_OUTPUT_DIR directory is already present; please remove before running this script"
    exit 1
fi
if [ -f "$JOB_MAP_INDEX" ]; then
    echo "ERROR:  the $JOB_MAP_INDEX file is already present; please remove before running this script"
    exit 1
fi

# Ensure the output directory exists for Slurm output files:
mkdir -p "$JOB_OUTPUT_DIR"

# Location of the templates directory relative to the JOBS_DIR we're using:
RELATIVE_TEMPLATES_DIR="$(realpath --relative-to="$JOBS_DIR" "./templates" 2>/dev/null)"
if [ $? -ne 0 ]; then
    printf "ERROR:  the ./templates directory could not be found\n" 1>&2
    exit 1
fi
if [ -n "$CHOSEN_COMPLETED_DIR" ]; then
    RELATIVE_CHOSEN_COMPLETED_DIR="$(realpath --relative-to="$JOBS_DIR" "$CHOSEN_COMPLETED_DIR" 2>/dev/null)"
    if [ $? -ne 0 -o -z "$RELATIVE_CHOSEN_COMPLETED_DIR" ]; then
        printf "ERROR:  the alternate completed calculations directory $CHOSEN_COMPLETED_DIR does not exist\n" 1>&2
        exit 1
    fi
fi

# Generate the job indices:
echo "* Job array will be generated in directory $JOBS_DIR"
cd "${JOBS_DIR}"
echo "* Generating job indices"
job-templating-tool -v $VERBOSITY \
	--catalog "./${CATALOG_FILENAME}" \
	--array-base-index 1 \
	--jobs-per-directory ${MAX_JOBS_PER_DIRECTORY:-40} \
	--prefix "./" \
	--parameter NPROC=${NPROC:-1} \
	--parameter MEM_PER_PROC=${MEM_PER_PROC:-2048} \
	--parameter CHEMICAL="$CHEMICALS" \
        --parameter SOLVENT="$SOLVENTS" \
	"${RELATIVE_TEMPLATES_DIR}"/{solvated.com,job.sh} 2>&1 | awk '{printf("    %s\n",$0);}'
if [ $? -eq 0 ]; then
    # Generate the job_array.qs script:
    echo "* Generating job_array.qs script"
    EXTRA_ARGS=()
    if [ -n "$RELATIVE_CHOSEN_COMPLETED_DIR" ]; then
        EXTRA_ARGS+=(--parameter CHOSEN_COMPLETED_DIR="$RELATIVE_CHOSEN_COMPLETED_DIR")
    fi
    job-templating-tool -v $VERBOSITY \
	    --use-flat-layout \
	    --index-format-in-paths="" \
            --prefix "./" \
            --parameter NPROC=${NPROC:-1} \
            --parameter MEM_PER_PROC=${MEM_PER_PROC:-2048} \
            --parameter ARRAY_INDEX_START=1 \
            --parameter ARRAY_INDEX_END="$(wc -l "./${CATALOG_FILENAME}" | awk '{print $1;}')" \
            "${EXTRA_ARGS[@]}" \
            "${RELATIVE_TEMPLATES_DIR}"/job_array.qs 2>&1 | awk '{printf("    %s\n",$0);}'
fi

