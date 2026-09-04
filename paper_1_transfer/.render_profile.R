# Intentionally empty. Set as R_PROFILE_USER to suppress the project .Rprofile during
# local Quarto rendering.
#
# It was added when .Rprofile sourced renv/activate.R unconditionally and so failed on a
# box where renv had never been set up. .Rprofile has since been guarded on renv/activate.R
# existing and renv/library being populated, and both manuscripts render correctly with no
# R_PROFILE_USER set at all (verified 2026-08-11, and again after the guard was tightened).
# A fresh clone carries the activation script but an empty library, so the guard stays
# false there too and this override is not needed to render one.
#
# It is kept for the working copy that DOES have a populated renv library, where a render
# would otherwise resolve its packages through renv mid-render, and because two documents
# send readers here: paper_1_transfer/README.md, under "Rendering the manuscript", and
# paper_2_plasticity/hpc/README.md, under "Then render". HPC_RUNBOOK.md, which an earlier
# version of this note credited, sets no R_PROFILE_USER at all. Remove this file only
# together with those two references.
