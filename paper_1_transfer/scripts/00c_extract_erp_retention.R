# =============================================================================
# paper_1_transfer/scripts/00c_extract_erp_retention.R
#
# PURPOSE
# -------
# Reproducibly derive the ERP single-trial *retention* descriptives that the
# Method section of paper_1_morphosyntax.qmd currently states as a hard-coded
# sentence ("on average 31.6 of the 48 presented trials per cell were retained,
# SD = 5.8"). This script writes a machine-readable table so the manuscript can
# inject the numbers instead of hard-coding them.
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
#                           modelled  (pooled mean ~= 31.44, SD ~= 5.80).
#   * scope == "overall":   ALL grammaticality categories pooled, which is the
#                           value the manuscript currently prints (~= 31.6 / 5.8).
# Reporting both makes the provenance of whichever number the manuscript uses
# explicit and auditable.
#
# OUTPUT
# ------
# paper_1_transfer/results/_erp_trial_retention.csv
#   Per-condition rows (scope == "per_condition_canonical") plus two pooled
#   summary rows (scope == "canonical" and scope == "overall"). Columns:
#     scope, grammatical_property, session, mini_language, grammaticality,
#     mean_retained, sd_retained, n_cells, presented_per_cell, pct_discarded
#
# This script is idempotent: re-running it fully regenerates the CSV.
# =============================================================================

suppressWarnings(suppressMessages({
  library(dplyr)
  library(readr)
}))

# --- Shared infrastructure (paths, manifest, read-only guard) ----------------
if (!exists("data_path"))            source(here::here("_shared", "R", "00_paths.R"))
if (!exists("LES_PROPERTY_CODES"))   source(here::here("_shared", "R", "03_data_manifest.R"))

# --- Design constants --------------------------------------------------------
PRESENTED_PER_CELL <- 48L   # trials presented per condition cell (see header)

# The modelled grammaticality contrast (canonical Grammatical vs Ungrammatical).
CANONICAL_GRAMMATICALITY <- c("Grammatical", "Ungrammatical")

# Map the human-readable property labels used in the legacy CSV onto the canonical
# snake_case property names of the data manifest, names(LES_PROPERTY_CODES), so that
# downstream code and the manuscript share one vocabulary. The CSV's labels are not
# themselves in the manifest, so this map is maintained here and must be kept in step
# if the manifest renames a property. The stopifnot() below only checks that every
# label was mapped, so it would not catch such a rename.
PROPERTY_LABEL_TO_KEY <- c(
  "Gender agreement"             = "gender_agreement",
  "Differential object marking"  = "differential_object_marking",
  "Verb-object number agreement" = "verb_object_number_agreement"
)

# --- Locate and read the source table ----------------------------------------
src_csv <- data_path("EEG_trial_count_per_condition.csv")
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
  all(trials$session %in% c(2L, 3L, 4L, 6L))   # ERP sessions
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

# --- Validate the headline numbers -------------------------------------------
canon_mean <- canonical_pooled$mean_retained
canon_sd   <- canonical_pooled$sd_retained
stopifnot(
  abs(canon_mean - 31.4) < 0.5,   # canonical pooled mean ~= 31.4
  abs(canon_sd   - 5.8)  < 0.5,   # canonical pooled SD  ~= 5.8
  canonical_pooled$presented_per_cell == 48
)

# --- Report ------------------------------------------------------------------
cat("\n===== ERP trial retention =====\n")
cat(sprintf("CANONICAL pooled (Grammatical+Ungrammatical): mean = %.3f, SD = %.3f, cells = %d, %% discarded = %.2f\n",
            canon_mean, canon_sd, canonical_pooled$n_cells, canonical_pooled$pct_discarded))
cat(sprintf("OVERALL   pooled (all categories):            mean = %.3f, SD = %.3f, cells = %d, %% discarded = %.2f\n",
            overall_pooled$mean_retained, overall_pooled$sd_retained,
            overall_pooled$n_cells, overall_pooled$pct_discarded))
cat("\nhead of output table:\n")
print(utils::head(out, 8))
cat("\npooled/canonical summary rows:\n")
print(out %>% filter(scope %in% c("overall", "canonical")) %>% as.data.frame())
cat("\n[00c] done.\n")
