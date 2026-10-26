# =============================================================================
# paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R
# Phase 2b -- Pool diagnostics/summaries, compute the retention contrasts, the
#             informative-vs-weak prior sensitivity and the signal-detection contrasts
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
#   (6) first-session language advantage
#                                   -> results/_first_session_language_advantage.csv
#   (7) signal-detection contrasts  -> results/_accuracy_sdt_contrasts.csv
# The rows of (3) for a retention-free fit (tag `_retfree`) carry the same contrast keys
# as the others but a different estimand, the Session-6 deviation from the training trend
# (see below); only the model id tells them apart. It stops without writing anything when
# results/ holds no fitted artefacts.
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
# direction unchanged, so in every fit without the retention offset the retention pd equals
# the grammaticality x session pd, as the pooled artefacts show. The contrast is therefore
# the fitted trajectory evaluated over the retention step, not an independent estimate of
# it, and it cannot separate an offline gain specific to the unrehearsed interval from
# continued improvement at the training rate. It is reported, with that limitation stated
# in the manuscript, because it is still the change the fitted model implies over that
# interval.
#
# The exception is a property sampled at two sessions only: there the linear term IS the
# two-session change. Verb-object number agreement (Sessions 4 and 6) is such a property.
#
# Fitting with LES_P1_RETENTION_FREE=1 (see 03_fit_brms_erp.R) adds an explicit Session-6
# offset, so the linear term carries the training trend and the offset carries the
# deviation at retention. Where those fits exist, the block below reports the offset
# instead, which makes the retention row an estimate rather than an extrapolation.
#
# For the accuracy models the grammaticality terms are response bias (see the header of
# 04_fit_brms_accuracy.R), so their rows in (3) are a change in bias. The manuscript reports
# the judgement models through (7) instead and reads only the ERP rows of (3).
# =============================================================================

suppressPackageStartupMessages({
  source(here::here("_shared", "R", "00_paths.R"))
  source(here::here("_shared", "R", "02_diagnostics.R"))
  source(here::here("paper_1_transfer", "scripts", "_config.R"))
  library(dplyr)
  library(posterior)
})

#' Summarise a vector of posterior draws
#'
#' The same median, equal-tailed credible interval and probability of direction that
#' les_posterior_summary() (_shared/R/02_diagnostics.R) computes per coefficient, so a
#' derived contrast and a coefficient are summarised alike.
#' @param x Numeric vector of draws.
#' @param ci Credible-interval mass.
#' @return A one-row data frame with columns median, ci_low, ci_high and pd.
.les_summarise_draws <- function(x, ci = 0.95) {
  lo <- (1 - ci) / 2; hi <- 1 - lo
  data.frame(
    median  = stats::median(x),
    ci_low  = stats::quantile(x, lo, names = FALSE),
    ci_high = stats::quantile(x, hi, names = FALSE),
    pd      = max(mean(x > 0), mean(x < 0))
  )
}

#' Is an ERP fit of the current model specification?
#'
#' Every step below that reads ERP artefacts by file name applies it, so a superseded
#' cluster-row fit left in the results directory never reaches a pooled table.
#' @param tag ERP model tag, the file stem without an artefact suffix.
#' @return TRUE when results/<tag>_fitmeta.rds exists and carries LES_P1_ERP_MODEL_VERSION.
.les_erp_tag_current <- function(tag) {
  fm <- paper1_results(paste0(tag, "_fitmeta.rds"))
  if (!file.exists(fm)) return(FALSE)
  rec <- readRDS(fm)
  "erp_model_version" %in% names(rec) && identical(rec$erp_model_version[1], LES_P1_ERP_MODEL_VERSION)
}

#' Accuracy fit tags, in table order
#'
#' Step 04 composes the accuracy tags as accuracy_<property>[_diversity][_rtscreen]
#' [_maxranef][_byitem][_weakprior] (model_tag in 04_fit_brms_accuracy.R). Only _diversity
#' and _rtscreen change the data, so each fit is paired with
#' accuracy_<property><dtag>.rds. The tags in `first` come first, in the order each table
#' had before the remaining combinations were added, so the rows of existing fits keep
#' their order.
#' @param first Character vector of tags to list first.
#' @return A data frame with columns tag (the fit's tag after the property) and dtag (the
#'   derived-data tag).
.les_acc_variants <- function(first) {
  g <- expand.grid(p = c("", "_weakprior"), i = c("", "_byitem"), m = c("", "_maxranef"),
                   d = c("", "_diversity", "_rtscreen"), stringsAsFactors = FALSE)
  tags <- paste0(g$d, g$m, g$i, g$p)
  tags <- c(first, setdiff(tags, first))
  data.frame(tag = tags, dtag = sub("^((_diversity)?(_rtscreen)?).*$", "\\1", tags),
             stringsAsFactors = FALSE)
}

#' Fits in results/ that a step did not enumerate
#'
#' A new cache tag added to 03 or 04 must also be enumerated where a step builds model ids
#' from tags, or its fits silently produce no rows there. This names them instead.
#' @param considered Character vector of the model ids the step looked for.
#' @param step Label for the message.
#' @param family Regular expression for the model families the step covers ("erp",
#'   "accuracy" or both).
#' @return The ids of fitted models (results/<id>.rds) of those families not in
#'   `considered`, invisibly; they are also reported with message().
.les_unlisted_fits <- function(considered, step, family = "erp|accuracy") {
  fits <- sub("\\.rds$", "", list.files(paper1_results(),
                                        pattern = paste0("^(", family, ")_.*\\.rds$")))
  fits <- setdiff(fits[!grepl("_(convergence|summary|fitmeta)$", fits)], considered)
  if (length(fits)) {
    message("[", step, "] ", length(fits), " fit(s) carry tags this step does not enumerate ",
            "and get no rows: ", paste(fits, collapse = ", "))
  }
  invisible(fits)
}

# --- (1), (2) and (4) Pool the per-model artefacts ----------------------------
#' Pool the per-model artefacts
#'
#' Binds every results/*_convergence.rds, *_summary.rds and *_fitmeta.rds into one table
#' each, taking the model id and its tags from the file name. The model tags are those of
#' step 03 (_exclreproc, _weakprior, _itemslope, _retfree, composed in that order) and of
#' step 04 (_diversity, _maxranef, _byitem, _weakprior, in that order). ERP artefacts of a
#' superseded specification are left out (.les_erp_tag_current()).
#' @return The pooled fit metadata as a data frame, or NULL when there is none, invisibly.
#'   Writes results/_pooled_convergence.csv, _pooled_posterior_summaries.csv and
#'   _pooled_fit_metadata.csv, each only when there are artefacts of its kind.
pool_artefacts <- function() {
  # Byte-order sort, so the row order of the pooled CSVs does not depend on the collation
  # of the machine that ran the pooling.
  .ls <- function(pattern) {
    sort(list.files(paper1_results(), pattern = pattern, full.names = TRUE), method = "radix")
  }
  conv_files <- .ls("_convergence\\.rds$")
  summ_files <- .ls("_summary\\.rds$")
  meta_files <- .ls("_fitmeta\\.rds$")

  # Pool only ERP fits of the current model specification. The trial-level change of 17
  # September 2026 kept every cache tag's name, so without this check a partial refit would
  # pool new trial-level fits with superseded cluster-row fits, whose intervals were too
  # narrow, in the same tables. An ERP artefact is current only if its fit record exists and
  # carries LES_P1_ERP_MODEL_VERSION. Accuracy artefacts are unaffected.
  .tag_of <- function(f) sub("_(convergence|summary|fitmeta)\\.rds$", "", basename(f))
  erp_tags <- unique(grep("^erp_", .tag_of(c(conv_files, summ_files, meta_files)), value = TRUE))
  current <- vapply(erp_tags, .les_erp_tag_current, logical(1))
  stale <- erp_tags[!current]
  if (length(stale)) {
    message("[pool] left out ", length(stale), " ERP fit(s) of a superseded specification or ",
            "without a fit record: ", paste(stale, collapse = ", "))
    .keep <- function(files) files[!.tag_of(files) %in% stale]
    conv_files <- .keep(conv_files); summ_files <- .keep(summ_files); meta_files <- .keep(meta_files)
  }

  if (length(conv_files)) {
    # Take the model id from the FILE NAME rather than from inside the artefact, exactly as
    # the posterior summaries are pooled below. The cache tags live only in the name, so
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
  meta <- NULL
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
  invisible(meta)
}

#' Standardised value of one level of a recoded predictor
#'
#' z_recoded_* are deterministic transforms of recoded_*, so the standardised value for a
#' given recoded level is simply read back from the data (no rescaling math).
#' @param dat The data frame a model was fitted to.
#' @param recoded_col,z_col Names of the recoded column and its z-scored twin.
#' @param recoded_level The level of `recoded_col` to look up.
#' @return The single z value of that level, or NA when the level is absent or maps to more
#'   than one z value.
.les_zval <- function(dat, recoded_col, z_col, recoded_level) {
  v <- unique(dat[[z_col]][dat[[recoded_col]] == recoded_level])
  v <- v[!is.na(v)]
  if (length(v) != 1) return(NA_real_)
  v
}

#' Find a fixed-effect draw by its components, not by a written term order
#'
#' R's terms() orders the components of an interaction by the order in which each variable
#' first appears across the WHOLE formula, not by the order written in the product that
#' introduced it. `z_recoded_mini_language` appears in the base grammaticality * session *
#' language product, so the retention-free formula's `grammaticality * z_retention *
#' mini_language` yields the coefficient "b_...grammaticality:...mini_language:z_retention",
#' NOT the written "...grammaticality:z_retention:...mini_language". Hard-coding either
#' order is a silent trap: the lookup returns NULL and the contrast is quietly dropped
#' rather than erroring. Matching on the component SET is order-independent.
#' @param draws A draws_df from posterior::as_draws_df().
#' @param ... Character names of the term's components, without the "b_" prefix.
#' @return The numeric draws of the one population-level coefficient whose components are
#'   exactly those given, or NULL when none or several match.
.les_draw_term <- function(draws, ...) {
  parts <- c(...)
  nm <- grep("^b_", names(draws), value = TRUE)
  hit <- vapply(nm, function(n) {
    setequal(strsplit(sub("^b_", "", n), ":", fixed = TRUE)[[1]], parts)
  }, logical(1))
  if (sum(hit) != 1L) return(NULL)
  draws[[nm[hit][1]]]
}

#' Retention contrast (S4 -> S6) for one fitted model and its data
#'
#' A model without a language term simply has no three-way draw to find, so the
#' language-scoped rows are governed by whether that term exists rather than by a switch
#' the caller has to set. For a retention-free fit the rows carry the z_retention offset,
#' the Session-6 deviation from the training trend, under the same contrast keys.
#' @param fit A brmsfit.
#' @param dat The data frame it was fitted to, from which the session and language z codes
#'   are read.
#' @param model_id Label written into the model column.
#' @return A data frame with columns model, contrast ("overall", "within_Mini-Norwegian",
#'   "within_Mini-English", "language_difference"), median, ci_low, ci_high and pd, or NULL
#'   (with a message) when the contrast cannot be formed.
retention_contrast <- function(fit, dat, model_id) {
  draws <- posterior::as_draws_df(fit)

  z4 <- .les_zval(dat, "recoded_session", "z_recoded_session", 2)  # Session 4 -> code 2
  z6 <- .les_zval(dat, "recoded_session", "z_recoded_session", 3)  # Session 6 -> code 3
  if (is.na(z4) || is.na(z6)) {
    message("[retention] ", model_id, ": Session 4 or 6 is absent from the data, or its ",
            "session z code is not unique -- skipped")
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

# --- (3) Collect retention contrasts across ERP cells and accuracy models ------
#' Collect the retention contrasts of every fitted ERP cell and accuracy model
#'
#' ERP cells are covered for every random-effect structure and prior set that has been
#' fitted. The manuscript reports the maximal (crossed participant-and-item) structure as
#' primary, so its contrasts must exist alongside the simpler ones rather than the table
#' silently covering only whichever structure happened to be fitted first. Each fit is
#' paired with the derived file it was fitted to, read from data_derived/. Fits whose tags
#' are not enumerated here are named in a message (.les_unlisted_fits()).
#' @return The contrasts as a data frame (see retention_contrast()), or NULL, invisibly.
#'   Writes results/_retention_contrasts.csv when there is at least one row.
collect_retention <- function() {
  out <- list()
  considered <- character(0)
  n_found <- 0L

  grid <- les_p1_erp_grid()
  # Tags are appended by 03_fit_brms_erp.R in the order robustness -> prior -> item ->
  # retention (cell_tag <- paste0(cell_id, les_p1_exclreproc_tag(), les_prior_tag(),
  # les_p1_item_tag(), les_p1_retention_tag())), so a maximal-structure retention-free
  # fit is "<cell>_itemslope_retfree" and its robustness twin
  # "<cell>_exclreproc_itemslope_retfree". Every variant must be enumerated here or
  # its contrasts never reach _retention_contrasts.csv and the manuscript keeps printing
  # its pending marker; .les_unlisted_fits() below names any fit that is missed. The
  # weak-prior retention-free combinations are listed although none has been fitted, so a
  # future refit is picked up; they come last so the order of existing rows is unchanged.
  base_variants <- c("", "_itemslope", "_weakprior", "_weakprior_itemslope",
                     "_retfree", "_itemslope_retfree",
                     "_weakprior_retfree", "_weakprior_itemslope_retfree")
  variants <- c(base_variants, paste0("_exclreproc", base_variants))
  for (i in seq_len(nrow(grid))) {
    cell <- grid$cell_id[i]
    # z4 and z6 are read off the data each fit was computed from, so the robustness fits
    # are paired with their own derived file (01 writes those under the tag; see
    # les_p1_cell_rds() in _config.R) and never with the primary data. The paths are spelt
    # out rather than taken from les_p1_cell_rds(), which follows
    # LES_P1_EXCLUDE_REPROCESSED in the calling environment; this step pairs both itself.
    fdat <- c(reported   = paper1_derived(paste0(cell, ".rds")),
              exclreproc = paper1_derived(paste0(cell, "_exclreproc.rds")))
    dat <- list()
    for (v in variants) {
      mid  <- paste0(cell, v)
      considered <- c(considered, mid)
      ffit <- paper1_results(paste0(mid, ".rds"))
      if (!file.exists(ffit)) next
      n_found <- n_found + 1L
      # Only fits of the current specification (see pool_artefacts()).
      fm <- paper1_results(paste0(mid, "_fitmeta.rds"))
      if (!file.exists(fm) || !identical(readRDS(fm)$erp_model_version[1], LES_P1_ERP_MODEL_VERSION)) {
        message("[retention] ", mid, ": superseded specification or no fit record -- skipped")
        next
      }
      key <- if (startsWith(v, "_exclreproc")) "exclreproc" else "reported"
      if (!file.exists(fdat[[key]])) {
        message("[retention] ", mid, ": its derived data ", basename(fdat[[key]]),
                " are missing -- skipped")
        next
      }
      if (is.null(dat[[key]])) dat[[key]] <- readRDS(fdat[[key]])
      out[[mid]] <- retention_contrast(readRDS(ffit), dat[[key]], mid)
    }
  }

  # Accuracy models, every variant step 04 can write (.les_acc_variants()), each paired with
  # the derived file 02 wrote for it. The reported and _diversity fits keep their places.
  acc <- .les_acc_variants(first = c("", "_diversity"))
  for (p in names(LES_P1_PROPERTIES)) {
    for (v in seq_len(nrow(acc))) {
      mid  <- paste0("accuracy_", p, acc$tag[v])
      considered <- c(considered, mid)
      ffit <- paper1_results(paste0(mid, ".rds"))
      fdat <- paper1_derived(paste0("accuracy_", p, acc$dtag[v], ".rds"))
      if (!file.exists(ffit)) next
      n_found <- n_found + 1L
      if (!file.exists(fdat)) {
        message("[retention] ", mid, ": its derived data ", basename(fdat), " are missing -- skipped")
        next
      }
      out[[mid]] <- retention_contrast(readRDS(ffit), readRDS(fdat), mid)
    }
  }
  .les_unlisted_fits(considered, "retention")

  res <- do.call(rbind, out)
  if (!is.null(res)) {
    utils::write.csv(res, paper1_results("_retention_contrasts.csv"), row.names = FALSE)
    message("[retention] wrote ", nrow(res), " contrasts")
  } else if (n_found == 0L) {
    message("[retention] no fitted models found yet")
  } else {
    message("[retention] ", n_found, " fitted model(s) found but every one was skipped; ",
            "_retention_contrasts.csv left as it was")
  }
  invisible(res)
}

# --- (6) Language modulation at a property's FIRST session ---------------------
#' Grammaticality x language contrast at each accuracy model's first session
#'
#' With session z-scored, the grammaticality x language coefficient is the source-language
#' advantage at the AVERAGE session and the three-way term is its growth. Whether the
#' advantage was already present when the property was first probed is the quantity that
#' separates transfer present from first exposure (as wholesale projection predicts) from an
#' advantage that only accrues with exposure -- and it is a linear combination of draws, not
#' a new model:
#'     advantage(first session) = b_gl + z_first * b_gsl ,
#' z_first being the z-score of the property's earliest measured session. The coefficients
#' are found by their components (.les_draw_term()), so a formula that orders them
#' differently cannot drop a row silently. Computed for every accuracy fit (the behavioural
#' advantage is where the adjudication rests).
#' @return A data frame with columns model, contrast ("gram_x_language_at_first_session"),
#'   median, ci_low, ci_high and pd, or NULL, invisibly. Writes
#'   results/_first_session_language_advantage.csv when there is at least one row.
first_session_advantage <- function() {
  out <- list()
  considered <- character(0)
  n_found <- 0L
  acc <- .les_acc_variants(first = c("", "_diversity"))
  for (p in names(LES_P1_PROPERTIES)) {
    for (v in seq_len(nrow(acc))) {
      mid  <- paste0("accuracy_", p, acc$tag[v])
      considered <- c(considered, mid)
      ffit <- paper1_results(paste0(mid, ".rds"))
      fdat <- paper1_derived(paste0("accuracy_", p, acc$dtag[v], ".rds"))
      if (!file.exists(ffit)) next
      n_found <- n_found + 1L
      if (!file.exists(fdat)) {
        message("[first-session] ", mid, ": its derived data ", basename(fdat),
                " are missing -- skipped")
        next
      }
      fit <- readRDS(ffit); dat <- readRDS(fdat)
      draws <- posterior::as_draws_df(fit)
      b_gl  <- .les_draw_term(draws, "z_recoded_grammaticality", "z_recoded_mini_language")
      b_gsl <- .les_draw_term(draws, "z_recoded_grammaticality", "z_recoded_session",
                              "z_recoded_mini_language")
      if (is.null(b_gl) || is.null(b_gsl)) {
        message("[first-session] ", mid, ": no unique grammaticality x language or ",
                "grammaticality x session x language term -- skipped")
        next
      }
      first_code <- min(dat$recoded_session, na.rm = TRUE)
      z_first <- .les_zval(dat, "recoded_session", "z_recoded_session", first_code)
      if (is.na(z_first)) {
        message("[first-session] ", mid, ": the first session's z code is not unique in ",
                "the data -- skipped")
        next
      }
      out[[mid]] <- cbind(model = mid, contrast = "gram_x_language_at_first_session",
                          .les_summarise_draws(b_gl + z_first * b_gsl))
    }
  }
  .les_unlisted_fits(considered, "first-session", family = "accuracy")
  res <- do.call(rbind, out)
  if (!is.null(res)) {
    utils::write.csv(res, paper1_results("_first_session_language_advantage.csv"),
                     row.names = FALSE)
    message("[first-session] wrote ", nrow(res), " row(s)")
  } else if (n_found == 0L) {
    message("[first-session] no fitted accuracy models found")
  } else {
    message("[first-session] ", n_found, " fitted accuracy model(s) found but every one was ",
            "skipped; _first_session_language_advantage.csv left as it was")
  }
  invisible(res)
}

# --- (5) Prior sensitivity: informative vs weakly-informative ----------------
#' Informative-versus-weak prior sensitivity for every comparable pair of fits
#'
#' The manuscript reports the largest informative-vs-weak shift among the grammaticality
#' terms, reading it from results/_prior_sensitivity.csv. That file used to be produced ad
#' hoc, with no pipeline step that wrote it, so it silently went stale whenever one prior
#' set was refitted and the other was not -- and a shift computed across two different
#' datasets measures the difference between the datasets, not between the priors. Building
#' it here ties it to the same run that pools everything else. A pair is written only when
#' each side has exactly one fit-time record and the two records agree on the number of
#' observations and of participants. That is a check on the sample's size, not on its
#' identity: two samples of equal size would pass it. Every pair is skipped, with a message,
#' when the pooled metadata are absent or predate the structure and retention_free columns.
#' @param meta The pooled fit metadata, as pool_artefacts() returns it. When omitted it is
#'   read from results/_pooled_fit_metadata.csv.
#' @return The comparison table (les_prior_sensitivity() columns plus model and structure),
#'   or NULL, invisibly. Writes results/_prior_sensitivity.csv; when no pair is comparable it
#'   deletes an existing copy instead, so the manuscript prints its pending marker rather
#'   than reading a stale file.
collect_prior_sensitivity <- function(meta) {
  if (missing(meta)) {
    meta_path <- paper1_results("_pooled_fit_metadata.csv")
    meta <- if (file.exists(meta_path)) utils::read.csv(meta_path, stringsAsFactors = FALSE) else NULL
  }
  meta_ok <- !is.null(meta) &&
    all(c("model", "structure", "retention_free", "prior_variant", "n_obs",
          "n_participants") %in% names(meta))

  # Each entry is (informative id, weak id), named by the informative id. The ERP cells
  # appear once per random-effect structure, because the manuscript reports a
  # prior-sensitivity figure for whichever structure is primary and the two must not be
  # pooled: they are different models, and a shift computed across them would confound
  # prior with structure exactly as the pre-exclusion comparison confounded prior with
  # sample. The same holds for the retention-free, reprocessed-excluded and
  # diversity-covariate variants, which are paired only with a weak-prior refit carrying
  # the same tags. The prior tag sits between the robustness tag and the structure tags
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
  # The _maxranef and _byitem accuracy variants have no weak-prior twin, so they enter no
  # pair; the manuscript's largest accuracy shift is read over the reported structure.
  # The base-structure retention-free pairs come last: no weak-prior retention-free fit
  # exists yet, and listing them keeps a future one from being left out silently.
  pairs <- c(
    erp_pairs(),                                             # base structure
    erp_pairs(item = "_itemslope"),                          # maximal structure
    erp_pairs(item = "_itemslope", ret = "_retfree"),        # maximal, retention-free
    erp_pairs(mis = "_exclreproc"),
    erp_pairs(mis = "_exclreproc", item = "_itemslope"),
    erp_pairs(mis = "_exclreproc", item = "_itemslope", ret = "_retfree"),
    acc_pairs(),
    acc_pairs("_diversity"),
    erp_pairs(ret = "_retfree"),                             # base, retention-free
    erp_pairs(mis = "_exclreproc", ret = "_retfree")
  )
  out <- list()
  warned_meta <- FALSE
  for (id in names(pairs)) {
    inf_id <- pairs[[id]][1]; weak_id <- pairs[[id]][2]
    inf_f  <- paper1_results(paste0(inf_id,  "_summary.rds"))
    weak_f <- paper1_results(paste0(weak_id, "_summary.rds"))
    if (!file.exists(inf_f) || !file.exists(weak_f)) next
    # Both fits of an ERP pair must be of the current specification; the same-data check
    # below cannot catch a superseded pair, because pooling has already left out its records.
    if (startsWith(inf_id, "erp_") &&
        !(.les_erp_tag_current(inf_id) && .les_erp_tag_current(weak_id))) {
      message("[sensitivity] ", id, ": a fit of the pair is of a superseded specification -- skipped")
      next
    }
    if (!meta_ok) {
      if (!warned_meta) {
        message("[sensitivity] the pooled fit metadata are ",
                if (is.null(meta)) "absent" else "missing the structure, retention_free or n_participants column",
                ", so no pair can be checked for same data -- every pair skipped")
        warned_meta <- TRUE
      }
      next
    }

    # Same-data check. The fit-time record carries the model id without the structure and
    # retention tags (03 records paste0(cell_id, les_p1_exclreproc_tag()); 04 records the
    # accuracy id with its data and structure tags), so the lookup is keyed on the bare id
    # together with the structure and the retention_free flag that pool_artefacts() derives
    # from the file name. Base and maximal fits, and reported and retention-free fits, share
    # a bare id and would otherwise match two records each.
    struct <- if (grepl("_itemslope(_retfree)?$", id)) "maximal" else "base"
    bare   <- sub("(_itemslope)?(_retfree)?$", "", id)
    same   <- meta$model == bare & meta$structure == struct &
              (meta$retention_free %in% grepl("_retfree$", id))
    rec_inf  <- meta[same & meta$prior_variant == "informative", , drop = FALSE]
    rec_weak <- meta[same & meta$prior_variant == "weak", , drop = FALSE]
    if (nrow(rec_inf) != 1L || nrow(rec_weak) != 1L) {
      message("[sensitivity] ", id, ": ", nrow(rec_inf), " informative and ", nrow(rec_weak),
              " weak-prior fit record(s), where one each is needed to confirm the two fits ",
              "share their data -- skipped")
      next
    }
    if (!identical(rec_inf$n_obs, rec_weak$n_obs) ||
        !identical(rec_inf$n_participants, rec_weak$n_participants)) {
      message("[sensitivity] ", id, ": informative n=", rec_inf$n_obs, " (", rec_inf$n_participants,
              " participants) but weak n=", rec_weak$n_obs, " (", rec_weak$n_participants,
              ") -- fitted to different data, skipped")
      next
    }
    s <- tryCatch(les_prior_sensitivity(paper1_results(), inf_id, weak_id = weak_id),
                  error = function(e) {
                    message("[sensitivity] ", id, ": ", conditionMessage(e), " -- skipped")
                    NULL
                  })
    if (is.null(s)) next
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

# --- (7) Signal-detection contrasts from the accuracy models -------------------
#' Sensitivity and criterion contrasts from every fitted accuracy model
#'
#' The accuracy models regress `correct` on grammaticality, session and language. That is
#' a logistic signal-detection model in disguise (DeCarlo, 1998,
#' https://doi.org/10.1037/1082-989X.3.2.186; see the header of 04_fit_brms_accuracy.R).
#' With eta(g, s, l) the linear predictor, the rates of answering "grammatical" are
#'   logit(H)  =  eta(z_grammatical,   s, l)
#'   logit(FA) = -eta(z_ungrammatical, s, l)
#' so, evaluated at the exact z values each property's data carry,
#'   sensitivity  d_L = logit(H) - logit(FA) = eta(zG) + eta(zU)
#'   criterion    c_L = -(logit(H) + logit(FA)) / 2 = -(eta(zG) - eta(zU)) / 2
#' d_L is on the logit scale, about 1.7 times probit d' (DeCarlo, 1998). A negative c_L
#' is a liberal criterion, a readiness to answer "grammatical", matching the sign of the
#' descriptive criterion written by 02_extract_accuracy.R. Covariates other than the three
#' design factors, and every random effect (participant and, in the _byitem fits, item), are
#' held at zero, so the quantities are those of an average participant and item.
#'
#' For each fitted accuracy model and each measure the function writes: the value per
#' language and session; the Mini-Norwegian minus Mini-English difference per session and
#' at the average session; each group's change from the first to the last session of the
#' property and from Session 4 to Session 6; and the between-language difference in those
#' changes.
#' @return The contrasts as a data frame, or NULL, invisibly. Writes
#'   results/_accuracy_sdt_contrasts.csv when there is at least one row.
accuracy_sdt_contrasts <- function() {
  out <- list()
  considered <- character(0)
  acc <- .les_acc_variants(first = c("", "_diversity", "_maxranef", "_weakprior"))
  for (p in names(LES_P1_PROPERTIES)) {
    for (v in seq_len(nrow(acc))) {
      mid  <- paste0("accuracy_", p, acc$tag[v])
      considered <- c(considered, mid)
      ffit <- paper1_results(paste0(mid, ".rds"))
      fdat <- paper1_derived(paste0("accuracy_", p, acc$dtag[v], ".rds"))
      if (!file.exists(ffit) || !file.exists(fdat)) next
      dat   <- readRDS(fdat)
      draws <- posterior::as_draws_df(readRDS(ffit))
      g <- "z_recoded_grammaticality"; s <- "z_recoded_session"; l <- "z_recoded_mini_language"
      term <- function(...) {
        parts <- c(...)
        v <- if (!length(parts)) draws[["b_Intercept"]] else .les_draw_term(draws, parts)
        if (is.null(v)) 0 else v
      }
      b <- list(i = term(), g = term(g), s = term(s), l = term(l),
                gs = term(g, s), gl = term(g, l), sl = term(s, l), gsl = term(g, s, l))
      eta <- function(zc, zs, zl) {
        b$i + b$g * zc + b$s * zs + b$l * zl + b$gs * zc * zs + b$gl * zc * zl +
          b$sl * zs * zl + b$gsl * zc * zs * zl
      }
      zG <- .les_zval(dat, "recoded_grammaticality", g, 0.5)
      zU <- .les_zval(dat, "recoded_grammaticality", g, -0.5)
      zL <- c("Mini-Norwegian" = .les_zval(dat, "recoded_mini_language", l, 0.5),
              "Mini-English"   = .les_zval(dat, "recoded_mini_language", l, -0.5))
      codes <- sort(unique(dat$recoded_session))
      zS <- stats::setNames(vapply(codes, function(k)
        .les_zval(dat, "recoded_session", s, k), numeric(1)),
        as.character(LES_ERP_SESSIONS[codes + 1]))
      zS <- c(zS, average = 0)
      if (anyNA(c(zG, zU, zL, zS))) {
        message("[sdt] ", mid, ": design codes not recoverable from the data -- skipped")
        next
      }
      measure_fn <- list(
        sensitivity = function(zs, zl) eta(zG, zs, zl) + eta(zU, zs, zl),
        criterion   = function(zs, zl) -(eta(zG, zs, zl) - eta(zU, zs, zl)) / 2
      )
      rows <- list()
      # The Monte Carlo standard error of each interval bound, so the manuscript can tell a
      # bound that clears zero from one within sampling error of it (reruns under adaptive
      # reduce_sum differ at that level; _shared/R/01_bayesian_settings.R). It needs each
      # chain's autocorrelation, so the draws are laid out with the chains as columns, which
      # as_draws_df's chain-major order allows.
      stopifnot(!is.unsorted(draws$.chain))
      n_chains <- posterior::nchains(draws)
      add <- function(measure, contrast, lang, session, x) {
        xm <- matrix(x, ncol = n_chains)
        rows[[length(rows) + 1]] <<- cbind(
          model = mid, measure = measure, contrast = contrast,
          mini_language = lang, session = session, .les_summarise_draws(x),
          mcse_low  = unname(posterior::mcse_quantile(xm, probs = 0.025)),
          mcse_high = unname(posterior::mcse_quantile(xm, probs = 0.975)))
      }
      first <- names(zS)[1]; last <- names(zS)[length(zS) - 1]
      for (m in names(measure_fn)) {
        f <- measure_fn[[m]]
        for (ss in names(zS)) {
          for (lang in names(zL)) add(m, "value", lang, ss, f(zS[[ss]], zL[[lang]]))
          add(m, "language_difference", "Mini-Norwegian - Mini-English", ss,
              f(zS[[ss]], zL[["Mini-Norwegian"]]) - f(zS[[ss]], zL[["Mini-English"]]))
        }
        spans <- list(first_to_last = c(first, last))
        if (all(c("4", "6") %in% names(zS)) && !identical(c(first, last), c("4", "6"))) {
          spans$s4_to_s6 <- c("4", "6")
        }
        for (sp in names(spans)) {
          a <- spans[[sp]][1]; z <- spans[[sp]][2]
          ch <- lapply(zL, function(zl) f(zS[[z]], zl) - f(zS[[a]], zl))
          for (lang in names(zL)) add(m, paste0("change_", sp), lang, paste(a, z, sep = "->"), ch[[lang]])
          add(m, paste0("change_", sp, "_language_difference"), "Mini-Norwegian - Mini-English",
              paste(a, z, sep = "->"), ch[["Mini-Norwegian"]] - ch[["Mini-English"]])
        }
      }
      out[[mid]] <- do.call(rbind, rows)
    }
  }
  .les_unlisted_fits(considered, "sdt", family = "accuracy")
  res <- if (length(out)) do.call(rbind, out) else NULL
  f <- paper1_results("_accuracy_sdt_contrasts.csv")
  if (!is.null(res)) {
    utils::write.csv(res, f, row.names = FALSE)
    message("[sdt] wrote ", nrow(res), " rows for ", length(out), " accuracy models")
  } else {
    message("[sdt] no fitted accuracy models found")
  }
  invisible(res)
}

# =============================================================================
#' Entry point
#'
#' Stops, writing nothing, when results/ holds no *_summary.rds or *_convergence.rds: step 5
#' runs where the fits are, and run anywhere else it would otherwise delete the tracked
#' _prior_sensitivity.csv while leaving the other pooled tables as they were.
#' @return NULL, invisibly; see the functions above for the files written.
.run <- function() {
  if (!length(list.files(paper1_results(), pattern = "_(summary|convergence)\\.rds$"))) {
    stop("No fitted artefacts (*_summary.rds, *_convergence.rds) under ", paper1_results(),
         "; step 5 runs where the fits are (see HPC_RUNBOOK.md), so nothing was written.",
         call. = FALSE)
  }
  meta <- pool_artefacts()
  collect_retention()
  first_session_advantage()
  collect_prior_sensitivity(meta)
  accuracy_sdt_contrasts()
  message("[summaries] done.")
  invisible(NULL)
}

if (sys.nframe() == 0L) .run()
