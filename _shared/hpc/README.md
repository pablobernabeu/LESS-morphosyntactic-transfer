# `_shared/hpc` — cluster environment and its checks

Code shared by both papers' SLURM jobs. Everything here is infrastructure: the runtime
environment the jobs run in, the checks on that environment, and the two scripts that move
code to the cluster and results back. No model is fitted from this directory. The fitting stages are in `paper_1_transfer/hpc/` and
`paper_2_plasticity/hpc/`, whose READMEs hold the submission recipes and the stage tables.

See [`../../HPC_RUNBOOK.md`](../../HPC_RUNBOOK.md) for the project layout on the
cluster and the transfer/render workflow.

Nothing here reads the study's data except `validate_rseeg.R`, which reads a file Paper
2's script 03 has already written. The R library and CmdStan these scripts assume are
rebuilt by `00_restore_environment.slurm` and described in section 0 of the runbook. Path
resolution goes through `LES_DATA_ROOT` and `LES_STORE`, both exported by `arc_env.sh`.

## In use

| File | What it is |
|------|------------|
| `00_restore_environment.slurm` | The reproduction route. Restores the R library from `../../renv.lock` at the recorded versions and builds CmdStan at the version of record (`LES_CMDSTAN_RECORD` in `arc_env.sh`, 2.39.0), the release every reported fit was compiled by, by running the renv bootstrap, restore and CmdStan build lines of the runbook's section 0 as a batch job. The renv that carries out the restore is the version the lockfile pins. Before the restore it stops if the running R differs from the version `renv.lock` records, unless `LES_RESTORE_ALLOW_R_MISMATCH=1` is exported, and after the build it checks that CmdStan reports the version asked for. Needs `renv.lock` beside the code root and outbound network. Submit once, before any fitting job. |
| `arc_env.sh` | Sourced at the top of every job script in both papers and the single source of truth for the cluster layout and the two versions of record. It `module load`s R and stops the job if the module fails to load or supplies an R other than the series the library is built for, points `R_LIBS_USER`, `CMDSTAN`, `LES_DATA_ROOT` and `LES_STORE` at the project `/data` space, selects the CmdStan tree of record unless `LES_CMDSTAN_VERSION` names another, pins `CXXFLAGS_OPTIM = -O1` because of a GCC 14.2.0 compiler crash that its own header explains, and `cd`s to the code root. A path changed here changes everywhere. Sourced in an interactive shell it purges loaded modules, and a failed check returns instead of closing the session. |
| `py_env.sh` | Sourced after `arc_env.sh` by the jobs that run Python (Paper 1's EEG reprocessing and recovery). Loads the SciPy-bundle module on the same toolchain as R and activates the project-space virtual environment that `paper_1_transfer/hpc/00e_submit_reprocessing.sh` builds once. |
| `deploy_to_cluster.sh` | The route for copying code to the cluster, run from the dev box: `bash _shared/hpc/deploy_to_cluster.sh <paper_1_transfer\|paper_2_plasticity\|_shared\|all> [ssh-alias]`. The alias defaults to `LES_CLUSTER_HOST` and, when that is unset, to `arc-agent`, the author's own alias, so anyone else passes the alias they defined for the runbook (`arc` there) or exports `LES_CLUSTER_HOST`. It sends the target's tracked R, Python and job scripts (and Paper 1's overlay manifests) in the LF form git stores, and only those whose content differs from the cluster's copy. It holds back `09_run_decoding.R` and `08_decoding.slurm` unless `LES_ALLOW_DECODING_DEPLOY=1`, because the banked permutation blocks are keyed to the tensor, the permutation count and the seed but not to the script's code, and `08_decoding.slurm` sets the count and the seed. It then lists your LESS jobs on HTC and ARC, refusing to go on if the query fails, follows each job's batch script through every file it runs or sources, and holds back the changed files among them, so that neither a running nor a pending job reads a file that changed under it. A live job it cannot identify stops the deploy. `LES_DEPLOY_ANYWAY=1` overrides both; `LES_DEPLOY_DRY_RUN=1` reports without copying. Every copied file is checked by checksum on the cluster. Exit status 3 means files were held back. Code only: never data, never the store, never a fit. HPC_RUNBOOK.md has the full account. |
| `pull_results.sh` | The route for bringing result CSVs back, run from the dev box: `bash _shared/hpc/pull_results.sh <paper_1_transfer\|paper_2_plasticity> [file.csv ...]`. Without `LES_PULL_APPLY=1` it only reports each store CSV as the same as the committed copy, changed, new or local-only. Applied, it copies the changed files, or the named ones, checks them against the store's checksums and logs each in `<paper>/results/_pulls/pull_log.csv`. |
| `check_arc_env.R` | One-shot sanity check. Prints where the paths resolve, which library R is using, and whether CmdStan really compiles and samples a trivial model. Run it by hand after sourcing `arc_env.sh`, or let `rebuild_cmdstan.slurm` run it. Its closing PASS/FAIL covers the compile alone, so read the lines above it as well. |
| `rebuild_cmdstan.slurm` | Run once after CmdStan is installed or moved. The precompiled headers bake in the install path, so a relocated CmdStan has to be rebuilt, and the rebuild is too memory-hungry for a login node. Its log goes to `paper_1_transfer/hpc/logs/`. |
| `validate_rseeg.R` | Checks `resting_state_eeg.rds` after Paper 2's script 03: band power and IAF by condition, the Berger effect, and the eyes-closed IAF range. Nothing invokes it automatically, so run it yourself after stage 1c. |

One level up, `_shared/install_bayesian_dependencies.R` bootstraps an unpinned R library
and CmdStan where none exists yet. It is not the reproduction route, which is
`00_restore_environment.slurm` above.

## Reconnaissance scripts, outside every pipeline

Six one-off scripts from June 2026 record how the resting-state recordings were located
and what format they turned out to be in. They now sit in
[`reconnaissance/`](reconnaissance/README.md), which explains what each one settled.
Nothing in either paper references any of them. They are kept as a record of how the data
were found, and not because anything needs them.
