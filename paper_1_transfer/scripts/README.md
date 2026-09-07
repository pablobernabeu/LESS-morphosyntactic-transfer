# `paper_1_transfer/scripts` — the Paper 1 pipeline

Numbered scripts, run in order. The stage-by-stage table, saying what each one produces
and whether it runs locally or on the cluster, is in
[`../README.md`](../README.md#pipeline-scripts-run-in-order) and is the authority. This
file covers the conventions, and what is not in the numbered chain.

## Conventions

`_config.R` is sourced first by every script and defines the analysis grid: three
properties × three windows × two macroregions, eighteen ERP cells, plus the model-ID
naming every downstream file depends on. After it, a script sources whichever of
[`../../_shared/R/`](../../_shared/R/README.md) it needs.

The numbering has no step 6, and a letter suffix means a script added beside an existing
stage (`00b`, `01b`, `07c`, `09b`), which is why it does not take a number of its own.
Nothing reads a script by position in a directory listing, so the gaps are harmless.

Four files sit outside the numbered chain:

- `test_exclusion_guard.R` is the regression test for the mis-filtered-dataset exclusion
  and its staleness guard, and for the decoding seed's repeated default. Run it after
  touching that logic.
- `tests/test_summarise_cells.R` validates step 1's single-trial transform
  synthetically, because the real merge is HPC-scale and must not be run locally.
- `tests/test_erp_retention_artefact.R` pins the headline values of
  `../results/_erp_trial_retention.csv` (step 0c), so a regenerated table with different
  numbers is reported by the test and never refused by the script.
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
environment and must not be restored on the rendering box. Two stages need more than the
lockfile provides. Step 10 needs the non-CRAN package `scopusflow`
(`pak::pak('pablobernabeu/scopusflow')`) and an Elsevier key in `SCOPUS_API_KEY`; without
both it stops and the manuscript falls back to its placeholders. Steps 1, 3, 4, 5, 7, 7b,
8 and 9 need the cluster: CmdStan, the threading build and the memory. See
[`../hpc/README.md`](../hpc/README.md).

## Reproducing the results

Run the local stages in numerical order, submit the cluster stages as the jobs in
`../hpc/`, pull `../results/*.csv` back, and re-render the manuscript. The manuscript
transcribes no statistic by hand, so re-rendering is what updates the reported numbers.
Check `../results/_provenance.csv` afterwards: it records the versions and seeds of the
run that produced the results, and it is what the manuscript cites.

## The one opt-in script

`09b_assemble_confirmatory_timecourse.R` assembles a decoding time-course CSV from
per-block checkpoints, so that a confirmatory block computed at a higher permutation count
can be combined with exploratory blocks still at a lower one. It changes no default code
path: nothing calls it, and step 9 behaves identically whether or not it has ever been
run. It sources `09_run_decoding.R` so as to reuse that script's own FDR function, which
is safe because step 9 guards its entry point on `sys.nframe() == 0L`.

It fails closed on every disagreement it can see, refusing to write if any of these holds:

- the property is wrong, or the block is not the overall one;
- a checkpoint's fingerprint or permutation count disagrees with the others;
- the assembly would lower a stratum's permutation count;
- the time grids do not match, or a column is missing.

Where the decoding
tensor sits beside the checkpoints, it also checks the tensor's size against the record
step 08 wrote. Where the tensor is absent it says so, and its provenance then has to be
verified wherever the tensor lives.
