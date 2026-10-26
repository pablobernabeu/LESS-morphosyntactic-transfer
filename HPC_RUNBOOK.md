# HPC runbook — fitting both papers on Oxford's SLURM service

The Bayesian fits run on Oxford's SLURM service under the `educ-intract` project group.
Its two clusters, ARC and HTC, both use environment modules, with no Singularity
container, and access is by SSH key.
`arc` in the recipes below is a host alias, not a name the service publishes. Define one in
your own `~/.ssh/config` before running anything here, and use its name everywhere below,
including in the `scp` recipes. From outside the university network the alias needs a
`ProxyJump` through the service's gateway host, the login node being reachable directly
only from inside that network. If your key carries a passphrase, an interactive `ssh` will
prompt for it unless the key is already loaded in `ssh-agent`, which is worth arranging
before any scripted polling.

**ARC or HTC.** The project `/data` space is mounted at the same path on both, so
`_shared/hpc/arc_env.sh` serves either and no job script has to change. Only the
submission line differs. A plain `sbatch`, which is what the `sbatch` recipes below and
Paper 1's `submit_all.sh` use, goes to the login node's default cluster, ARC, where
project access comes through the `educ-intract` unix group and no `--account` is
needed. Since 2026-06-30 the preferred target for these single-node jobs is HTC,
submitted as `sbatch --clusters=htc --account=educ-intract <script>.slurm`, standard
QoS only and never `--qos=priority`. HTC requires the `--account`. Paper 2's
`submit_all.sh` submits its whole chain to HTC under `educ-intract` by default.
`LES_CLUSTER` and `LES_ACCOUNT` override the two, and `LES_CLUSTER=""` sends the chain to
the site default. Paper 1's chain still runs on ARC. The per-paper `hpc/README.md` files
carry the per-stage recipes.

## Project layout (the "scripts on personal disk, heavy material in /data" split)

```
~/new_LESS/                                   PERSONAL DISK -- code only
   _shared/{R,hpc,install_bayesian_dependencies.R}
   paper_1_transfer/{scripts,hpc,*.qmd,references.bib,...}
   paper_2_plasticity/{scripts,hpc,*.qmd,references.bib,...}
   LESS Project.Rproj                          here::here() sentinel

$LES_PROJECT/                                 PROJECT SPACE (shared, multi-project)
   new_LESS/                                    LESS's own folder -- heavy material
      data/                                     read-only inputs   (LES_DATA_ROOT)
      Rlib/R-4.5/                               R package library  (R_LIBS_USER)
      cmdstan/cmdstan-*/                        Stan toolchain     (CMDSTAN)
      pyenv/eeg-recon-py3.13/                   Python venv for the EEG reconstruction (py_env.sh)
      store/paper_{1,2}_*/{data_derived,results,figures}   model outputs (LES_STORE)
```

The project-space root, `LES_PROJECT`, is shared with other projects, so everything LESS
owns sits under its own `new_LESS/` level. `arc_env.sh` is the one place that root is
written out; it sets `LES_BASE` to that folder and derives every other variable from it.

`_shared/hpc/arc_env.sh` is sourced at the top of every job and is the **single
source of truth** for this split: it `module load`s R, points `R_LIBS_USER` /
`CMDSTAN` / `LES_DATA_ROOT` / `LES_STORE` at the project space, and `cd`s to the
code root. `_shared/R/00_paths.R` reads `LES_DATA_ROOT` / `LES_STORE` (falling
back to a single self-contained tree on the dev box), so **no analysis script
hard-codes a cluster path**.

## 0. One-time setup (already done; here for reproducibility)

```bash
ssh arc                                     # key-based, non-interactive
# code -> personal disk:
#   (from the dev box)  scp -r _shared paper_1_transfer paper_2_plasticity \
#                              "LESS Project.Rproj" arc:new_LESS/
# log directories -> neither tracked nor copied, and Slurm opens a job's -o file before
# the job body runs, so create them before the first sbatch (from ~/new_LESS):
mkdir -p paper_1_transfer/hpc/logs paper_2_plasticity/hpc/logs
# data -> lives in the project space as a real directory:
#   $LES_BASE/data   (read-only; LES_DATA_ROOT)
# The legacy loaders read it by paths relative to the CODE root ("data/..."), so
# arc_env.sh creates the pointer on that side, automatically, on every job:
#   ~/new_LESS/data -> $LES_BASE/data
# There is no $LES_PROJECT/data; the data tree lives only under $LES_BASE.
# toolchain -> project-space library + CmdStan. Two routes:
#   reproduction: restore renv.lock and build CmdStan 2.39.0 (put renv.lock beside the
#   code root first; see below)
sbatch _shared/hpc/00_restore_environment.slurm
#   bootstrap: an unpinned library where none exists (brms, cmdstanr, eegUtils, papaja,
#   ...), which is how the library was first built; shared with Paper 2 -- run ONE only
sbatch paper_1_transfer/hpc/00_install_dependencies.slurm
```

Either job builds into `Rlib/R-4.5` and `cmdstan/` (both need the gfbf/2025a GCC compiler
from the R module + outbound network — both confirmed available). If a compute node
ever lacks network, run the step on the `interactive` partition: `srun -p interactive --pty
bash`, then `source _shared/hpc/arc_env.sh` followed by the job's `Rscript` lines. Sourcing
it in an interactive shell runs `module purge`, which unloads whatever modules the shell
had, `cd`s to the code root and creates the `data` symlink there. When one of its checks
fails it returns rather than exiting, so the session survives, but the environment it has
set up by then is incomplete.

The text inputs in the repository's `data/` tree (the CSVs, the BrainVision `.vhdr`,
`.vmrk` and `.txt` exports, the lab logs) are stored LF-normalised under the `* text=auto`
rule in `.gitattributes`, while the original exports carry CRLF. The exceptions are a few
files git classifies as binary (nine CSVs and 19 `.vhdr` files), which are stored as they
are. For every other input, a copy of the data taken from outside git matches the committed
file only once CR is stripped. A checksum comparison of the inputs has to hash normalised
content, for instance
`git hash-object --path=<repo path> <file>` inside a clone, or sha256 after removing CR.

The bootstrap installer pins nothing. `install_if_missing()` skips any package that is already
present and otherwise takes the current CRAN release, cmdstanr comes from the Stan
R-universe head, and `install_cmdstan()` is called without a `version=`. Running it again
today would therefore build a newer environment than the one the reported fits came from.
Rebuild against the record instead. The environment of record is the module `R/4.5.1-gfbf-2025a`
(R 4.5.1 on `x86_64-pc-linux-gnu`, GCC 14.2.0, OpenBLAS 0.3.29, FlexiBLAS 3.4.5) with
CmdStan 2.39.0 under `$LES_BASE/cmdstan/cmdstan-2.39.0`, compiled with
`CXXFLAGS_OPTIM = -O1` (see the `cc1plus` ICE section below). The R packages are pinned in
the repository's `renv.lock`, so the way to rebuild that side is a restore. Of its 422
package records, 420 were snapshotted on the cluster across the whole library search path.
The other two, `depictr` and `scopusflow`, were added by hand and are not installed on the
cluster (see the root `README.md`).

Two things about the layout govern how that restore has to be written. First, the `scp` in
the block above copies `_shared`, the two paper directories and the `.Rproj` sentinel, and
nothing else. The code root on the cluster therefore carries no `.Rprofile`, no `renv/` and
no `renv.lock`, and `arc_env.sh` `cd`s into that code root before anything else runs. renv
is never activated at job time, so both the lockfile and the target library have to be
named explicitly. Second, the library argument must name the whole search path, and not
`R_LIBS_USER` alone. The snapshot was taken across both trees, so a restore that cannot see
the R module's own library would reinstall the hundred-odd packages the lockfile pinned
from it.

```bash
# renv.lock is not part of the scp above, so put it beside the code root once,
# from the dev box:  scp renv.lock arc:new_LESS/
source _shared/hpc/arc_env.sh
Rscript --vanilla -e 'if (!requireNamespace("renv", quietly = TRUE)) install.packages("renv", repos = "https://cloud.r-project.org")'
Rscript --vanilla -e 'renv::restore(lockfile = "renv.lock", library = .libPaths(), prompt = FALSE)'
Rscript --vanilla -e 'cmdstanr::install_cmdstan(version = "2.39.0", dir = Sys.getenv("CMDSTAN_INSTALL_DIR"))'
```

The first `Rscript` line installs renv if R cannot find it, taking whatever release CRAN
currently serves, and the restore then replaces that copy with the renv 1.2.3 the lockfile
pins. `_shared/hpc/00_restore_environment.slurm` runs the same bootstrap, restore and build
as a batch job on the `short` partition, so nothing has to be typed on a login node, and it
goes further than the three lines above in three ways: it installs the renv version the
lockfile pins (from CRAN's archive) before restoring, so the restore engine is pinned too;
it stops before installing anything if the running R is not the version `renv.lock`
records; and it checks that the CmdStan it built reports the version asked for. Submit
it once and let it finish before starting a chain with no argument, or run
`submit_all.sh with_restore`, which submits it and makes the chain wait for it with
`afterok` (section 1).

**Raw EEG signal files and the Python environment (Paper 1's reprocessing only).** The
data tree holds the BrainVision headers and marker files of every raw recording, but not the
signal (`.eeg`) files, which are archived on OSF (component `tq7vy`, Session 3). The EEG
reconstruction (`paper_1_transfer/scripts/eeg_reconstruction/`) needs thirteen of them: the
nine records it reprocesses and IDs 10, 51, 58 and 59, whose 0.1 Hz exports fix its filter
rule. They sit beside their headers in `data/raw data/EEG/Session 3/Raw/`, placed there on
27 September 2026 after each was checked against the SHA-256 that OSF reports, and the
headers and marker files already in the tree were checked against OSF the same way (all
matched). Every reprocessing job hashes them again into its provenance record. The
recovery stage (protocol Amendments 2, 3 and 6) adds two more, placed on 30 September 2026
on the same terms: Session 6 of lab ID 5 (`Session 6/Raw/5.eeg`) and Session 2 of lab ID 7
(`Session 2/Raw/7.eeg`), from OSF `tq7vy`. The Python
side runs on the `SciPy-bundle/2025.06-gfbf-2025a` module (the same gfbf/2025a toolchain as
the R module) plus a project-space virtual environment holding the one pinned package the
bundle lacks; `paper_1_transfer/hpc/00e_submit_reprocessing.sh` builds it on the login node
the first time it runs, and `_shared/hpc/py_env.sh` loads it in the jobs.

CmdStan needs that explicit version because `install_cmdstan()` otherwise builds the
current release. Which tree a job then uses is decided by `arc_env.sh`, which names the
version of record once, as `LES_CMDSTAN_RECORD` (2.39.0), and selects that tree whenever it
exists. Only when it is absent does a job take the highest `cmdstan-*` tree it finds, and
it says so in its log. Submitting a job with `--export=ALL,LES_CMDSTAN_VERSION=2.39.0`
(as `paper_1_transfer/hpc/submit_eeg_rerun.sh` does for the fits) goes one step further and
fails the job outright if that tree is absent. Do not export it in the shell before the tree
has been built: `arc_env.sh` stops as soon as the named tree is missing, which ends the
manual route above at its `source` line. The restore job clears an inherited value before
it sources `arc_env.sh`. The manual route and the `00_install_dependencies.slurm` bootstrap
do not, so either one stops there on a fresh environment. `arc_env.sh` also stops a job
whose R module fails to load, or loads an R other than the 4.5 series the library is built
for. What a given run actually used is written at fit time to
`paper_*/results/_provenance.csv` by `_shared/R/04_provenance.R`, and that file, not this
one, is authoritative for a completed run.

## 1. Submit the pipelines (from `~/new_LESS`)

```bash
cd ~/new_LESS
bash paper_1_transfer/hpc/submit_all.sh        # 01/02 extract -> 03/04 fit -> 05 summarise
bash paper_2_plasticity/hpc/submit_all.sh      # 01/02/03 extract -> 04/05 fit -> 06 summarise
squeue -M htc,arc -u "$USER"                   # track (both chains go to HTC by default)
```

Both scripts submit to HTC under `educ-intract` unless `LES_CLUSTER` and `LES_ACCOUNT` say
otherwise, and both stop at the first submission that fails.

`submit_all.sh` chains the stages with `--dependency=afterok`, and its first argument can
put provisioning at the head of the chain. `with_restore` submits
`_shared/hpc/00_restore_environment.slurm`, the pinned route, and makes the chain wait for
it with `afterok`. `with_install` bootstraps an unpinned toolchain in its place. A restore
submitted by hand has to finish before a chain is started with no argument, since nothing
then makes the stages wait for it. The restore job writes its log under
`paper_1_transfer/hpc/logs/`, which both papers' `submit_all.sh` create before submitting
it. Partitions are set per stage in the job scripts:

| Partition | Stages |
|---|---|
| `long` | The ERP, accuracy and Part A fits, the decoding array, projpred and its order diagnostic, and Paper 2's `09c` participant-grouped comparison, whose 40 refits took 15 h 48 min in HTC 8976040 (sacct elapsed). |
| `medium` | The single-trial ERP extraction, and Part B. |
| `short` | Everything else: Paper 1's EEG reprocessing and recovery (`00e`, `00f`, `00g`), the remaining extractions (accuracy, cognitive indices, trajectory, rs-EEG, aperiodic decomposition), the summaries, the projpred recovery job and the `09b` common-sample comparison. |

The per-stage tables in
[`paper_1_transfer/hpc/README.md`](paper_1_transfer/hpc/README.md) and
[`paper_2_plasticity/hpc/README.md`](paper_2_plasticity/hpc/README.md) list them.

These two chains cover only the core extract → fit → summarise path. The later and
longest-running stages are submitted by hand: Paper 1's `07`/`07b` grand averages and
the `08_decoding.slurm` array, and Paper 2's `07` aperiodic, `08` projpred, `09`
aperiodic-model, `09b` common-sample comparison and `09c` participant-grouped
comparison, in that order. Paper 1's `00_descriptives.slurm` and Paper 2's
`10_descriptives.slurm`, `11_predictor_reliability.slurm` and
`13_extract_task_durations.slurm` are submitted by hand as well, all on the `short`
partition, since neither chain reaches them. So are two checks. Paper 1's trigger-rule
check (`00h_submit_trigger_check.sh`, Amendment 5 of the reprocessing protocol) feeds no
analysis. Paper 2's projpred order diagnostic (`08c_order_diagnostic.slurm`, on `long`)
writes the tables from which supplement S5 explains why the paper reports no ranking of the
individual-difference predictors. `08_decoding.slurm` has two stages,
and the cross-property stage needs `--array=0`, `--export=ALL,LES_DECODE_STAGE=cross_property`
and an explicit `-o` log path, or it starts three tasks racing to write the same files
and clobbers a running element's log. The two `hpc/README.md` files above are the
authority for all of this.

**Paper 1's EEG reprocessing** (`docs/eeg_filter_reprocessing_protocol.md`) comes before
every Paper 1 EEG stage and is started with one script, which splits each array across the
`educ-lift` and `educ-intract` accounts and chains validate → reprocess → assemble with
`afterok`:

```bash
cd ~/new_LESS && LES_CODE_COMMIT=<deployed commit> bash paper_1_transfer/hpc/00e_submit_reprocessing.sh
```

What it produces and how the overlay is then admitted are in
[`paper_1_transfer/hpc/README.md`](paper_1_transfer/hpc/README.md), "EEG reprocessing".
The recovery of two misaligned exports and the rebuild of three missing marker files follow
it with `bash paper_1_transfer/hpc/00g_submit_recovery.sh`, submitted the same way.

**Prior-sensitivity run** (weakly-informative baseline): submit the fitting job with
`LES_PRIOR_SET=weak` and `LES_PROVENANCE_SKIP=1`, for example
`sbatch --export=ALL,LES_PRIOR_SET=weak,LES_PROVENANCE_SKIP=1 paper_1_transfer/hpc/03_fit_erp.slurm`.
Cached fits are tagged `*_weakprior*`, so the two runs never share a fit, but the run-level
record is not tagged: Paper 1's step 03 and Paper 2's step 04 rewrite
`results/_provenance.csv` at the end of every run unless `LES_PROVENANCE_SKIP=1` is set
(`09_aperiodic_model.slurm`, which runs step 04, sets it by default), and the manuscripts
would then report the sensitivity run's
date and environment as those of the reported fits. The same holds for any other variant
switch, and for a `LES_PRIOR_PREDICTIVE=1` run of step 03. The "Analysis-variant switches"
table in each paper's `hpc/README.md` is the authority for the switches and their recipes.

## 2. Pull results back and render (dev box)

Outputs land in `$LES_STORE/paper_{1,2}_*/results/`, where `LES_STORE` is
`$LES_BASE/store` (note the `new_LESS/` level inside `LES_BASE`). Bring them back with
`_shared/hpc/pull_results.sh`, then render with the dev-box recipe (TinyTeX; see
`paper_1_transfer/README.md`):

```bash
cd /path/to/your/clone
export LES_CLUSTER_HOST=arc                              # the alias defined above
bash _shared/hpc/pull_results.sh paper_1_transfer        # report only: same, changed, new
LES_PULL_APPLY=1 bash _shared/hpc/pull_results.sh paper_1_transfer      # copy the changed files
LES_PULL_APPLY=1 bash _shared/hpc/pull_results.sh paper_1_transfer _new_table.csv   # or name them
quarto render paper_1_transfer/paper_1_morphosyntax.qmd
quarto render paper_2_plasticity/paper_2_neuroplasticity.qmd
```

Do not copy the store's CSVs with a glob. The store keeps whatever every run left there:
variant-tagged outputs, superseded files, and aggregates such as Paper 2's
`_projpred_path.csv` that whichever selection finished last has overwritten. A wholesale
copy imports whatever mix is there on the day and records nothing. The script first
reports each CSV as the same as the committed copy (compared as git would store it, so the
working copy's line endings do not matter), changed, new in the store, or present only
locally. Applied, it copies the changed files, or the ones you name, and a new file only
when named. It then checks every copied file against the store's checksums and appends a
row per file (store path, cluster modification time, SHA-256, git blob id, time of the
pull) to `<paper>/results/_pulls/pull_log.csv`, which nothing renders. Commit that log with
the CSVs. It never deletes a local file the store lacks.

The script lists only the CSVs at the top of each paper's `results/` in the store, and it
takes file names without a folder, so it cannot reach a subfolder. The one subfolder a
document reads is Paper 2's `results/diagnostics/`, where `08c_projpred_order_diagnostic.R`
writes the order diagnostic's tables. Copy those by hand, check each against `sha256sum` on
the cluster, and append a row per file to `pull_log.csv` in the script's format, with the
path under `results/` in the `file` column. The six tables pulled on 7 October 2026 were
brought back that way.

The `*[pending model fit]*` placeholders populate automatically.

`paper_1_transfer/results/` and `paper_2_plasticity/results/` are the only trees the
manuscripts read. `_shared/R/00_paths.R` resolves to them whenever `LES_STORE` is
unset, which is the case on the dev box. An older working copy may also carry a root-level
`store/`, a partial pull-back from early July. It is not in the repository or part of the
layout, and nothing on the dev box reads or writes it. Every CSV it held has a counterpart
in the two `results/` trees, so it can be removed.

## 3. Paper-2 resting-state EEG (optional)

The Session-2 resting recordings already live in the local task-EEG tree, as
BrainVision ASCII exports under `data/raw data/EEG/Session 2/Export/`.
`paper_2_plasticity/scripts/03_extract_resting_state_eeg.R` parses them in base R and
computes the PSD with a self-contained Welch estimator, because eegUtils' `import_raw`
does not read ASCII. It needs no OSF download, no eegUtils and no network, so it runs on
any batch node (`paper_2_plasticity/hpc/03_extract_rseeg.slurm`, `short` partition). It
writes `paper_2_plasticity/data_derived/resting_state_eeg.rds`. `04` fits the
cognitive-only Part A models without it and adds the Session-2 rs-EEG baseline predictors
automatically once that file exists. `05` fits cognition only either way, because its
rs-EEG pre/post block skips, there being no Session-6 recording to pair with Session 2.

## Do not scp a script that a running job is executing

`Rscript file.R` does not read the whole file up front. It parses and evaluates one
expression at a time, holding an offset into the file. Overwriting that file while a job
is running shifts the content underneath the offset, and when the interpreter reaches the
end it reads a fragment of a line and dies with a parse error such as

    Error: unexpected ')' in "age == "crossprop")"

which is the tail of `if (stage == "crossprop") {`.

This happened on 2026-08-06: `09_run_decoding.R` was synced while decoding array 12664261
had been running since 2026-08-01. The array element that was mid-run finished all of its
work and wrote every artefact, then failed at the very end with a non-zero exit. Nothing
was lost, but the failure propagated: the cross-property job chained with
`--dependency=afterok` could no longer start, and had to be submitted by hand.

A pending job is exposed too, in a quieter way: it runs whatever copy of a script is on
disk when it starts, so a file changed while it waits gives one result two versions of the
code. Before syncing, check what is live (`squeue -M htc,arc -u $USER`) and which files
those jobs run or source. If a job can still read the file, either wait, or copy to a new
name and submit the new name. The risk is highest for the long decoding and fitting jobs,
which can hold a file open for a week or more.

`_shared/hpc/deploy_to_cluster.sh` does that check for you, and it is the recommended
way to sync code:

```bash
bash _shared/hpc/deploy_to_cluster.sh paper_2_plasticity      # or paper_1_transfer, _shared, all
bash _shared/hpc/deploy_to_cluster.sh paper_2_plasticity arc  # through a named ssh alias
LES_DEPLOY_DRY_RUN=1 bash _shared/hpc/deploy_to_cluster.sh all arc   # what would be copied, copy nothing
```

The optional second argument is the ssh alias to deploy through. Without it, the script uses
`LES_CLUSTER_HOST`, and when that is unset it falls back to `arc-agent`, the author's own
alias, so anyone else should pass the alias defined above or export `LES_CLUSTER_HOST`.

It sends the target's tracked R and job scripts, plus, for Paper 1, the EEG reconstruction
and the overlay manifests the importer reads; a new file has to be staged with `git add`
first. Text files go as git stores them, LF-only, whatever line endings the checkout wrote,
so a job script never reaches bash with a carriage return. It holds back
`09_run_decoding.R` and `08_decoding.slurm` unless `LES_ALLOW_DECODING_DEPLOY=1` is
exported, whether or not a decoding job is live: the banked permutation blocks are keyed to
the tensor's trial, participant and time-point counts, a digest of its values, the
permutation count and the seed, but not to the code of `09_run_decoding.R`, so a changed
copy would resume blocks the old code computed, and `08_decoding.slurm` sets the count and
the seed.

It then surveys the cluster in one connection. It lists your jobs on HTC and ARC and keeps
the LESS ones (names beginning `p1_`, `p2_` or `les_`, or the code root as working
directory), and it refuses to deploy if either query fails, since an empty answer has to
mean an empty queue. For each of those jobs it follows the batch script through every file
it runs, sources or imports, on both the local and the cluster copies, and holds back
whichever of those files has changed; a live job it cannot identify stops the deploy.
`LES_DEPLOY_ANYWAY=1` overrides both, so keep it for a job you have checked by hand. A file
whose content already matches the cluster's copy is not copied again, and an R, Python or
CSV file that differs only in line endings counts as matching, so a cluster copy keeps its
modification time unless its content changes. That matters for the decoding tensor cache,
which keys on the size and modification time of `_config.R`, `_eeg_import.R` and the
overlay manifest. Last, it checks every copied file's checksum on the cluster. It exits 0
when the whole target is current, 3 when files were held back (run it again once the jobs
end), and 1 on any refusal or failure. It copies code only: never data, never the store,
never a fit.

## Troubleshooting

### `internal compiler error: Segmentation fault ... cc1plus` when fitting

GCC 14.2.0, the compiler in the `R/4.5.1-gfbf-2025a` toolchain, segfaults while
instantiating Stan's `reduce_sum` templates at `-O2` and `-O3`. Because `les_brm()`
uses within-chain threading, every model compile hits it, and the fit job dies within
seconds. It is a compiler crash, not a resource limit: it reproduces on a compute node
with an unlimited stack, unlimited virtual memory and 100 GB free in `/tmp`, at under
2 GB peak RSS.

`_shared/hpc/arc_env.sh` pins `CXXFLAGS_OPTIM = -O1` in `$CMDSTAN/make/local` to avoid
it, so sourcing the env in any job script is enough. `-O1` is the only level that
compiles with threading on. If you would rather keep `-O3`, the alternative is to drop
threading, but that changes the `reduce_sum` reduction order and so the exact posterior
draws, whereas the optimisation level does not.

To re-measure after a toolchain upgrade:
`sbatch paper_1_transfer/hpc/99_diagnose_ice.slurm` compiles one ERP cell at several
optimisation levels, with and without threading, and reports which combinations build.

### A job "COMPLETED" in seconds without fitting anything

`les_brm()` uses `file_refit = "on_change"`, so an unchanged dataset legitimately
reuses its cached fit. Verb–object number agreement has data only from Sessions 4 and 6,
so the mis-filtered Session-3 exclusion removes nothing from it and its six cells
correctly reuse their cached fits. Check the `.Rout` log: a genuine reuse still prints
real convergence diagnostics.

Never treat an exit code or a marker file as evidence that a data-changing job did what
it claimed. `paper_1_transfer/scripts/03_fit_brms_erp.R` records, for every fit, what
data it was actually fitted to (`*_fitmeta.rds`, pooled by step 05 into
`_pooled_fit_metadata.csv`), and the Paper 1 manuscript prints a visible marker on its
exclusion claim until every reported fit backs it up. Run
`Rscript --vanilla paper_1_transfer/scripts/test_exclusion_guard.R` after touching that
logic. The `--vanilla` keeps the project `.Rprofile` out of the way, which matters in a
working copy whose renv library has been populated. `Rscript` is not on the dev box's PATH,
so use the full-path invocation given in `paper_1_transfer/README.md`.

## Before submission (manuscripts)

The author blocks, ORCIDs, correspondence address, CRediT statement and funding are
filled in. What still needs a decision from the authors is listed, item by item, in
[`AUTHOR_TASKS.txt`](AUTHOR_TASKS.txt) at the repository root; the manuscripts mark the
same points in the text with the bracketed-italic convention (`*[...]*`), so a render
shows every one of them in place. Search either `.qmd` for `*[` to find them.
