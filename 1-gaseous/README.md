# Step 1:  Gas-Phase Discrete Molecule

This directory contains files that implement a Slurm job array-based workflow for optimizing and calculating final vibrational frequencies for an array of chemical species.

The charge/multiplicity and atomic coordinates for each of the discrete molecules (hereafter denoted as CHEMICAL) are stored in files under the [chemicals](./chemicals) directory, with the molecule name followed by the `.xyz` extension.

The Gaussian input file template that will be applied to each CHEMICAL can be found in [templates/gaseous.com](./templates/gaseous.com).  This template references the `NPROC` and `MEM_PER_PROC` parameters, the `CHEMICAL` identity in the description, and imports the `.xyz` coordinates for the molecule from the `CHEMICALS_DIR/CHEMICAL.xyz` file.

The Bash script that executes the Gaussian calculation, checks for errors, and — if successful — copies the results up to the [../3-completed](../3-completed) directory is found in [templates/job.sh](./templates/job.sh).  That script makes use of the Unix `install` command's ability to backup existing files with unique suffixes to prevent the workflow from overwriting previous results for a CHEMICAL.  Removal of (uniquely-renamed) deprecated results is left up to the user.


## Generating the Array

The templating setup is accomplished using

```
$ ./templating.sh -v
* Job array will be generated in directory ./jobs-20220603-1557
* Generating job indices
    [INFO] 2 input templates to process
    [INFO] added parameter CHEMICALS_DIR = ['../../0-chemicals']
    [INFO] added parameter NPROC = [10]
    [INFO] added parameter MEM_PER_PROC = [2048]
    [INFO] added parameter CHEMICAL = ['CarbonMonoxide']
    [INFO] total parameter combinations 1
    [INFO] will generate 2 file(s) in 1 indices
    [INFO] next job array index in sequence would be 2
* Generating job_array.qs script
    [INFO] 1 input templates to process
    [INFO] added parameter CHEMICALS_DIR = ['../../0-chemicals']
    [INFO] added parameter NPROC = [10]
    [INFO] added parameter MEM_PER_PROC = [2048]
    [INFO] added parameter ARRAY_INDEX_START = [1]
    [INFO] added parameter ARRAY_INDEX_END = [1]
    [INFO] total parameter combinations 1
    [INFO] will generate 1 file(s) in 1 indices
    [INFO] next job array index in sequence would be 2
```

Each time the `templating.sh` script is run, a unique job array hierarchy is created (according to the date, hour, and minute).  A `job_array.qs` script with the correct CPU count, requested memory size, and job array indices is created for easy submission of the array to Slurm.

The job indices generation in the script emits a *catalog* file that maps each combination of parameters to the job directory and files created:

```
$ cd jobs-20220602-1443
$ cat job-map.index 
[1:./1] { "parameters": {"CHEMICAL":"CarbonMonoxide","MEM_PER_PROC":2048,"CHEMICALS_DIR":"../../0-chemicals","NPROC":10}, "files": ["./1/gaseous.com","./1/job.sh"] }
```

Job index 1 uses subdirectory `./1` and is associated with the `CarbonMonoxide` CHEMICAL.  Two files were generated from templates — the Gaussian input file and the computational script:

```
$ ls -l ./1
total 21
-rw-r--r-- 1 frey it_nss  215 Jun  2 14:43 gaseous.com
-rwxr-xr-x 1 frey it_nss 1737 Jun  2 14:43 job.sh
```

> PLEASE NOTE:  The name of the catalog file is taken from the value of the `CATALOG_FILENAME` variable defined in the [../config.sh](../config.sh) file.  It defaults to `job-map.index`, which is what will be cited in this documentation.


### Gaussian Input File

The gas-phase calculation input for the job includes the templated header and the coordinates from [../0-chemicals/CarbonMonoxide.xyz](../0-chemicals/CarbonMonoxide.xyz):

```
$ cat ./1/gaseous.com 
%chk=CarbonMonoxide.chk
%nproc=10
%mem=19456MB
#p nosymm M062x/aug-cc-pVDZ opt(maxcyc=800) Volume iop(6/45=1000) freq

CarbonMonoxide - gas phase optimization

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
