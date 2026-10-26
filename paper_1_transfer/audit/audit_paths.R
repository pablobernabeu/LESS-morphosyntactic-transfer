# Where the R stages of the EEG export audit read and write: the R counterpart of
# audit_paths.py, with the same environment variables and defaults. The data tree is
# LES_DATA_ROOT, else <code root>/data; intermediate outputs go to
# <LES_STORE or code root>/paper_1_transfer/data_derived/eeg_audit/<stage>/, which is not under
# version control, unless LES_AUDIT_OUT names another root. The code root is found with `here`,
# as _shared/R/00_paths.R finds it, but without that file's setwd(), so a stage's working
# directory stays where the stage puts it.
if (!requireNamespace("here", quietly = TRUE)) {
  stop("Package 'here' is not installed. Restore the pinned environment first (renv::restore()).",
       call. = FALSE)
}
AUDIT_CODE_ROOT <- here::here()

audit_data_root <- function() {
  env <- Sys.getenv("LES_DATA_ROOT")
  if (nzchar(env)) env else file.path(AUDIT_CODE_ROOT, "data")
}

audit_root <- function() {
  env <- Sys.getenv("LES_AUDIT_OUT")
  if (nzchar(env)) return(env)
  store <- Sys.getenv("LES_STORE")
  file.path(if (nzchar(store)) store else AUDIT_CODE_ROOT, "paper_1_transfer", "data_derived", "eeg_audit")
}

# Folder of one audit stage, created on demand.
audit_dir <- function(stage) {
  d <- file.path(audit_root(), stage)
  dir.create(d, recursive = TRUE, showWarnings = FALSE)
  normalizePath(d, winslash = "/")
}
