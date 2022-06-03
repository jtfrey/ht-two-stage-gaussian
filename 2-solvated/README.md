# Step 2:  Solvated Molecules

This directory contains files that implement a Slurm job array-based workflow for optimizing and calculating final vibrational frequencies for the array of chemical species produced by Step 1 in a solvated SCRF model.

The Gaussian input file template that will be applied to each CHEMICAL and SOLVENT can be found in [templates/solvated.com](./templates/solvated.com).  This template references the `NPROC` and `MEM_PER_PROC` parameters, the `CHEMICAL` identity in the description, and the named Gaussian SCRF `SOLVENT`.  No molecular coordinates are included:  the checkpoint file for the CHEMICAL from Step 1 is copied to act as the starting-point for this Step.

The Bash script that executes the Gaussian calculation, checks for errors, and — if successful — copies the results up to the [../3-completed](../3-completed) directory is found in [templates/job.sh](./templates/job.sh).  That script makes use of the Unix `install` command's ability to backup existing files with unique suffixes to prevent the workflow from overwriting previous results for a CHEMICAL and SOLVENT.  Removal of (uniquely-renamed) deprecated results is left up to the user.  The script is also responsible for copying and renaming the CHEMICAL checkpoint file that will act as the input for this Step.


## Generating the Array

The [templating.sh](./templating.sh) script accepts several arguments:

```
$ ./templating.sh --help
usage:

    ./templating.sh {options} <SOLVENT-LIST> ..

  options:

    -h, --help              show this help text
    -v                      increase information printed by job-templating-tool

    --exclude <name>
    --exclude-regex <regex>
    --exclude-pattern <pattern>
                            options that are passed to the available-chemicals
                            program to omit certain species from the list

    One or more <SOLVENT-LIST> values should be provided, each being a
    comma-separated list of Gaussian SCRF solvent names:

        Water,Hexane,DimethylEther

```

The script looks in the [../3-completed](../3-completed) directory for CHEMICAL results:  a directory named CHEMICAL which contains a file named CHEMICAL.chk is indicative of a successful Step 1 calculation, e.g. `../3-completed/1245tetrabromobenzene_636-28-2/1245tetrabromobenzene_636-28-2.chk` would be considered for solvated calculations in this step.  


a single optional argument:  the directory containing `.xyz` files to be used.  If not provided, it defaults to the [chemicals](./chemicals) directory.  The [chemicals.test](./chemicals.test) directory contains single file — a carbon monoxide molecule — and the templating setup would be accomplished using

```
$ ./templating.sh -v ./chemicals.test
* Job array will be generated in directory ./jobs-20220602-1443
* Generating job indices
    [INFO] 2 input templates to process
    [INFO] added parameter CHEMICALS_DIR = ['../chemicals.test']
    [INFO] added parameter NPROC = [10]
    [INFO] added parameter MEM_PER_PROC = [2048]
    [INFO] added parameter CHEMICAL = ['carbon_monoxide']
    [INFO] total parameter combinations 1
    [INFO] will generate 2 file(s) in 1 indices
    [INFO] next job array index in sequence would be 2
* Generating job_array.qs script
    [INFO] 1 input templates to process
    [INFO] added parameter NPROC = [10]
    [INFO] added parameter MEM_PER_PROC = [2048]
    [INFO] added parameter ARRAY_INDEX_START = [1]
    [INFO] added parameter ARRAY_INDEX_END = [1]
    [INFO] total parameter combinations 1
    [INFO] will generate 1 file(s) in 1 indices
    [INFO] next job array index in sequence would be 2
```

Each time the `templating.sh` script is run, a unique job array hierarchy is created (according to the date, hour, and minute).  A `job_array.qs` script with the correct CPU count, requested memory size, and job array indices is created for easy submission of the array to Slurm.]

The job indices generation in the script emits a *catalog* file that maps each combination of parameters to the job directory and files created:

```
$ cd jobs-20220602-1443
$ cat job-map.index 
[1:./1] { "parameters": {"CHEMICAL":"carbon_monoxide","MEM_PER_PROC":2048,"CHEMICALS_DIR":"../chemicals.test","NPROC":10}, "files": ["./1/gaseous.com","./1/job.sh"] }
```

Job index 1 uses subdirectory `./1` and is associated with the `carbon_monoxide` CHEMICAL.  Two files were generated from templates — the Gaussian input file and the computational script:

```
$ ls -l ./1
total 21
-rw-r--r-- 1 frey it_nss  215 Jun  2 14:43 gaseous.com
-rwxr-xr-x 1 frey it_nss 1737 Jun  2 14:43 job.sh
```

> PLEASE NOTE:  The name of the catalog file is taken from the value of the `CATALOG_FILENAME` variable defined in the [../config.sh](../config.sh) file.  It defaults to `job-map.index`, which is what will be cited in this documentation.


### Gaussian Input File

The gas-phase calculation input for the job includes the templated header and the coordinates from [chemicals.test/carbon_monoxide.xyz](./chemicals.test/carbon_monoxide.xyz):

```
$ cat ./1/gaseous.com 
%chk=carbon_monoxide.chk
%nproc=10
%mem=19456MB
#p nosymm M062x/aug-cc-pVDZ opt(maxcyc=800) Volume iop(6/45=1000) freq

carbon_monoxide - gas phase optimization

0 1
C    0.0    0.0    0.0
O    0.0    0.0    1.44


```


### Computational Script

Note that the templated files retain their original names, `gaseous.com` and `job.sh`.  The computational script begins by renaming the `gaseous.com` file using the CHEMICAL name.  It sets `GAUSS_SCRDIR` and executes the gas-phase calculation.  If a zero return code results, it is assumed the job ran properly.

Whether or not the job produced usable results is then checked.  This is accomplished in a Bash function named `check_gaussian_output()` that can be found in the [templates/job.sh](./templates/job.sh) script template.  As of the authoring of this document, that Bash function implements the following tests:

1. Ensure the `.log` file exists
2. Ensure the `.chk` file exists (the solvated calculations will need it!)
3. Ensure the `.log` file ends with the usual "Normal termination of Gaussian" text
4. Ensure the `.log` file indicates that a stationary point was found

> PLEASE NOTE:  additional on-the-fly tests of the Gaussian output can be added to the `check_gaussian_output()` function by the user but will only be applied in job arrays generated thereafter.

If all tests are passed, the script copies the `.com`, `.log`, and `.chk` files into the workflow's [../3-completed](../3-completed) directory (where solvated job arrays can find gas-phase results).  The copying is effected using the Unix `install` command so that any existing output files in the [../3-completed](../3-completed) directory are renamed rather than being overwritten.



## The Array Job

The `templating.sh` script emits an appropriately-configured `job_array.qs` script for the array in the base of the generated directory — in our example above, `jobs-20220602-1443`.

Each sub-job will have a unique job index, found in the `$SLURM_ARRAY_TASK_ID` environment variable set for the job by Slurm.  This integer value dictates what work the sub-job should do:  in this case, it equates with a specific subdirectory containing `gaseous.com` and `job.sh` templated files.  Each job index begins by looking-up the working directory in which to run:  it does this using the `$SLURM_ARRAY_TASK_ID` to locate the matching line in the mapping file, `job-map.index`.  From there, it changes into that directory (e.g. for `$SLURM_ARRAY_TASK_ID` of 1, `./1`) and creates a symbolic link to its Slurm output file (for ease of reference).  Finally, the templated `job.sh` script therein (which runs the Gaussian calculations, etc.) is executed.


### Submitting the Job

The `job_array.qs` is submitted quite simply using `sbatch`:

```
$ cd jobs-20220602-1443
$ sbatch job_array.qs
Submitted batch job 13753296
```

The job array appears in `squeue` output as a base job id, an underscore, and a job index, e.g. `13742533_1`:

```
$ squeue --user=frey
             JOBID PARTITION     NAME     USER ST       TIME  NODES NODELIST(REASON)
      13753296_[1]  standard gas_phas     frey PD       0:00      1 (None)

 ...wait a minute...

$ squeue --user=frey
             JOBID PARTITION     NAME     USER ST       TIME  NODES NODELIST(REASON)
        13753296_1  standard gas_phas     frey  R       0:05      1 r01n42
```

Any pending job indices will be listed with the index range visible, as in the range `[1]` above.
