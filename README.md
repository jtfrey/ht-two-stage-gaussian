# Solvation Study Workflow

This directory contains files that implement a Slurm job array-based workflow for studying large-scale combinations of computational parameters.  In this case, the combinations of a discrete molecule ("chemical") and multiple solvents are to be studied.

The generation of job array hierarchies makes use of the [job-templating-tool](https://github.com/jtfrey/job-templating-tool) utility.


## Getting Started

The workflow described herein is made available as a git revision-controlled repository with its origin in the Github cloud.  For each project on which you wish to work, it is recommended that you create a new copy of this directory hierarchy on Caviness or DARWIN.

> **NOTE**:  Before proceeding, be sure you have entered your desired cluster workgroup using the `workgroup` command.

First, choose a name for the directory, likely related to the project in question:  for the sake of example, let's say `STL-2`.  I want to store this project in `${WORKDIR}/users/frey/solvation/STL-2`.  The initial directory hierarchy is pulled from Github to populate that directory using the `git` command:

```
$ git clone https://github.com/jtfrey/ht-two-stage-gaussian.git ${WORKDIR}/users/frey/solvation/STL-2
Cloning into '/work/it_nss/users/frey/solvation/STL-2'...
remote: Enumerating objects: 37, done.
remote: Counting objects: 100% (37/37), done.
remote: Compressing objects: 100% (25/25), done.
remote: Total 37 (delta 12), reused 33 (delta 10), pack-reused 0
Receiving objects: 100% (37/37), 21.38 KiB | 3.05 MiB/s, done.
Resolving deltas: 100% (12/12), done.
```

The structure of the directory can easily be confirmed:

```
$ cd ${WORKDIR}/users/frey/solvation/STL-2

$ ls -l
total 48
drwxr-xr-x  3 frey  it_nss     96 Jun  6 09:04 0-chemicals
drwxr-xr-x  9 frey  it_nss    288 Jun  6 09:04 1-gaseous
drwxr-xr-x  9 frey  it_nss    288 Jun  6 09:04 2-solvated
drwxr-xr-x  9 frey  it_nss     96 Jun  6 09:04 3-completed
-rw-r--r--  1 frey  it_nss   1355 Jun  6 09:04 LICENSE
-rw-r--r--  1 frey  it_nss  14076 Jun  6 09:04 README.md
-rw-r--r--  1 frey  it_nss    940 Jun  6 09:04 config.sh
```


## Configuration

The workflow uses the [config.sh](./config.sh) file to provide global defintions of some critical parameters:

- The `NPROC` value is used throughout the workflow where the number of CPU cores for a job index is required
- The `MEM_PER_PROC` value (an integer understood to be in megabytes and without any unit) is used for all memory sizing requests/options throughout the workflow
- The `WORKFLOW_DIR` is the absolute path to the top level of this workflow hierarchy
- The `GASEOUS_DIR` is the absolute path to the gas-phase portion of the workflow
- The `SOLVATED_DIR` is the absolute path to the solvated portion of the workflow
- The `COMPLETED_DIR` is the absolute path to the directory where completed gas-phase and solvated results will be copied
- The `CATALOG_FILENAME` is the name of the job mapping index file that associates selected templating parameters with index and directory
- The `MAX_JOBS_PER_DIRECTORY` is the maximum number of directories the job-templating-tool will create at each level of a job array

While the values of `NPROC` and `MEM_PER_PROC` may require modification, the rest of the variables are unlikely to need modification and doing so can render the workflow unusable ??? so be cautious!


## Step 0:  Species of Interest

The workflow begins with providing one or more molecular coordinate files for the chemical species to be studied.  Each file must be named with the CHEMICAL name and a `.xyz` suffix:

```
$ pushd 0-chemicals

$ ls -l
total 1
-rw-r--r-- 1 frey it_nss 52 Jun  2 14:12 CarbonMonoxide.xyz

$ cat CarbonMonoxide.xyz
0 1
C    0.0    0.0    0.0
O    0.0    0.0    1.44

$ popd
```

In this case, the CHEMICAL name is `CarbonMonoxide` and is the only file present.  Since file names on Unix systems are case-sensitive, CHEMICAL names are also case-sensitive:  `CarbonMonoxide` and `carbonmonoxide` are distinct names.

Remove the `CarbonMonoxide.xyz` file then copy all your desired `.xyz` files into the [0-chemicals](./0-chemicals) directory before proceeding to the next step.


## Step 1:  Gas-phase Optimization

With a set of CHEMICAL species prepared, the gas-phase discrete molecule energetics must be calculated for each.  This entails a Gaussian optimization from the initial geometry followed by computation of vibrational frequencies for the sake of free energies, etc.

The `1-gaseous` directory contains the infrastructure for this step of the workflow.  The `./available-chemicals` script (and its implementation in `available-chemicals.py`) is responsible for indentifying the CHEMICAL species to be studied.  By default, it looks in the [0-chemicals](./0-chemicals) directory for all `.xyz` files and drops the `.xyz` suffix to leave just the CHEMICAL name.

The `./templating.sh` script is responsible for producing a Slurm job array for a set of CHEMICAL names.  The names are generated by its executing the `./available-chemicals` script, so the first thing to do is check what CHEMICAL names are detected:

```
$ pushd 1-gaseous
$ ./available-chemicals 
CarbonMonoxide
```

This correlates with the fact that the workflow comes with the single file [0-chemicals/CarbonMonoxide.xyz](./0-chemicals/CarbonMonoxide.xyz).  Check the output of `./available-chemicals` to confirm that the list of CHEMICAL names agrees with expectation.

Generate a job array for the list of CHEMICAL names using the `./templating.sh` script:

```
$ ./templating.sh
* Job array will be generated in directory ./jobs-20220603-1604
* Generating job indices
* Generating job_array.qs script

$ ls -l ./jobs-20220603-1604
total 22
drwxr-xr-x 2 frey it_nss    4 Jun  3 16:04 1
-rw-r--r-- 1 frey it_nss 1148 Jun  3 16:04 job_array.qs
-rw-r--r-- 1 frey it_nss  166 Jun  3 16:04 job-map.index
drwxr-xr-x 2 frey it_nss    2 Jun  3 16:04 output
```

The individual job index directories (in this case, `./jobs-20220603-1604/1`) can be examined, the `job-map.index` and `job_array.qs` files checked, etc.  When the job array is ready for execution, submit it to Slurm:

```
$ pushd ./jobs-20220603-1604
$ sbatch job_array.qs
Submitted batch job 13758353

$ squeue --job=13758353
             JOBID PARTITION     NAME     USER ST       TIME  NODES NODELIST(REASON)
      13758353_[1]  standard gas_phas     frey PD       0:00      1 (None)
      
 ??? wait a few seconds ???  
    
$ squeue --job=13758353
             JOBID PARTITION     NAME     USER ST       TIME  NODES NODELIST(REASON)
        13758353_1  standard gas_phas     frey  R       0:04      1 r01n22
```

As the job indices complete, successful calculations will have their results archived to the [3-completed](./3-completed) directory using the CHEMICAL name as the name of the per-chemical subdirectory:

```
$ popd ; popd
$ ls -l 3-completed
total 1
drwxr-xr-x 2 frey it_nss 5 Jun  3 16:07 CarbonMonoxide

$ ls -l 3-completed/CarbonMonoxide
total 219
-rwxr-xr-x 1 frey it_nss 2097152 Jun  3 16:07 CarbonMonoxide.chk
-rwxr-xr-x 1 frey it_nss     213 Jun  3 16:07 CarbonMonoxide.com
-rwxr-xr-x 1 frey it_nss  117735 Jun  3 16:07 CarbonMonoxide.log
```

With the gas-phase calculation completed, the workflow can proceed to the next step.

### For the Expert

The `available-chemicals` script does have far more functionality available:

- CHEMICAL names and name patterns can be excluded/included from the list
- The list can be pulled from a text file (one CHEMICAL name per line) rather than by scanning the `../0-chemicals` directory for names

The command has built-in help that describes the available options in detail:

```
$ pushd 1-gaseous
$ ./available-chemicals --help
usage: available-chemicals.py [-h] [--format {csv,lines,json}]
                              [--base-list {all,none}] [--short-circuit]
                              [--chemicals-dir <directory>] [--exclude <name>]
                              [--exclude-regex <regular-expression>]
                              [--exclude-pattern <glob-pattern>]
                              [--include <name>]
                              [--include-regex <regular-expression>]
                              [--include-pattern <glob-pattern>]
                              [--name-list <file>]
                              [--json-name-list <json-file>]
                                   :
```

All of these options can also be passed to the `./templating.sh` script, and it will use them when it invokes `./available-chemicals` to generate the CHEMICAL name list.

Additional detailed discussion of this workflow step can be found in the [1-gaseous/README.md](./1-gaseous/README.md) file.


## Step 2:  Solvated Optimization

With a set of processed CHEMICAL species archived in [3-completed](./3-completed), the solvated molecule energetics can be calculated for one or more solvent species.  This entails a Gaussian SCRF optimization from the optimized gas-phase geometry followed by computation of vibrational frequencies for the sake of free energies, etc.

The `2-solvated` directory contains the infrastructure for this step of the workflow.  The `./available-chemicals` script (and its implementation in `available-chemicals.py`) is responsible for indentifying the CHEMICAL species to be studied.  By default, it looks in the [3-completed](./3-completed) directory for all directories that contain an appropriately-named `.chk` file, e.g. [3-completed/CarbonMonoxide/CarbonMonoxide.chk](./3-completed/CarbonMonoxide/CarbonMonoxide.chk).

The `./templating.sh` script is responsible for producing a Slurm job array for a set of CHEMICAL names.  The names are generated by its executing the `./available-chemicals` script, so the first thing to do is check what CHEMICAL names are detected:

```
$ pushd 2-solvated
$ ./available-chemicals 
CarbonMonoxide
```

This correlates with the fact that step 1 above successfully ran the optimization of CarbonMonoxide and archived the results under [3-completed](./3-completed).  Check the output of `./available-chemicals` to confirm that the list of CHEMICAL names agrees with expectation.

Generate a job array for the list of CHEMICAL names and a list of named Gaussian SCRF solvents using the `./templating.sh` script:

```
$ ./templating.sh Water DimethylEther
* Job array will be generated in directory ./jobs-20220603-1617
* Generating job indices
* Generating job_array.qs script

$ ls -l ./jobs-20220603-1617
total 23
drwxr-xr-x 2 frey it_nss    4 Jun  3 16:17 1
drwxr-xr-x 2 frey it_nss    4 Jun  3 16:17 2
-rw-r--r-- 1 frey it_nss 1147 Jun  3 16:17 job_array.qs
-rw-r--r-- 1 frey it_nss  306 Jun  3 16:17 job-map.index
drwxr-xr-x 2 frey it_nss    2 Jun  3 16:17 output
```

The individual job index directories (in this case, `./jobs-20220603-1617/1` and `./jobs-20220603-1617/2`) can be examined, the `job-map.index` and `job_array.qs` files checked, etc..  When the job array is ready for execution, submit it to Slurm:

```
$ pushd ./jobs-20220603-1617
$ sbatch job_array.qs
Submitted batch job 13758374

$ squeue --job=13758374
             JOBID PARTITION     NAME     USER ST       TIME  NODES NODELIST(REASON)
    13758374_[1-2]  standard solvated     frey PD       0:00      1 (None)
      
 ??? wait a few seconds ???  
    
$ squeue --job=13758374
             JOBID PARTITION     NAME     USER ST       TIME  NODES NODELIST(REASON)
        13758374_1  standard solvated     frey  R       0:01      1 r03n18
        13758374_2  standard solvated     frey  R       0:01      1 r03n19
```

As the job indices complete, successful calculations will have their results archived to the [3-completed](./3-completed) directory using the CHEMICAL name as the name of the per-chemical subdirectory, and a subdirectory will be created therein for each named SOLVENT:

```
$ popd ; popd
$ ls -l 3-completed
total 1
drwxr-xr-x 2 frey it_nss 5 Jun  3 16:07 CarbonMonoxide

$ ls -l 3-completed/CarbonMonoxide
total 219
-rwxr-xr-x 1 frey it_nss 2097152 Jun  3 16:07 CarbonMonoxide.chk
-rwxr-xr-x 1 frey it_nss     213 Jun  3 16:07 CarbonMonoxide.com
-rwxr-xr-x 1 frey it_nss  117735 Jun  3 16:07 CarbonMonoxide.log
drwxr-xr-x 2 frey it_nss       5 Jun  3 16:19 Water

$ ls -l 3-completed/CarbonMonoxide/Water
total 297
-rwxr-xr-x 1 frey it_nss 3145728 Jun  3 16:19 CarbonMonoxide_Water.chk
-rwxr-xr-x 1 frey it_nss     222 Jun  3 16:19 CarbonMonoxide_Water.com
-rwxr-xr-x 1 frey it_nss   62048 Jun  3 16:19 CarbonMonoxide_Water.log
```

We note one problem:  we asked for **two** solvents but only Water appears to have worked properly.  Let's go examine our job index for CarbonMonoxide in DimethylEther:

```
$ pushd 2-solvated
$ pushd jobs-20220603-1617
$ ../job-index-lookup --chemical=CarbonMonoxide --solvent=DimethylEther
./2

$ pushd ./2
$ ls -l
total 200
-rwxr-xr-x 1 frey it_nss 2097152 Jun  3 16:19 CarbonMonoxide_DimethylEther.chk
-rw-r--r-- 1 frey it_nss     246 Jun  3 16:17 CarbonMonoxide_DimethylEther.com
-rw-r--r-- 1 frey it_nss    4604 Jun  3 16:19 CarbonMonoxide_DimethylEther.log
-rwxr-xr-x 1 frey it_nss    3637 Jun  3 16:17 job.sh
lrwxrwxrwx 1 frey it_nss      30 Jun  3 16:19 slurm-13758374_2.out -> ../output/slurm-13758374_2.out

$ tail -10 CarbonMonoxide_DimethylEther.log
 ----------------------------------------------------------------------
 QPErr --- A syntax error was detected in the input line.
 llCheck Guess=Read SCRF=(SMD,Solvent=Dim
                              '
 Last state= "SCR2"
 TCursr=    177857 LCursr=       101
 Error termination via Lnk1e in /opt/shared/gaussian/g16c01/std/g16/l1.exe at Fri Jun  3 16:19:43 2022.
 Job cpu time:       0 days  0 hours  0 minutes  0.4 seconds.
 Elapsed time:       0 days  0 hours  0 minutes  0.1 seconds.
 File lengths (MBytes):  RWF=      6 Int=      0 D2E=      0 Chk=      2 Scr=      1
```

Apparently Gaussian didn't like what we selected as our SOLVENT.  Checking the list of named Gaussian SCRF solvents, the problem is clear:  **DimethylEther** is not on the list, we meant to say **DiethylEther**.  We can correct this oversight by generating another job array:

```
$ popd ; popd
$ ./templating.sh DiethylEther
* Job array will be generated in directory ./jobs-20220603-1746
* Generating job indices
* Generating job_array.qs script
```

Because the `./templating.sh` script creates a unique job array directory, the redo for corrected input file(s) does not require that the previous job array be removed or replaced:  in essence, *both* job arrays can be executing at the same time.  The same `../job-index-lookup` command exists for [1-gaseous](./1-gaseous) job arrays, and the same behavior w.r.t. multiple job arrays (corrected input geometries, for example) is possible.  Now we submit the new job array:

```
$ pushd jobs-20220603-1746
$ sbatch job_array.qs 
Submitted batch job 13758492
```

Once this job completes, its success can be checked by seeing if output for DiethylEther was produced in [3-completed/CarbonMonoxide](./3-completed/CarbonMonoxide):

```
$ popd ; popd
$ ls -l 3-completed/CarbonMonoxide
total 220
-rwxr-xr-x 1 frey it_nss 2097152 Jun  3 16:07 CarbonMonoxide.chk
-rwxr-xr-x 1 frey it_nss     213 Jun  3 16:07 CarbonMonoxide.com
-rwxr-xr-x 1 frey it_nss  117735 Jun  3 16:07 CarbonMonoxide.log
drwxr-xr-x 2 frey it_nss       5 Jun  3 17:47 DiethylEther
drwxr-xr-x 2 frey it_nss       5 Jun  3 16:19 Water

$ ls -l 3-completed/CarbonMonoxide/DiethylEther
total 336
-rwxr-xr-x 1 frey it_nss 3145728 Jun  3 17:47 CarbonMonoxide_DiethylEther.chk
-rwxr-xr-x 1 frey it_nss     243 Jun  3 17:47 CarbonMonoxide_DiethylEther.com
-rwxr-xr-x 1 frey it_nss   62278 Jun  3 17:47 CarbonMonoxide_DiethylEther.log
```

The DiethylEther-solvated job ran properly this time and produced output.

### For the Expert

The `available-chemicals` script for this step also has far more functionality available:

- CHEMICAL names and name patterns can be excluded/included from the list
- The list can be pulled from a text file (one CHEMICAL name per line) rather than by scanning the `../0-chemicals` directory for names

The command has built-in help that describes the available options in detail:

```
$ pushd 2-solvated
$ ./available-chemicals --help
usage: available-chemicals.py [-h] [--format {csv,lines,json}]
                              [--base-list {all,none}] [--short-circuit]
                              [--completed-dir <directory>] [--exclude <name>]
                              [--exclude-regex <regular-expression>]
                              [--exclude-pattern <glob-pattern>]
                              [--include <name>]
                              [--include-regex <regular-expression>]
                              [--include-pattern <glob-pattern>]
                              [--name-list <file>]
                              [--json-name-list <json-file>]
                                   :
```

All of these options can also be passed to the `./templating.sh` script, and it will use them when it invokes `./available-chemicals` to generate the CHEMICAL name list.

Additional detailed discussion of this workflow step can be found in the [2-solvated/README.md](./2-solvated/README.md) file.

## Step 3:  Results

As constructed, the workflow will fill-in the [3-completed](./3-completed) directory with a hierarchy of results.  The results are organized at the top level by CHEMICAL name; inside each CHEMICAL directory are the optimized results for that discrete molecule and any successful solvated calculations.  The solvated results are organized by SOLVENT name, as well.  Thus, the [3-completed](./3-completed) directory winds up holding all deliverable results from the workflow.
