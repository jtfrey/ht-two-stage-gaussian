# Step 2:  Solvated Molecules

This directory contains files that implement a Slurm job array-based workflow for optimizing and calculating final vibrational frequencies for the array of chemical species produced by Step 1 in a solvated SCRF model.

The Gaussian input file template that will be applied to each CHEMICAL and SOLVENT can be found in [templates/solvated.com](./templates/solvated.com).  This template references the `NPROC` and `MEM_PER_PROC` parameters, the `CHEMICAL` identity in the description, and the named Gaussian SCRF `SOLVENT`.  No molecular coordinates are included:  the completed checkpoint file for CHEMICAL from Step 1 is copied to act as the starting-point for this Step.

The Bash script that executes the Gaussian calculation, checks for errors, and — if successful — copies the results up to the [../3-completed](../3-completed) directory is found in [templates/job.sh](./templates/job.sh).  That script makes use of the Unix `install` command's ability to backup existing files with unique suffixes to prevent the workflow from overwriting previous results for a CHEMICAL and SOLVENT.  Removal of (uniquely-renamed) deprecated results is left up to the user.  The script is also responsible for copying and renaming the completed CHEMICAL checkpoint file that will act as the input for this Step.


## Generating the Array

The templating setup for this step by default makes use of all properly-completed step-1 calcuations.  A *properly completed* step-1 calculation will:

1. Have a directory present under [../3-completed/<CHEMICAL>](../3-completed/<CHEMICAL>)
2. Have a checkpoint file under that directory, e.g. [../3-completed/<CHEMICAL>/<CHEMICAL>.chk](../3-completed/<CHEMICAL>/<CHEMICAL>.chk)

If these two conditions are met, the CHEMICAL will by default be included in step 2.

> **NOTE:** there are options you can pass to the `./templating.sh` script to exclude/include CHEMICAL species by name.  For example, to only include the CHEMCIAL species named "CarbonMonoxide" and "Water" in a step-2 job array, the `--base-list=none --include=CarbonMonoxide,Water` options can be used.  On the other hand, to exclude from the full set of completed step-1 calculations any CHEMICAL species with a name containing the word "chloro," the options would be `--base-list=all --exclude-regex=[Cc]hloro` (since only the capitalization of the "C" varies in CHEMICAL species associated with Olga's `STL_1` work).

The other information needed by the step-2 templating is the SOVLENT list.  A comma-separated list of [Gaussian SCRF solvents](http://gaussian.com/scrf/?tabid=7) is needed:

```
$ ./templating.sh -v Water,DiethylEther
* Job array will be generated in directory ./jobs-20220606-0941
* Generating job indices
    [INFO] 2 input templates to process
    [INFO] added parameter NPROC = [10]
    [INFO] added parameter MEM_PER_PROC = [2048]
    [INFO] added parameter CHEMICAL = ['CarbonMonoxide']
    [INFO] added parameter SOLVENT = ['Water', 'DiethylEther']
    [INFO] total parameter combinations 2
    [INFO] will generate 4 file(s) in 2 indices
    [INFO] next job array index in sequence would be 3
* Generating job_array.qs script
    [INFO] 1 input templates to process
    [INFO] added parameter NPROC = [10]
    [INFO] added parameter MEM_PER_PROC = [2048]
    [INFO] added parameter ARRAY_INDEX_START = [1]
    [INFO] added parameter ARRAY_INDEX_END = [2]
    [INFO] total parameter combinations 1
    [INFO] will generate 1 file(s) in 1 indices
    [INFO] next job array index in sequence would be 2
```

Gaussian honors any capitalization of the solvent name (it is not case-sensitive) but the Unix file system **is** case-sensitive:  to avoid confusion, choose to either:

- Uppercase all letters in solvent names (e.g. WATER, DIETHYLETHER)
- Lowercase all letters in solvent names (e.g. water, diethylether)
- Use the canonical capitalization established by Gaussian on the cited SCRF reference page (e.g. Water, DiethylEther)

Each time the `templating.sh` script is run, a unique job array hierarchy is created (according to the date, hour, and minute).  A `job_array.qs` script with the correct CPU count, requested memory size, and job array indices is created for easy submission of the array to Slurm.

The job indices generation in the script emits a *catalog* file that maps each combination of parameters to the job directory and files created:

```
$ cd jobs-20220606-0941
$ cat job-map.index 
[1:./1] { "parameters": {"CHEMICAL":"CarbonMonoxide","SOLVENT":"Water","MEM_PER_PROC":2048,"NPROC":10}, "files": ["./1/solvated.com","./1/job.sh"] }
[2:./2] { "parameters": {"CHEMICAL":"CarbonMonoxide","SOLVENT":"DiethylEther","MEM_PER_PROC":2048,"NPROC":10}, "files": ["./2/solvated.com","./2/job.sh"] }
```

The `CarbonMonoxide` CHEMICAL is associated with both jobs — it is the only CHEMICAL species present in these examples.  Job index 1 uses subdirectory `./1` and is associated with the `Water` SOLVENT.  Two files were generated from templates — the Gaussian input file and the computational script:

```
$ ls -l ./1
total 21
-rwxr-xr-x 1 frey it_nss 3621 Jun  6 09:41 job.sh
-rw-r--r-- 1 frey it_nss  222 Jun  6 09:41 solvated.com
```

> PLEASE NOTE:  The name of the catalog file is taken from the value of the `CATALOG_FILENAME` variable defined in the [../config.sh](../config.sh) file.  It defaults to `job-map.index`, which is what will be cited in this documentation.


### Gaussian Input File

The gas-phase calculation input for the job includes the templated header and the coordinates from [../0-chemicals/CarbonMonoxide.xyz](../0-chemicals/CarbonMonoxide.xyz):

```
$ cat ./1/solvated.com 
%chk=CarbonMonoxide_Water.chk
%nproc=10
%mem=19456MB
#p nosymm M062x/aug-cc-pVDZ opt(maxcyc=200) Volume iop(6/45=1000) Geom=AllCheck Guess=Read SCRF=(SMD,Solvent=Water) freq

CarbonMonoxide - Water-solvated optimization


```

Note the checkpoint file referenced is the combination of the CHEMICAL name and SOLVENT name — we will refer to this name as CHEMICAL+SOLVENT in the remainder of this document.


### Computational Script

Note that the templated files retain their original names, `solvated.com` and `job.sh`.  The computational script begins by renaming the `solvated.com` file using the CHEMICAL+SOLVENT name.  It sets `GAUSS_SCRDIR` and executes the solvated calculation.  If a zero return code results, it is assumed the job ran properly.

Whether or not the job produced usable results is then checked.  This is accomplished in a Bash function named `check_gaussian_output()` that can be found in the [templates/job.sh](./templates/job.sh) script template.  As of the authoring of this document, that Bash function implements the following tests:

1. Ensure the `.log` file exists
2. Ensure the `.chk` file exists (the solvated calculations will need it!)
3. Ensure the `.log` file ends with the usual "Normal termination of Gaussian" text
4. Ensure the `.log` file indicates that a stationary point was found

> PLEASE NOTE:  additional on-the-fly tests of the Gaussian output can be added to the `check_gaussian_output()` function by the user but will only be applied in job arrays generated thereafter.

If all tests are passed, the script copies the `.com`, `.log`, and `.chk` files into the workflow's [../3-completed/<CHEMICAL>/<SOLVENT>](../3-completed/<CHEMICAL>/<SOLVENT>) directory.  The copying is effected using the Unix `install` command so that any existing output files in the [../3-completed/<CHEMICAL>/<SOLVENT>](../3-completed/<CHEMICAL>/<SOLVENT>) directory are renamed rather than being overwritten.


## The Array Job

The `templating.sh` script emits an appropriately-configured `job_array.qs` script for the array in the base of the generated directory — in our example above, `jobs-20220606-0941`.

Each sub-job will have a unique job index, found in the `$SLURM_ARRAY_TASK_ID` environment variable set for the job by Slurm.  This integer value dictates what work the sub-job should do:  in this case, it equates with a specific subdirectory containing `solvated.com` and `job.sh` templated files.  Each job index begins by looking-up the working directory in which to run:  it does this using the `$SLURM_ARRAY_TASK_ID` to locate the matching line in the mapping file, `job-map.index`.  From there, it changes into that directory (e.g. for `$SLURM_ARRAY_TASK_ID` of 1, `./1`) and creates a symbolic link to its Slurm output file (for ease of reference).  Finally, the templated `job.sh` script therein (which runs the Gaussian calculations, etc.) is executed.


### Submitting the Job

The `job_array.qs` is submitted quite simply using `sbatch`:

```
$ cd jobs-20220602-1443
$ sbatch job_array.qs
Submitted batch job 13772053
```

The job array appears in `squeue` output as a base job id, an underscore, and a job index, e.g. `13772053_1`:

```
$ squeue --job=13772053
               JOBID PARTITION     NAME     USER ST       TIME  NODES NODELIST(REASON)
      13772053_[1-2]  standard gas_phas     frey PD       0:00      1 (None)

 ...wait a minute...

$ squeue --job=13772053
             JOBID PARTITION     NAME     USER ST       TIME  NODES NODELIST(REASON)
        13772053_1  standard solvated     frey  R       0:08      1 r00n24
        13772053_2  standard solvated     frey  R       0:08      1 r04n48
```

Any pending job indices will be listed with the index range visible, as in the range `[1-2]` above.
