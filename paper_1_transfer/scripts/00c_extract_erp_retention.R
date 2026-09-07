# =============================================================================
# paper_1_transfer/scripts/00c_extract_erp_retention.R
#
# PURPOSE
# -------
# Derive the ERP single-trial *retention* descriptives that the Method section of
# paper_1_morphosyntax.qmd injects through erp_ret(): the mean and SD of trials retained
# per condition cell after artefact rejection, against the 48 presented. This script is
# the source of those numbers. It writes both the canonical and the overall scope (see
# below), so the choice the manuscript makes is auditable in the artefact.
#
# SOURCE
# ------
# This script does not touch the single-trial EEG itself. The trial-by-trial exports
# under 'data/raw data/EEG' are large and slow to load, and the legacy descriptives
# script 'data/EEG data descriptives.R' has already reduced them to a per-cell
# trial-count table, 'data/EEG_trial_count_per_condition.csv', which is the source
# here. Its columns are:
#     mini_language, participant_lab_ID, session, grammatical_property,
#     grammaticality, n_trials
# One row = one (participant x session x property x grammaticality) cell; n_trials
# is the number of EEG trials RETAINED for that cell after artefact rejection.
# The experiment presented 48 trials per cell (this constant is documented in the
# legacy script, which computes "% discarded" as 100*(1 - mean(n_trials)/48)).
#
# WHAT "CANONICAL" vs "OVERALL" MEANS
# -----------------------------------
# Paper 1 models the canonical Grammatical vs Ungrammatical contrast only (see
# _config.R: LES_P1_GRAMMATICALITY_REGEX = "S10[12]"; the ancillary S103 violation
# conditions -- here "Number agreement violation" and "Article location violation"
# -- are excluded). We therefore report TWO pooled summaries and tag them in a
# 'scope' column:
#   * scope == "canonical": the Grammatical + Ungrammatical cells that are actually
#                           modelled; the row erp_ret() reads.
#   * scope == "overall":   ALL grammaticality categories pooled, the figure the
#                           legacy descriptives script reported.
# Reporting both makes the provenance of whichever number the manuscript uses
# explicit and auditable. The expected headline values are not asserted here, where a
# regenerated table would fail the script before anyone saw its numbers; they are pinned
# in tests/test_erp_retention_artefact.R, which reads the written table.
#
# OUTPUT
# ------
# paper_1_transfer/results/_erp_trial_retention.csv
#   Per-condition rows (scope == "per_condition_canonical") plus two pooled
#   summary rows (scope == "canonical" and scope == "overall"). Columns:
#     scope, grammatical_property, session, mini_language, grammaticality,
#     mean_retained, sd_retained, n_cells, presented_per_cell, pct_discarded
# paper_1_transfer/results/_misfiltered_share.csv
#   One row per property recorded at the session of the mis-filtered datasets
#   (_config.R, LES_P1_MISFILTERED): the retained trials those datasets contribute,
#   the retained trials of every dataset at that session, and their ratio as a
#   percentage. The Method quotes that share, so it is computed here from the same
#   retained-trial table and not typed.
#
# This script is idempotent: re-running it fully regenerates both CSVs.
# =============================================================================

suppressWarnings(suppressMessages({
  library(dplyr)
  library(readr)
}))

# --- Shared infrastructure (paths, manifest, read-only guard, exclusion list) --
if (!exists("data_path"))            source(here::here("_shared", "R", "00_paths.R"))
if (!exists("LES_PROPERTY_CODES"))   source(here::here("_shared", "R", "03_data_manifest.R"))
if (!exists("LES_P1_MISFILTERED"))   source(here::here("paper_1_transfer", "scripts", "_config.R"))

# --- Design constants --------------------------------------------------------
PRESENTED_PER_CELL <- 48L   # trials presented per condition cell (see header)

# The modelled grammaticality contrast (canonical Grammatical vs Ungrammatical).
CANONICAL_GRAMMATICALITY <- c("Grammatical", "Ungrammatical")

# Map the human-readable property labels used in the legacy CSV onto the canonical
# snake_case property names of the data manifest, names(LES_PROPERTY_CODES), so that
# downstream code and the manuscript share one vocabulary. The legacy CSV labels each
# property in the same words as the manuscript's figures, so the map is derived from
# the manifest's display labels (LES_PROPERTY_LABELS, keyed by property in design order)
# and the two cannot drift apart. Should the CSV ever carry a different spelling, the
# recode leaves it unmapped and the stopifnot() below stops here.
stopifnot(setequal(names(LES_PROPERTY_LABELS), names(LES_PROPERTY_CODES)))
PROPERTY_LABEL_TO_KEY <- stats::setNames(names(LES_PROPERTY_LABELS),
                                         unname(LES_PROPERTY_LABELS))

# --- Locate and read the source table ----------------------------------------
src_csv <- erp_trial_count_csv()
if (!file.exists(src_csv)) {
  stop("Source trial-count table not found: ", src_csv,
       "\nRun the legacy 'data/EEG data descriptives.R' first to generate it.")
}
message("[00c] reading source: ", src_csv)

trials <- read_csv(src_csv, show_col_types = FALSE) %>%
  mutate(
    grammatical_property = recode(grammatical_property, !!!PROPERTY_LABEL_TO_KEY),
    session              = as.integer(session)
  )

# --- Validate the source ------------------------------------------------------
expected_props <- unname(PROPERTY_LABEL_TO_KEY)
stopifnot(
  all(c("mini_language", "session", "grammatical_property",
        "grammaticality", "n_trials") %in% names(trials)),
  all(trials$grammatical_property %in% expected_props),
  all(trials$session %in% LES_ERP_SESSIONS)
)

# --- Per-condition table (canonical cells only) ------------------------------
# One summary row per (property x session x mini_language x grammaticality) over
# the modelled Grammatical/Ungrammatical cells.
per_condition <- trials %>%
  filter(grammaticality %in% CANONICAL_GRAMMATICALITY) %>%
  group_by(grammatical_property, session, mini_language, grammaticality) %>%
  summarise(
    mean_retained = mean(n_trials),
    sd_retained   = sd(n_trials),
    n_cells       = n(),
    .groups       = "drop"
  ) %>%
  mutate(
    scope              = "per_condition_canonical",
    presented_per_cell = PRESENTED_PER_CELL,
    pct_discarded      = 100 * (PRESENTED_PER_CELL - mean_retained) / PRESENTED_PER_CELL
  )

# --- Pooled summary rows ------------------------------------------------------
# A pooled row treats every retained cell equally (each cell = one observation),
# matching how the legacy script computed the headline mean/SD.
pooled_row <- function(df, scope_label) {
  tibble(
    scope                = scope_label,
    grammatical_property = "ALL",
    session              = NA_integer_,
    mini_language        = "ALL",
    grammaticality       = if (scope_label == "canonical") "Grammatical+Ungrammatical" else "ALL",
    mean_retained        = mean(df$n_trials),
    sd_retained          = sd(df$n_trials),
    n_cells              = nrow(df),
    presented_per_cell   = PRESENTED_PER_CELL,
    pct_discarded        = 100 * (PRESENTED_PER_CELL - mean(df$n_trials)) / PRESENTED_PER_CELL
  )
}

canonical_pooled <- pooled_row(
  trials %>% filter(grammaticality %in% CANONICAL_GRAMMATICALITY),
  "canonical"
)
overall_pooled <- pooled_row(trials, "overall")

# --- Assemble and write -------------------------------------------------------
out <- bind_rows(
  overall_pooled,
  canonical_pooled,
  per_condition %>%
    select(scope, grammatical_property, session, mini_language, grammaticality,
           mean_retained, sd_retained, n_cells, presented_per_cell, pct_discarded)
) %>%
  mutate(
    mean_retained = round(mean_retained, 3),
    sd_retained   = round(sd_retained, 3),
    pct_discarded = round(pct_discarded, 3)
  )

out_csv <- paper1_results("_erp_trial_retention.csv")
les_assert_readonly_data(out_csv)   # never write inside read-only data/
write_csv(out, out_csv)
message("[00c] wrote: ", out_csv, "  (", nrow(out), " rows)")

# --- Share of the session's observations held by the mis-filtered datasets ----
# The source table covers the full sample, the four mis-filtered datasets included, so
# their share of the retained canonical trials at their session is a direct ratio. One
# row per property recorded at that session; a property not yet introduced then has no
# row, which is the correct statement about it.
mis_key <- paste(LES_P1_MISFILTERED$participant_lab_ID, LES_P1_MISFILTERED$session)
mis_share <- trials %>%
  filter(grammaticality %in% CANONICAL_GRAMMATICALITY,
         session %in% unique(LES_P1_MISFILTERED$session)) %>%
  mutate(misfiltered = paste(participant_lab_ID, session) %in% mis_key) %>%
  group_by(grammatical_property, session) %>%
  summarise(
    n_datasets_misfiltered = n_distinct(participant_lab_ID[misfiltered]),
    n_datasets_all         = n_distinct(participant_lab_ID),
    n_trials_misfiltered   = sum(n_trials[misfiltered]),
    n_trials_all           = sum(n_trials),
    .groups = "drop"
  ) %>%
  mutate(share_pct = round(100 * n_trials_misfiltered / n_trials_all, 3))

share_csv <- paper1_results("_misfiltered_share.csv")
les_assert_readonly_data(share_csv)
write_csv(mis_share, share_csv)
message("[00c] wrote: ", share_csv, "  (", nrow(mis_share), " rows)")

# --- Validate the structure of the written table -------------------------------
# Structural checks only: both pooled rows are present, the presented count is the
# design constant, and each pooled mean lies within the presented range. The headline
# values themselves are asserted by tests/test_erp_retention_artefact.R against the
# written artefact, so a regenerated table with different numbers is reported, not
# refused.
canon_mean <- canonical_pooled$mean_retained
canon_sd   <- canonical_pooled$sd_retained
pooled     <- out[out$scope %in% c("overall", "canonical"), , drop = FALSE]
stopifnot(
  setequal(pooled$scope, c("overall", "canonical")),
  all(pooled$presented_per_cell == PRESENTED_PER_CELL),
  all(pooled$mean_retained > 0 & pooled$mean_retained <= PRESENTED_PER_CELL)
)

# --- Report ------------------------------------------------------------------
cat("\n===== ERP trial retention =====\n")
cat(sprintf(paste0("CANONICAL pooled (Grammatical+Ungrammatical): mean = %.3f, SD = %.3f, ",
                   "cells = %d, %% discarded = %.2f\n"),
            canon_mean, canon_sd, canonical_pooled$n_cells, canonical_pooled$pct_discarded))
cat(sprintf(paste0("OVERALL   pooled (all categories):            mean = %.3f, SD = %.3f, ",
                   "cells = %d, %% discarded = %.2f\n"),
            overall_pooled$mean_retained, overall_pooled$sd_retained,
            overall_pooled$n_cells, overall_pooled$pct_discarded))
cat("\nhead of output table:\n")
print(utils::head(out, 8))
cat("\npooled/canonical summary rows:\n")
print(out %>% filter(scope %in% c("overall", "canonical")) %>% as.data.frame())
cat("\nmis-filtered share of the session's retained canonical trials:\n")
print(as.data.frame(mis_share))
cat("\n[00c] done.\n")
