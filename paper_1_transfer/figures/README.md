# `paper_1_transfer/figures` — diagnostic images written by the fits

Almost every figure in Paper 1 is drawn at render time by an R chunk in the `.qmd`, from
the CSVs in [`../results/`](../results/README.md), and lands in
`paper_1_morphosyntax_files/`. What collects here is the smaller set the **fitting**
scripts write, which no chunk can redraw because they need the fitted models.

| Pattern | Written by |
|---------|------------|
| `<cell_tag>_priorpc.png` | The prior predictive check for one cell, written by step 3 (ERP) or step 4 (accuracy) when the job is submitted with `LES_PRIOR_PREDICTIVE=1`. |
| `<cell_tag>_ppc.png` | The posterior predictive check for one cell, written by the same two steps on every ordinary fitting run. |

None of these images is under version control, and the manuscript reads none of them.
Its prior predictive figure, the representative check the Priors section shows (gender
agreement, 400–900 ms, midline, maximal random-effect structure, informative priors), is
drawn at render time like the other figures. It reads two tables in `../results/`,
`_prior_predictive_check.csv` (the kernel density of the observed amplitudes and of each
dataset simulated from the priors, over the displayed range) and
`_prior_predictive_check_meta.csv` (one row describing the run, from which the figure note
takes its numbers). Both are written by `../scripts/03b_export_prior_predictive.R`, which
runs the same prior-only model as step 3's check and touches no fitted model. To
regenerate them, submit `../hpc/03b_prior_predictive.slurm` as its header shows. Without
the tables the chunk prints a placeholder panel, so the `@fig-priorpc` cross-reference
still resolves.

Until 26 October 2026 the figure was `prior_predictive_check.png`, a bayesplot panel that
step 3 copied here when submitted with `LES_PRIOR_PREDICTIVE=1` and
`LES_P1_PRIORPC_REPRESENTATIVE` set to the representative cell's tag (ISSUES.md X7-01).
Only a refit could redraw it, and it did not follow the house style. It was removed from
version control when the manuscript stopped reading it. Step 3 still makes that copy if
the variable is set, but nothing reads the file.
Steps 3 and 4 write one `_ppc` image per fitted `cell_tag` or `model_tag`, plus one
`_priorpc` image when `LES_PRIOR_PREDICTIVE=1`. Every variant run therefore adds a set of
its own beside that of the reported fits. These images are produced on the cluster and are
inspected by eye. The numerical convergence check is separate. `les_check_convergence()` in
[`../../_shared/R/02_diagnostics.R`](../../_shared/R/02_diagnostics.R) computes R̂, ESS and
divergences from the fitted models and opens no image. None of the images is required to
render the paper.
