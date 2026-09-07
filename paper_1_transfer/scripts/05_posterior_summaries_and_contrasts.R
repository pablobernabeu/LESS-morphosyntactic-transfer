# =============================================================================
# paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R
# Phase 2b -- Pool diagnostics/summaries, compute the retention contrasts and the
#             informative-vs-weak prior sensitivity
# =============================================================================
#
# WHAT THIS SCRIPT DOES
# ---------------------
# After the models in steps 03-04 have been fitted (locally or on the HPC), this
# script collates their machine-readable artefacts into the tables the manuscript
# reads, and derives the theory-critical RETENTION contrasts that are not single
# coefficients:
#   (1) pooled convergence gate     -> results/_pooled_convergence.csv
#   (2) pooled posterior summaries  -> results/_pooled_posterior_summaries.csv
#   (3) retention contrasts (S4->S6)-> results/_retention_contrasts.csv
#   (4) pooled fit metadata         -> results/_pooled_fit_metadata.csv
#   (5) prior sensitivity           -> results/_prior_sensitivity.csv
#
# THE RETENTION CONTRAST
# ----------------------
# Sessions 4 (end of training) and 6 (post-consolidation) bracket the retention
# interval. They enter here as their growth-curve session codes 2 and 3 (sessions
# 2, 3, 4 and 6 are coded 0, 1, 2, 3; see import_trialbytrial_EEG_data.R), read back
# off each cell's own data rather than from LES_RETENTION_SESSIONS, which this script
# does not consult. Because session enters the models as the
# continuous, standardised z_recoded_session, the change in the grammaticality
# effect between two sessions is a LINEAR COMBINATION of the posterior draws,
# evaluated exactly here rather than approximated. For the grammaticality effect
# G(s, l) at standardised session s and standardised language l,
#
#     G(s, l) = b_gram + b_gram:session * s + b_gram:lang * l
#               + b_gram:session:lang * s * l ,
#
# the retention shift is  G(z6, l) - G(z4, l) = (z6 - z4) * ( b_gram:session
#               + b_gram:session:lang * l ).
# We report it overall (l = 0, the standardised mean) and within each language.
# Reporting the full posterior of a derived quantity, with its 95% credible
# interval and probability of direction, is the recommended Bayesian practice
# (Makowski et al., 2019, https://doi.org/10.3389/fpsyg.2019.02767; Kruschke &
# Liddell, 2018, https://doi.org/10.3758/s13423-016-1221-4). No multiplicity
# correction is applied across the contrasts written here, on the same grounds the
# manuscript's Inference section states: within a model, hierarchical shrinkage across
# participants and items already regularises the estimates (Gelman, Hill & Yajima, 2012,
# https://doi.org/10.1080/19345747.2011.618213), and every cell is reported as an
# estimate rather than screened for significance, with no claim that the grid is immune
# to selection effects (Rubin, 2021, https://doi.org/10.1007/s11229-021-03276-4).
#
# WHAT THAT DERIVATION CANNOT SHOW, AND THE VARIANT THAT CAN
# ----------------------------------------------------------
# (z6 - z4) is a constant, so the overall contrast is the grammaticality x session
# coefficient rescaled. Multiplying a posterior by a constant leaves its probability of
# direction unchanged, and the artefacts bear this out: the retention pd equals the
# grammaticality x session pd in all 75 cells. The contrast is therefore the fitted
# trajectory evaluated over the retention step, not an independent estimate of it, and it
# cannot separate an offline gain specific to the unrehearsed interval from continued
# improvement at the training rate. It is reported, with that limitation stated in the
# manuscript, because it is still the change the fitted model implies over that interval.
#
# The exception is a property sampled at two sessions only: there the linear term IS the
# two-session change. Verb-object number agreement (Sessions 4 and 6) is such a property.
#
# Fitting with LES_P1_RETENTION_FREE=1 (see 03_fit_brms_erp.R) adds an explicit Session-6
# offset, so the linear term carries the training trend and the offset carries the
# deviation at retention. Where those fits exist, the block below reports the offset
# instead, which makes the retention row an estimate rather than an extrapolation.
# =============================================================================

suppressPackageStartupMessages({
  source(here::here("_shared", "R", "00_paths.R"))
  source(here::here("_shared", "R", "02_diagnostics.R"))
  source(here::here("paper_1_transfer", "scripts", "_config.R"))
  library(dplyr)
  library(posterior)
})

# --- Summarise a vector of posterior draws (median, 95% CrI, pd) --------------
.les_summarise_draws <- function(x, ci = 0.95) {
  lo <- (1 - ci) / 2; hi <- 1 - lo
  data.frame(
    median  = stats::median(x),
    ci_low  = stats::quantile(x, lo, names = FALSE),
    ci_high = stats::quantile(x, hi, names = FALSE),
    pd      = max(mean(x > 0), mean(x < 0))
  )
}

# --- (1), (2) and (4) Pool the per-model artefacts ----------------------------
pool_artefacts <- function() {
  # Byte-order sort, so the row order of the pooled CSVs does not depend on the collation
  # of the machine that ran the pooling.
  .ls <- function(pattern) {
    sort(list.files(paper1_results(), pattern = pattern, full.names = TRUE), method = "radix")
  }
  conv_files <- .ls("_convergence\\.rds$")
  summ_files <- .ls("_summary\\.rds$")
  meta_files <- .ls("_fitmeta\\.rds$")

  if (length(conv_files)) {
    # Take the model id from the FILE NAME rather than from inside the artefact, exactly as
    # the posterior summaries are pooled below. The cache tags (_keepmisfiltered,
    # _weakprior, _itemslope, _retfree, composed in that order) live only in the name, so
    # binding the stored `model` column alone produced several indistinguishable rows per
    # ERP cell, with no way to tell a maximal fit from a base one, or the informative prior
    # set from the weak baseline. The table in the manuscript is captioned as covering all
    # fitted models, so those rows have to be identifiable.
    conv <- dplyr::bind_rows(lapply(conv_files, function(f) {
      d <- readRDS(f)
      d$model <- sub("_convergence\\.rds$", "", basename(f))
      d
    }))
    # Tags compose as <cell>_itemslope_retfree, so the structure test must allow the
    # retention-free suffix, or every maximal retention-free fit is classified as base.
    conv$structure      <- ifelse(grepl("_itemslope(_retfree)?$", conv$model), "maximal", "base")
    conv$retention_free <- grepl("_retfree$", conv$model)
    conv$prior_variant  <- ifelse(grepl("_weakprior", conv$model), "weak", "informative")
    utils::write.csv(conv, paper1_results("_pooled_convergence.csv"), row.names = FALSE)
    message("[pool] convergence: ", sum(conv$passed, na.rm = TRUE), "/", nrow(conv),
            " models passed")
  }
  if (length(summ_files)) {
    summ <- dplyr::bind_rows(lapply(summ_files, function(f) {
      d <- readRDS(f); d$model <- sub("_summary\\.rds$", "", basename(f)); d
    }))
    utils::write.csv(summ, paper1_results("_pooled_posterior_summaries.csv"), row.names = FALSE)
    message("[pool] posterior summaries pooled for ", length(summ_files), " models")
  }
  # Per-fit record of the analysed sample, written by scripts 03 and 04. The
  # manuscript reads the pooled file to decide whether it may state that the
  # mis-filtered Session-3 datasets were excluded from the results it reports.
  if (length(meta_files)) {
    meta <- dplyr::bind_rows(lapply(meta_files, function(f) {
      d <- readRDS(f)
      b <- basename(f)
      # Recomputed from the file name for every record, so that fits written before
      # the `structure` column existed are classified the same way as recent ones.
      # This overwrites the fit-time value rather than only filling it in where it is
      # missing, so a record's structure always follows its cache tag.
      d$prior_variant  <- if (grepl("_weakprior", b)) "weak" else "informative"
      d$structure      <- if (grepl("_itemslope(_retfree)?_fitmeta\\.rds$", b)) "maximal"
                          else "base"
      d$retention_free <- grepl("_retfree_fitmeta\\.rds$", b)
      d$model_tag      <- sub("_fitmeta\\.rds$", "", b)
      d
    }))
    utils::write.csv(meta, paper1_results("_pooled_fit_metadata.csv"), row.names = FALSE)
    n_app <- sum(meta$exclusion_applicable, na.rm = TRUE)
    message("[pool] fit metadata for ", nrow(meta), " models; exclusion applies to ", n_app,
            " and is satisfied by ",
            sum(meta$exclusion_applicable & meta$exclusion_applied, na.rm = TRUE))
  } else {
    message("[pool] no fit metadata found -- fits predate the fit-time exclusion record")
  }
}

# --- z-scale values of a recoded predictor, recovered from the cell data ------
# z_recoded_* are deterministic transforms of recoded_*, so the standardised value
# for a given recoded level is simply read back from the data (no rescaling math).
.les_zval <- function(dat, recoded_col, z_col, recoded_level) {
  v <- unique(dat[[z_col]][dat[[recoded_col]] == recoded_level])
  v <- v[!is.na(v)]
  if (length(v) != 1) return(NA_real_)
  v
}

# --- Find a fixed-effect draw by its COMPONENTS, not by a written term order --
# R's terms() orders the components of an interaction by the order in which each
# variable first appears across the WHOLE formula, not by the order written in
# the product that introduced it. `z_recoded_mini_language` appears in the base
# grammaticality * session * language product, so the retention-free formula's
# `grammaticality * z_retention * mini_language` yields the coefficient
# "b_...grammaticality:...mini_language:z_retention", NOT the written
# "...grammaticality:z_retention:...mini_language". Hard-coding either order is
# a silent trap: the lookup returns NULL and the contrast is quietly dropped
# rather than erroring. Matching on the component SET is order-independent.
.les_draw_term <- function(draws, ...) {
  parts <- c(...)
  nm <- grep("^b_", names(draws), value = TRUE)
  hit <- vapply(nm, function(n) {
    setequal(strsplit(sub("^b_", "", n), ":", fixed = TRUE)[[1]], parts)
  }, logical(1))
  if (sum(hit) != 1L) return(NULL)
  draws[[nm[hit][1]]]
}

# --- Retention contrast (S4 -> S6) for one fitted model + its data ------------
# A model without a language term simply has no three-way draw to find, so the
# language-scoped rows are governed by whether that term exists rather than by a
# switch the caller has to set.
retention_contrast <- function(fit, dat, model_id) {
  draws <- posterior::as_draws_df(fit)

  z4 <- .les_zval(dat, "recoded_session", "z_recoded_session", 2)  # Session 4 -> code 2
  z6 <- .les_zval(dat, "recoded_session", "z_recoded_session", 3)  # Session 6 -> code 3
  if (is.na(z4) || is.na(z6)) {
    message("[retention] ", model_id, ": sessions 4/6 not both present -- skipped")
    return(NULL)
  }
  dz <- z6 - z4

  # A model fitted with LES_P1_RETENTION_FREE=1 carries an explicit Session-6 offset. There
  # the retention estimate is that offset, not the linear slope: the linear term now carries
  # the training trend only. z_retention is coded -0.5/+0.5, so a unit change spans the
  # contrast and the coefficient IS the deviation at retention. Preferring it when present
  # is what makes the retention row an estimate rather than the training slope rescaled.
  b_ret  <- .les_draw_term(draws, "z_recoded_grammaticality", "z_retention")
  b_retl <- .les_draw_term(draws, "z_recoded_grammaticality", "z_retention",
                           "z_recoded_mini_language")
  if (!is.null(b_ret)) {
    rows <- list(cbind(model = model_id, contrast = "overall",
                       .les_summarise_draws(b_ret)))
    if (!is.null(b_retl)) {
      wl <- list()
      for (lvl in c("Mini-Norwegian", "Mini-English")) {
        code <- if (lvl == "Mini-Norwegian") 0.5 else -0.5
        lz <- .les_zval(dat, "recoded_mini_language", "z_recoded_mini_language", code)
        if (is.na(lz)) next
        wl[[lvl]] <- b_ret + b_retl * lz
        rows[[length(rows) + 1]] <- cbind(
          model = model_id, contrast = paste0("within_", lvl),
          .les_summarise_draws(wl[[lvl]]))
      }
      # Between-language difference in the retention change, so any statement about
      # the two languages' similarity cites an estimated quantity with its own
      # uncertainty rather than the visual similarity of two separate contrasts.
      if (length(wl) == 2) {
        rows[[length(rows) + 1]] <- cbind(
          model = model_id, contrast = "language_difference",
          .les_summarise_draws(wl[["Mini-Norwegian"]] - wl[["Mini-English"]]))
      }
    }
    return(do.call(rbind, rows))
  }

  b_gs <- .les_draw_term(draws, "z_recoded_grammaticality", "z_recoded_session")
  if (is.null(b_gs)) {
    message("[retention] ", model_id, ": no grammaticality:session term -- skipped")
    return(NULL)
  }
  b_gsl <- .les_draw_term(draws, "z_recoded_grammaticality", "z_recoded_session",
                          "z_recoded_mini_language")

  rows <- list(cbind(model = model_id, contrast = "overall",
                     .les_summarise_draws(dz * b_gs)))

  if (!is.null(b_gsl)) {
    wl <- list()
    for (lvl in c("Mini-Norwegian", "Mini-English")) {
      code <- if (lvl == "Mini-Norwegian") 0.5 else -0.5
      lz <- .les_zval(dat, "recoded_mini_language", "z_recoded_mini_language", code)
      if (is.na(lz)) next
      wl[[lvl]] <- dz * (b_gs + b_gsl * lz)
      rows[[length(rows) + 1]] <- cbind(
        model = model_id, contrast = paste0("within_", lvl),
        .les_summarise_draws(wl[[lvl]])
      )
    }
    # As in the freed-retention branch: the between-language difference as its own
    # estimated contrast (here dz * b_gsl * (lz_N - lz_E)).
    if (length(wl) == 2) {
      rows[[length(rows) + 1]] <- cbind(
        model = model_id, contrast = "language_difference",
        .les_summarise_draws(wl[["Mini-Norwegian"]] - wl[["Mini-English"]]))
    }
  }
  do.call(rbind, rows)
}

# --- Collect retention contrasts across ERP cells and accuracy models ---------
collect_retention <- function() {
  out <- list()

  # ERP cells, for every random-effect structure and prior set that has been fitted.
  # The manuscript reports the maximal (crossed participant-and-item) structure as
  # primary, so its contrasts must exist alongside the simpler ones rather than the
  # table silently covering only whichever structure happened to be fitted first.
  grid <- les_p1_erp_grid()
  # Tags are appended by 03_fit_brms_erp.R in the order mis-filter -> prior -> item ->
  # retention (cell_tag <- paste0(cell_id, les_p1_misfiltered_tag(), les_prior_tag(),
  # les_p1_item_tag(), les_p1_retention_tag())), so a maximal-structure retention-free
  # fit is "<cell>_itemslope_retfree" and its mis-filter-retained twin
  # "<cell>_keepmisfiltered_itemslope_retfree". Every variant must be enumerated here or
  # its contrasts never reach _retention_contrasts.csv and the manuscript keeps printing
  # its pending marker with nothing to show why.
  base_variants <- c("", "_itemslope", "_weakprior", "_weakprior_itemslope",
                     "_retfree", "_itemslope_retfree")
  variants <- c(base_variants, paste0("_keepmisfiltered", base_variants))
  for (i in seq_len(nrow(grid))) {
    cell <- grid$cell_id[i]
    # z4 and z6 are read off the data each fit was computed from, so the mis-filter-
    # retained fits are paired with their own derived file (02 and 01 write those under
    # the tag; see les_p1_cell_rds() in _config.R) and never with the reported data.
    fdat <- c(reported        = les_p1_cell_rds(grid$property[i], grid$window[i],
                                                grid$macroregion[i]),
              keepmisfiltered = paper1_derived(paste0(cell, "_keepmisfiltered.rds")))
    dat <- list()
    for (v in variants) {
      mid  <- paste0(cell, v)
      ffit <- paper1_results(paste0(mid, ".rds"))
      if (!file.exists(ffit)) next
      key <- if (startsWith(v, "_keepmisfiltered")) "keepmisfiltered" else "reported"
      if (!file.exists(fdat[[key]])) next
      if (is.null(dat[[key]])) dat[[key]] <- readRDS(fdat[[key]])
      out[[mid]] <- retention_contrast(readRDS(ffit), dat[[key]], mid)
    }
  }

  # Accuracy models, reported and with the diversity covariate (LES_P1_ACC_DIVERSITY=1),
  # each paired with the derived file 02 wrote for it.
  for (p in names(LES_P1_PROPERTIES)) {
    for (tag in c("", "_diversity")) {
      mid  <- paste0("accuracy_", p, tag)
      ffit <- paper1_results(paste0(mid, ".rds"))
      fdat <- paper1_derived(paste0("accuracy_", p, tag, ".rds"))
      if (file.exists(ffit) && file.exists(fdat)) {
        out[[mid]] <- retention_contrast(readRDS(ffit), readRDS(fdat), mid)
      }
    }
  }

  res <- do.call(rbind, out)
  if (!is.null(res)) {
    utils::write.csv(res, paper1_results("_retention_contrasts.csv"), row.names = FALSE)
    message("[retention] wrote ", nrow(res), " contrasts")
  } else {
    message("[retention] no fitted models found yet")
  }
  invisible(res)
}

# --- Language modulation at a property's FIRST session -------------------------
# With session z-scored, the grammaticality x language coefficient is the source-
# language advantage at the AVERAGE session and the three-way term is its growth.
# Whether the advantage was already present when the property was first probed is
# the quantity that separates transfer present from first exposure (as wholesale
# projection predicts) from an advantage that only accrues with exposure -- and it
# is a linear combination of draws, not a new model:
#     advantage(first session) = b_gl + z_first * b_gsl ,
# z_first being the z-score of the property's earliest measured session. Computed
# for the three accuracy models (the behavioural advantage is where the adjudication
# rests) and written to results/_first_session_language_advantage.csv.
first_session_advantage <- function() {
  out <- list()
  for (p in names(LES_P1_PROPERTIES)) {
    for (tag in c("", "_diversity")) {
      mid  <- paste0("accuracy_", p, tag)
      ffit <- paper1_results(paste0(mid, ".rds"))
      fdat <- paper1_derived(paste0("accuracy_", p, tag, ".rds"))
      if (!file.exists(ffit) || !file.exists(fdat)) next
      fit <- readRDS(ffit); dat <- readRDS(fdat)
      draws <- posterior::as_draws_df(fit)
      b_gl  <- draws[["b_z_recoded_grammaticality:z_recoded_mini_language"]]
      b_gsl <- draws[["b_z_recoded_grammaticality:z_recoded_session:z_recoded_mini_language"]]
      if (is.null(b_gl) || is.null(b_gsl)) next
      first_code <- min(dat$recoded_session, na.rm = TRUE)
      z_first <- .les_zval(dat, "recoded_session", "z_recoded_session", first_code)
      if (is.na(z_first)) next
      out[[mid]] <- cbind(model = mid, contrast = "gram_x_language_at_first_session",
                          .les_summarise_draws(b_gl + z_first * b_gsl))
    }
  }
  res <- do.call(rbind, out)
  if (!is.null(res)) {
    utils::write.csv(res, paper1_results("_first_session_language_advantage.csv"),
                     row.names = FALSE)
    message("[first-session] wrote ", nrow(res), " row(s)")
  } else {
    message("[first-session] no fitted accuracy models found")
  }
  invisible(res)
}

# --- (5) Prior sensitivity: informative vs weakly-informative ----------------
# The manuscript reports the largest informative-vs-weak shift among the
# grammaticality terms, reading it from results/_prior_sensitivity.csv. That file
# used to be produced ad hoc, with no pipeline step that wrote it, so it silently
# went stale whenever one prior set was refitted and the other was not -- and a
# shift computed across two different datasets measures the difference between the
# datasets, not between the priors. Building it here ties it to the same run that
# pools everything else, and the guard below refuses to emit a comparison whose two
# sides were not fitted to the same data.
collect_prior_sensitivity <- function() {
  meta_path <- paper1_results("_pooled_fit_metadata.csv")
  meta <- if (file.exists(meta_path)) utils::read.csv(meta_path, stringsAsFactors = FALSE) else NULL

  # Each entry is (informative id, weak id), named by the informative id. The ERP cells
  # appear once per random-effect structure, because the manuscript reports a
  # prior-sensitivity figure for whichever structure is primary and the two must not be
  # pooled: they are different models, and a shift computed across them would confound
  # prior with structure exactly as the pre-exclusion comparison confounded prior with
  # sample. The same holds for the retention-free, mis-filter-retained and
  # diversity-covariate variants, which are paired only with a weak-prior refit carrying
  # the same tags. The prior tag sits between the mis-filter tag and the structure tags
  # (see cell_tag in 03_fit_brms_erp.R), which is why the weak id is composed from its
  # parts.
  cells <- les_p1_erp_grid()$cell_id
  erp_pairs <- function(mis = "", item = "", ret = "") {
    ids <- paste0(cells, mis, item, ret)
    stats::setNames(lapply(cells, function(c) {
      c(paste0(c, mis, item, ret), paste0(c, mis, "_weakprior", item, ret))
    }), ids)
  }
  acc_pairs <- function(tag = "") {
    ids <- paste0("accuracy_", names(LES_P1_PROPERTIES), tag)
    stats::setNames(lapply(ids, function(a) c(a, paste0(a, "_weakprior"))), ids)
  }
  pairs <- c(
    erp_pairs(),                                             # base structure
    erp_pairs(item = "_itemslope"),                          # maximal structure
    erp_pairs(item = "_itemslope", ret = "_retfree"),        # maximal, retention-free
    erp_pairs(mis = "_keepmisfiltered"),
    erp_pairs(mis = "_keepmisfiltered", item = "_itemslope"),
    erp_pairs(mis = "_keepmisfiltered", item = "_itemslope", ret = "_retfree"),
    acc_pairs(),
    acc_pairs("_diversity")
  )
  out <- list()
  for (id in names(pairs)) {
    inf_id <- pairs[[id]][1]; weak_id <- pairs[[id]][2]
    inf_f  <- paper1_results(paste0(inf_id,  "_summary.rds"))
    weak_f <- paper1_results(paste0(weak_id, "_summary.rds"))
    if (!file.exists(inf_f) || !file.exists(weak_f)) next

    # Same-data check: compare the two fits' recorded sample sizes where available.
    # The fit-time record carries the model id without the structure and retention tags
    # (03 records paste0(cell_id, les_p1_misfiltered_tag()); 04 records the accuracy id
    # with its diversity tag), so the lookup is keyed on the bare id together with the
    # structure and, where the pooled table carries it, the retention_free column that
    # pool_artefacts() derives from the file name. Base and maximal fits, and reported and
    # retention-free fits, share a bare id and would otherwise match two rows each and
    # skip the check.
    struct <- if (grepl("_itemslope(_retfree)?$", id)) "maximal" else "base"
    bare   <- sub("(_itemslope)?(_retfree)?$", "", id)
    if (!is.null(meta) && "structure" %in% names(meta)) {
      same <- meta$model == bare & meta$structure == struct
      if ("retention_free" %in% names(meta)) {
        same <- same & (meta$retention_free %in% grepl("_retfree$", id))
      }
      n_inf  <- meta$n_obs[same & meta$prior_variant == "informative"]
      n_weak <- meta$n_obs[same & meta$prior_variant == "weak"]
      if (length(n_inf) == 1 && length(n_weak) == 1 && !identical(n_inf, n_weak)) {
        message("[sensitivity] ", id, ": informative n=", n_inf, " but weak n=", n_weak,
                " -- fitted to different data, skipped")
        next
      }
      if (length(n_inf) == 1 && length(n_weak) == 0) {
        message("[sensitivity] ", id, ": the weak-prior fit predates the fit-time record, ",
                "so it cannot be confirmed to share the informative fit's data -- skipped")
        next
      }
    }
    s <- try(les_prior_sensitivity(paper1_results(), inf_id, weak_id = weak_id),
             silent = TRUE)
    if (inherits(s, "try-error")) next
    s$model     <- inf_id
    s$structure <- struct
    out[[id]] <- s
  }

  res <- if (length(out)) do.call(rbind, out) else NULL
  f <- paper1_results("_prior_sensitivity.csv")
  if (!is.null(res)) {
    utils::write.csv(res, f, row.names = FALSE)
    message("[sensitivity] wrote ", nrow(res), " rows for ", length(out), " models")
  } else {
    # Do not leave a stale file standing: the manuscript would read it as current.
    if (file.exists(f)) {
      file.remove(f)
      message("[sensitivity] no comparable pairs; removed the stale _prior_sensitivity.csv ",
              "so the manuscript prints its pending marker instead")
    } else {
      message("[sensitivity] no comparable informative/weak pairs yet")
    }
  }
  invisible(res)
}

# =============================================================================
.run <- function() {
  pool_artefacts()
  collect_retention()
  first_session_advantage()
  collect_prior_sensitivity()
  message("[summaries] done.")
}

if (sys.nframe() == 0L) .run()
