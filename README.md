# The Neurocognition of Longitudinal L3 Morphosyntactic Transfer

Research compendium for a Bayesian single-trial ERP study of third-language morphosyntactic
transfer. Norwegian–English bilinguals learned Mini-English or Mini-Norwegian over four EEG
sessions, from first exposure to post-consolidation retention, and three grammatical
properties were tracked throughout: subject–verb gender agreement, differential object
marking, and verb–object number agreement.

The rendered manuscript is [`paper_1_transfer/paper_1_morphosyntax.pdf`](paper_1_transfer/paper_1_morphosyntax.pdf).
The study was preregistered at <https://osf.io/tjr54>.

**You can reproduce every number, table and figure in the paper from this repository
alone.** The machine-written summary tables the manuscript reads are committed under
`paper_1_transfer/results/`, and no statistic is transcribed by hand: the manuscript
computes each one at render time from those files. Re-fitting the models from raw EEG is a
separate, much heavier job that needs a cluster and the raw recordings; see *Re-fitting the
models* below.

## Layout

| Path | What it holds |
|---|---|
| `paper_1_transfer/` | The paper. `scripts/` (numbered, run in order), `hpc/` (SLURM jobs), `results/` (the tables the manuscript reads), `figures/`, the `.qmd` and its `references.bib`. Each subfolder has its own readme. |
| `_shared/` | Code shared with the companion paper: path resolution, brms settings and priors, convergence diagnostics, the read-only contract over the data, the provenance record, the participant-flow figure. |
| `HPC_RUNBOOK.md` | Cluster layout, job submission, pulling results back, and the failure modes worth knowing about. |
| `renv.lock` | The R packages of the **fitting** environment, pinned at the versions the cluster library held. |

## Where the data are

The raw electroencephalographic recordings are far too large for a git repository and are
deposited on OSF at <https://osf.io/tq7vy>. Nothing in this repository writes to them: the
read-only contract is enforced at run time by `les_assert_readonly_data()` in
`_shared/R/03_data_manifest.R`, which stops any script whose write path resolves inside a
data directory.

What *is* here is everything derived from those recordings that the paper depends on. The
pooled posterior summaries, the retention contrasts, the convergence diagnostics, the
sample-flow counts, the grand-average waveforms and the decoding time-courses all sit in
`paper_1_transfer/results/`, with `paper_1_transfer/results/README.md` explaining what
writes each one and what reads it.

## Reproducing the manuscript

You need [Quarto](https://quarto.org) and R. The apaquarto extension is vendored under
`paper_1_transfer/_extensions/`, so it needs no separate install.

```bash
quarto render paper_1_transfer/paper_1_morphosyntax.qmd --to apaquarto-pdf
```

Two things are worth knowing before the first run.

**Do not run `renv::restore()` to render.** `renv.lock` pins the Linux cluster environment
in which the models were fitted (R 4.5.1, brms 2.23.0, cmdstanr 0.9.0). Rendering happens
in a different environment by design and needs far less: `rmarkdown`, `knitr`, `here`,
`dplyr` and `ggplot2`. The project `.Rprofile` activates renv only when both
`renv/activate.R` and a populated `renv/library/` are present, so a fresh clone stays on
the system library and renders without any of this getting in the way.

**PDF output needs a few LaTeX packages** beyond a bare TinyTeX: `koma-script`,
`footnotehyper`, `fontawesome5` and `pdfcol`. The engine is lualatex. `--to apaquarto-html`
needs none of them and is the quicker way to check a change.

One figure is optional. `depictr` (not on CRAN, `pak::pak('pablobernabeu/depictr')`)
supplies the theme and the colourblind-safe Okabe–Ito palette. Without it every figure
still renders, falling back to `theme_minimal()` and hand-coded colours.

## Re-fitting the models

The fits are cluster work, not desktop work: eighteen ERP cells, three accuracy models,
their prior-sensitivity refits, and a permutation decoding analysis. `HPC_RUNBOOK.md` gives
the layout and `paper_1_transfer/hpc/README.md` the per-stage submission recipes. The order
is set out in `paper_1_transfer/README.md`, and `paper_1_transfer/scripts/README.md` covers
the conventions.

Every fitting run records its own environment. `paper_1_transfer/results/_provenance.csv`,
written by `_shared/R/04_provenance.R` at the moment the models are fitted, holds the R,
brms, cmdstanr, rstan, StanHeaders, posterior, loo, projpred, bayesplot and CmdStan versions
that run actually loaded, together with the seeds. Where any other account of the
environment disagrees with that file, the file is right. CmdStan, the GCC toolchain and the
`CXXFLAGS_OPTIM = -O1` pin are not R packages, so no lockfile can carry them; they are set
in `_shared/hpc/arc_env.sh` and explained in the runbook.

## The companion paper

A second paper draws on the same cohort, asking which baseline cognitive and resting-state
EEG measures predict the learning trajectory. It has its own compendium at
<https://github.com/pablobernabeu/LESS-cognitive-predictors> and shares the `_shared/` code
and the cohort definition, but no result. Each paper is self-contained.

## Licence

CC BY 4.0. See [`Licence.md`](Licence.md).
