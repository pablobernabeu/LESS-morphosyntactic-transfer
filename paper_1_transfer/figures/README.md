# `paper_1_transfer/figures` — diagnostic images written by the fits

Almost every figure in Paper 1 is drawn at render time by an R chunk in the `.qmd`, from
the CSVs in [`../results/`](../results/README.md), and lands in
`paper_1_morphosyntax_files/`. What collects here is the smaller set the **fitting**
scripts write, which no chunk can redraw because they need the fitted models.

| Pattern | Written by |
|---------|------------|
| `<cell_tag>_priorpc.png` | The prior predictive check for one cell, written by step 3 (ERP) or step 4 (accuracy) when the job is submitted with `LES_PRIOR_PREDICTIVE=1`. |
| `<cell_tag>_ppc.png` | The posterior predictive check for one cell, written by the same two steps on every ordinary fitting run. |
| `prior_predictive_check.png` | The one file here under version control, and the only one the manuscript reads. |

`prior_predictive_check.png` is the representative check the Priors section shows: gender
agreement, 400–900 ms, midline, as its caption states. It is kept in the repository so
that a checkout without the cluster outputs still renders a complete manuscript. The chunk
is guarded on the file existing, and falls back to a "pending figure generation" panel if
it is absent. Without that branch, the chunk would emit nothing at all and the
`@fig-priorpc` cross-reference in the text would render as a dangling reference.

The committed copy was placed here by hand, and the `<cell_tag>` it came from is not
recorded: the caption names the cell, but whether the panel was drawn under the base or
the maximal random-effect structure, and under the informative or the weak prior set, has
to be confirmed by the authors. Once confirmed, regenerate it with a recorded source by
submitting step 3 with `LES_PRIOR_PREDICTIVE=1` and `LES_P1_PRIORPC_REPRESENTATIVE` set to
the full tag, for example
`sbatch --export=ALL,LES_P1_ITEM_SLOPE=1,LES_PRIOR_PREDICTIVE=1,LES_P1_PRIORPC_REPRESENTATIVE=erp_gender_agreement_400_900_midline_itemslope paper_1_transfer/hpc/03_fit_erp.slurm`
for the maximal-structure, informative-prior panel of that cell (the tag has to match the
switches of the run: `_itemslope` needs `LES_P1_ITEM_SLOPE=1`, `_weakprior` needs
`LES_PRIOR_SET=weak`). The array task whose `cell_tag` equals the named value copies its
`<cell_tag>_priorpc.png` to this name; with the variable unset no run writes this file. If
you show a different cell, change the caption in the `.qmd` to match, since the caption
names the cell.

The `_priorpc` and `_ppc` files for the other seventeen ERP cells and the three accuracy
models are produced on the cluster and are diagnostic. They are read by eye, or through
`les_check_convergence()` in [`../../_shared/R/02_diagnostics.R`](../../_shared/R/02_diagnostics.R),
and none of them is required to render the paper.
