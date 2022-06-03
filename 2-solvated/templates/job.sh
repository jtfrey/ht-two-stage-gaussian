#!/bin/bash -l
#
# This is NOT a Slurm job script!  It is a template for the computational script
# that will be generated for each job array index and executed by the job_array.qs
# job script when the array is submitted for execution.
#

#
# This is a Bash function that is given two arguments:
#   - the .log file path
#   - the .chk file path
# It's job is to check a completed calculation for proper completion.
# It should return a zero value if all is okay, non-zero otherwise.
# Feel free to modify with additional criteria!
#
function check_gaussian_output()
{
    local log_file="$1" chk_file="$2"

    # Make sure the log file exists!
    if [ ! -f "$log_file" ]; then
        echo "ERROR:  no $log_file present"
        return 1
    fi

    # Make sure the chk file exists!
    if [ ! -f "$chk_file" ]; then
        echo "ERROR:  no $chk_file present"
        return 1
    fi

    # Check if the log file ends with the "Normal termination" string:
    tail -5 "$log_file" | grep "Normal termination of Gaussian" 1>/dev/null 2>/dev/null
    if [ $? -ne 0 ]; then
        echo "ERROR:  $log_file does not indicate normal termination in footer"
        return 1
    fi

    # At least one stationary point identified?
    grep "Stationary point found" "$log_file" >/dev/null 2>/dev/null
    if [ $? -ne 0 ]; then
        echo "ERROR:  $log_file does not indicate a stationary point was found"
        return 1
    fi

    return 0
}

# Add Gaussian '16 to the runtime environment:
vpkg_require gaussian/g16c01

# Setup for OpenMP, but we don't want to check the input file et al.
# That means we need to set GAUSS_SCRDIR ourself, too:
. /opt/shared/slurm/templates/libexec/openmp.sh
export GAUSS_SCRDIR="$TMPDIR"

# We'll use two env vars for the base of the gaseous and solvated file names
# (versus doing templated replacement of e.g. CHEMICAL in many locations herein):
GASEOUS_BASENAME="[{% print(CHEMICAL) %}]"
SOLVATED_BASENAME="[{% print('{:s}_{:s}'.format(CHEMICAL,SOLVENT.replace(',','_').replace('-','_').replace(' ',''))) %}]"

# Rename the templated "solvated.com" file:
mv "solvated.com" "${SOLVATED_BASENAME}.com"

# Copy the gas-phase checkpoint file:
cp "${COMPLETED_DIR}/${GASEOUS_BASENAME}/${GASEOUS_BASENAME}.chk" "${SOLVATED_BASENAME}.chk"
if [ $? -ne 0 ]; then
    printf "ERROR:  unable to copy the ${GASEOUS_BASENAME}.chk file from ${COMPLETED_DIR}/${GASEOUS_BASENAME}\n" 1>&2
    exit 1
fi

# Run solvated calculation:
g16 < "${SOLVATED_BASENAME}.com" > "${SOLVATED_BASENAME}.log"
gaussian_rc=$?

# Did the job complete successfully?
if [ $gaussian_rc -eq 0 ]; then
    # At this point, if there are any automated checks of the calculation results that you'd like to perform
    # they should be done here:
    check_gaussian_output "${SOLVATED_BASENAME}.log" "${SOLVATED_BASENAME}.chk"
    gaussian_rc=$?
    if [ $gaussian_rc -eq 0 ]; then
        COMPLETED_SOLVATED_DIR="${COMPLETED_DIR}/${GASEOUS_BASENAME}/[{% print(SOLVENT) %}]"
        # Create the completed directory if necessary:
        mkdir -p "${COMPLETED_SOLVATED_DIR}"
        gaussian_rc=$?
        if [ $gaussian_rc -ne 0 ]; then
            printf "ERROR:  failed to create completed directory $COMPLETED_SOLVATED_DIR (rc = $gaussian_rc)\n" 1>&2
        else
            # Use install to copy the outputs to the completed directory, making backups if necessary:
            install --backup=numbered --target-directory="$COMPLETED_SOLVATED_DIR" "${SOLVATED_BASENAME}".{com,log,chk}
            gaussian_rc=$?
            if [ $gaussian_rc -ne 0 ]; then
                printf "ERROR:  unable to copy completed files to $COMPLETED_SOLVATED_DIR (rc = $gaussian_rc)\n" 1>&2
            fi
        fi
    fi
fi
exit $gaussian_rc

