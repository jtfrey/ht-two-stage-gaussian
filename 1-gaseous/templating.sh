#!/bin/bash
#
# This script is used to generate a CHEMICAL job array hierarchy.
# For all coordinate fragment files present under the chemicals/
# subdirectory, generate a job from the gaseous.com and job.sh files
# in the templates/ subdirectory.
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
CHOSEN_COMPLETED_DIR=""
while [ $# -gt 0 ]; do
    case "$1" in
        -h|--help)
            cat <<EOT
usage:

    $0 {options} {<CHEMICALS_DIR>}

  options:

    -h, --help              show this help text
    -v                      increase information printed by job-templating-tool
    -D, --completed-dir <directory>
                            directory containing completed 1-gaseous job data
                            (default: $COMPLETED_DIR)

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
            CHOSEN_COMPLETED_DIR="${1#--completed-dir=}"
            ;;
        -D|--completed-dir)
            if [ $# -eq 1 ]; then
                printf "ERROR:  no value provided with option %s\n" "$1" 1>&2
                exit 22
            fi
            shift
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
            CHEMICALS_DIR="$1"
            ;;
    esac
    shift
done

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

# Generate the list of CHEMICAL species:
CHEMICALS="$(./available-chemicals -C "$CHEMICALS_DIR" "${AVAILABLE_CHEMICALS_OPTS[@]}")"
if [ $? -ne 0 -o -z "$CHEMICALS" ]; then
    printf "ERROR:  no chemical species available in $COMPLETED_DIR\n" 1>&2
    exit 1
fi

# Ensure the output directory exists for Slurm output files:
mkdir -p "$JOB_OUTPUT_DIR"

# Location of the templates and chemicals directories relative to the
# JOBS_DIR we're using:
RELATIVE_TEMPLATES_DIR="$(realpath --relative-to="$JOBS_DIR" "./templates" 2>/dev/null)"
if [ $? -ne 0 ]; then
    printf "ERROR:  the ./templates directory could not be found\n" 1>&2
    exit 1
fi
RELATIVE_CHEMICALS_DIR="$(realpath --relative-to="$JOBS_DIR" "$CHEMICALS_DIR" 2>/dev/null)"
if [ $? -ne 0 ]; then
    printf "ERROR:  the $CHEMICALS_DIR directory could not be found\n" 1>&2
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
    --parameter CHEMICALS_DIR="$RELATIVE_CHEMICALS_DIR" \
	--parameter NPROC=${NPROC:-1} \
	--parameter MEM_PER_PROC=${MEM_PER_PROC:-2048} \
	--parameter CHEMICAL="$CHEMICALS" \
	"${RELATIVE_TEMPLATES_DIR}"/{gaseous.com,job.sh} 2>&1 | awk '{printf("    %s\n",$0);}'
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
            --parameter CHEMICALS_DIR="$RELATIVE_CHEMICALS_DIR" \
            --parameter NPROC=${NPROC:-1} \
            --parameter MEM_PER_PROC=${MEM_PER_PROC:-2048} \
            --parameter ARRAY_INDEX_START=1 \
            --parameter ARRAY_INDEX_END="$(wc -l "./${CATALOG_FILENAME}" | awk '{print $1;}')" \
            "${EXTRA_ARGS[@]}" \
            "${RELATIVE_TEMPLATES_DIR}"/job_array.qs 2>&1 | awk '{printf("    %s\n",$0);}'
fi

