# `paper_1_transfer/scripts` — the Paper 1 pipeline

Numbered scripts. The stage-by-stage table, saying what each one produces
and whether it runs locally or on the cluster, is in
[`../README.md`](../README.md#pipeline-scripts-run-in-order) and is the authority. This
file covers the conventions, and what is not in the numbered chain.

## Conventions

`_config.R` defines the analysis grid: three
properties × three windows × two macroregions, eighteen ERP cells, plus the model-ID
naming every downstream file depends on. Scripts 00, 00c, 01, 01b, 02, 03, 04, 05, 07,
07b, 08 and 09 source it; 00b reaches it through script 00 and 09b through script 09. Each
of them also sources whichever of [`../../_shared/R/`](../../_shared/R/README.md) it
needs, and script 00 also sources Paper 2's `_config.R` for the index names, measures and
sessions of the Paper 2 flow stages. Scripts 00d, 07c and 10 use nothing from `_config.R`
and source only `00_paths.R` and `03_data_manifest.R`.

The numbering has no step 6, and a letter suffix means a script added beside an existing
stage (`00b`, `00c`, `00d`, `01b`, `07b`, `07c`, `09b`), which is why it does not take a
number of its own.
Nothing reads a script by position in a directory listing, so the gaps are harmless.

Eight files sit outside the numbered chain:

- `test_exclusion_guard.R` is the regression test for the mis-filtered-dataset exclusion
  and its staleness guard, for the decoding defaults (seed, permutation count, time step)
  that have to be repeated in the job scripts, and for the analysis grid the job arrays
  copy. Run it after touching that logic.
- `tests/test_summarise_cells.R` validates step 1's single-trial transform
  synthetically, because the real merge is HPC-scale and must not be run locally.
- `tests/test_erp_retention_artefact.R` pins the headline values of
  `../results/_erp_trial_retention.csv` (step 0c), counted from the analysed sample, so a
  regenerated table with different numbers is reported by the test and never refused by
  the script.
- `tests/test_retained_trials.R` checks 0c's counting of retained trials on a synthetic
  store.
- `tests/test_group_descriptives.R` checks the participant-balanced, group-separated
  descriptive summaries behind the group figures.
- `tests/test_eeg_import.R` checks the vendored importer against the legacy importer it
  copies, on real exports, including the Session-2 reference correction; it skips where
  the data tree is absent.
- `tests/test_decoding_prose.R` checks the manuscript helpers that compute the decoding
  section's prose (the two correction layers, the appendix guard, the Discussion's grading
  of gender agreement and the robustness sentence) on synthetic time-courses. It takes the
  helpers from `../paper_1_morphosyntax.qmd` with `knitr::purl()`, so run it after editing
  them.
- `09b_assemble_confirmatory_timecourse.R` is opt-in, described below.

## Where the data are

Inputs come from `../../data/`, which is **read-only**: no script here may write inside
it, and `les_assert_readonly_data()` stops any that tries. Paths resolve through
`../../_shared/R/00_paths.R`, so no script hard-codes a location and any of them can be
run from any working directory.

Derived datasets go to `../data_derived/`, which is **not in version control**, so a fresh
clone has none of it. Step 2 rebuilds the three accuracy datasets locally. The eighteen
single-trial ERP `.rds` are produced by step 1 on the cluster and are not reproducible on
a desktop. Manuscript-facing tables go to `../results/`; see
[its readme](../results/README.md).

## Dependencies

R packages are pinned in `../../renv.lock`, which describes the cluster fitting
environment and must not be restored on the rendering box. Step 10 runs locally and needs
`scopusflow` 0.4.0 from [CRAN](https://CRAN.R-project.org/package=scopusflow); install the
recorded release with `pak::pkg_install("scopusflow@0.4.0")`. It also needs an Elsevier key
in `SCOPUS_API_KEY`. Without either requirement, it stops without replacing the committed
counts. Steps 1, 3, 4, 5, 7, 7b,
8 and 9 need the cluster: CmdStan, the threading build and the memory. See
[`../hpc/README.md`](../hpc/README.md).

## Reproducing the results

Submit the stages as the jobs in `../hpc/`, in the order `../hpc/submit_all.sh` chains
them. Numerical order is not run order: steps 0 and 0b read step 2's accuracy files and
Paper 2's derived files, so they run after step 2, where both papers' `data_derived/`
exist. Then pull `../results/*.csv` back (`../../_shared/hpc/pull_results.sh`) and
re-render the manuscript. The manuscript
transcribes no statistic by hand, so re-rendering is what updates the reported numbers.
Check the provenance records afterwards. `../results/_provenance.csv` is the file the
manuscript reads for the software versions and the model-fitting seed. Every run of step 3
rewrites it, sensitivity runs included, unless `LES_PROVENANCE_SKIP=1` is set, so its
`recorded_utc` says which run wrote it last. The per-fit versions are in
`../results/_pooled_fit_metadata.csv`. The decoding seed, permutation count and time step
are recorded in `../results/_decoding_provenance.csv`, which `../hpc/08_decoding.slurm`
writes and from which the manuscript takes the decoding seed.

## The one opt-in script

`09b_assemble_confirmatory_timecourse.R` writes a decoding time-course CSV from the block
checkpoints step 9 has already banked, so that a property's time-course can be reported
before every block has finished, for instance after a run hit its walltime. Every row
comes from a checkpoint, never from an existing CSV. Every checkpoint must carry the
fingerprint of the tensor now on disk in all but its permutation count, so a confirmatory
block recomputed at a higher count can sit beside exploratory blocks at a lower one. It
changes no default code path: nothing calls it, and step 9 behaves identically whether or
not it has ever been run. It sources `09_run_decoding.R` to reuse that script's
fingerprint and FDR functions, which is safe because step 9 guards its entry point on
`sys.nframe() == 0L`. With every block banked, its CSV is identical to step 9's.

It fails closed, refusing to write if any of these holds:

- the tensor's size or modification time differs from the record step 08 wrote beside
  it, the record is missing, or the tensor's values no longer match its stored digest;
- a checkpoint holds the wrong property, analysis or level, carries a fingerprint that
  differs from the tensor's in anything but the permutation count, or has a permutation
  count that contradicts its own `n_perm` column;
- a block's trial or participant count differs from what the tensor gives, or a
  checkpoint exists for a block the tensor would not produce;
- an existing CSV holds a block the assembly would drop, or a block at a higher
  permutation count.

It loads the tensor, so run it in a job, not on a login node.
