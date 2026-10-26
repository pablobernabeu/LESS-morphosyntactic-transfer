# =============================================================================
# _shared/R/write_data_manifest.R  --  Content identity of the read-only data tree
# =============================================================================
#
# WHAT IT DOES
# The analyses read data/ (on the cluster, $LES_DATA_ROOT), which is copied to the
# cluster outside git and edited by nobody but the author. Nothing else records which
# version of the inputs a result came from, so a re-exported file, a hand edit or an
# incomplete copy would pass unnoticed (ISSUES.md X5-02). This script gives the tree a
# content identity in two halves:
#
#   les_write_data_manifest()   run on a git checkout (the rendering box). Lists every
#                               tracked file under data/ with the git blob id of its
#                               committed content, headed by the data tree id
#                               (git rev-parse HEAD:data) and the commit. The sparse,
#                               blob-less clone is enough: the listing reads only the
#                               tree objects. (git ls-tree -l and git ls-files --eol would
#                               need every blob, and in that clone fetch all 11 GB.)
#   les_verify_data_manifest()  run where the data are (the cluster). Hashes each listed
#                               file under data_path() the way git hashes it and reports
#                               every file that is missing or whose content differs.
#
# The blob id is git's SHA-1 of "blob <size>\0" followed by the committed bytes. Git
# stores a file it treats as text (.gitattributes: text=auto) with LF line endings, while a
# copy made outside git, such as the cluster's, may carry CRLF. The verifier therefore
# accepts a file whose bytes hash to the blob id as they stand or after each CRLF is
# turned into LF. A file that differs from the commit in any other way, a lone carriage
# return included, fails.
#
# WHEN TO RUN IT
# Opt-in and called by no pipeline stage. Write the manifest after every commit that
# changes data/, from the project root:
#     Rscript _shared/R/write_data_manifest.R write <manifest path>
# and verify a data copy, for example from a cluster job after each data sync:
#     Rscript _shared/R/write_data_manifest.R verify <manifest path>
# which exits with status 1 when any file is missing or differs. Hashing the whole tree
# reads every byte of it, so run the verification as a job, not on a login node. The
# result names the data tree id, which is what a reported result can cite as its input
# version.
#
# Needs here, digest (pinned in renv.lock) and, for writing, git on the PATH.
# =============================================================================

if (!exists("data_path")) source(here::here("_shared", "R", "00_paths.R"))

# Git's blob id of the bytes `b` (a raw vector).
.les_git_blob_id <- function(b) {
  digest::digest(c(charToRaw(paste0("blob ", length(b))), as.raw(0L), b),
                 algo = "sha1", serialize = FALSE)
}

# -----------------------------------------------------------------------------
# les_write_data_manifest()  --  list the committed data files and their blob ids
# -----------------------------------------------------------------------------
# `out` is the path of the tab-separated manifest to write. Runs git in the project root
# (.les_root) and stops when git fails. The file starts with two comment lines giving the
# commit and the data tree id, then a header row and one row per tracked file under
# data/: path (relative to data/) and blob (git blob id). Returns the table invisibly.
les_write_data_manifest <- function(out) {
  git <- function(args) {
    # system2() on Windows splits an argument at a space unless it is quoted.
    a <- c("-C", .les_root, "-c", "core.quotePath=false", args)
    a <- ifelse(grepl("[[:space:]]", a), shQuote(a), a)
    r <- suppressWarnings(system2("git", a, stdout = TRUE, stderr = FALSE))
    if (!is.null(attr(r, "status")) && attr(r, "status") != 0L) {
      stop("[data-manifest] git ", paste(args, collapse = " "), " failed", call. = FALSE)
    }
    r
  }
  commit <- git(c("rev-parse", "HEAD"))
  tree   <- git(c("rev-parse", "HEAD:data"))
  # "<mode> <type> <object>\t<path>"
  ls  <- git(c("ls-tree", "-r", "HEAD", "--", "data/"))
  ls  <- ls[grepl("^[0-9]+ blob ", ls)]
  tab <- data.frame(path = sub("^data/", "", sub("^[^\t]*\t", "", ls)),
                    blob = sub("^[0-9]+ blob ([0-9a-f]+)\t.*$", "\\1", ls),
                    stringsAsFactors = FALSE)
  tab <- tab[order(tab$path, method = "radix"), , drop = FALSE]
  con <- file(out, open = "wb")
  on.exit(close(con), add = TRUE)
  writeLines(c(paste0("# commit ", commit), paste0("# data_tree ", tree),
               paste(names(tab), collapse = "\t"),
               do.call(paste, c(tab, sep = "\t"))), con, sep = "\n", useBytes = TRUE)
  message(sprintf("[data-manifest] %d files, data tree %s (commit %s) -> %s",
                  nrow(tab), tree, substr(commit, 1, 7), out))
  invisible(tab)
}

# -----------------------------------------------------------------------------
# les_verify_data_manifest()  --  check a data copy against the manifest
# -----------------------------------------------------------------------------
# `manifest` is a file written by les_write_data_manifest(); `root` the folder holding the
# data (data_path() by default, so $LES_DATA_ROOT on the cluster). Reads every listed file
# in full. Returns, invisibly, a data frame with one row per listed file and columns path,
# status ("ok", "missing" or "differs"), expected and found (blob ids), with the data tree
# id as attribute "data_tree". Messages a summary; writes nothing. Files under `root` that
# the manifest does not list are not hashed, only counted in the summary.
les_verify_data_manifest <- function(manifest, root = data_path()) {
  head <- readLines(manifest, n = 2L, warn = FALSE)
  tree <- sub("^# data_tree ", "", grep("^# data_tree ", head, value = TRUE))
  tab <- utils::read.delim(manifest, comment.char = "#", colClasses = "character",
                           quote = "", na.strings = character(0))
  found <- vapply(seq_len(nrow(tab)), function(i) {
    f <- file.path(root, tab$path[i])
    if (!file.exists(f)) return(NA_character_)
    b <- readBin(f, "raw", n = file.info(f)$size)
    id <- .les_git_blob_id(b)
    if (id == tab$blob[i]) return(id)
    # A text file copied outside git may carry CRLF where the commit holds LF.
    cr <- which(b == as.raw(13L))
    crlf <- cr[cr < length(b) & b[pmin(cr + 1L, length(b))] == as.raw(10L)]
    if (length(crlf)) .les_git_blob_id(b[-crlf]) else id
  }, character(1))
  res <- data.frame(path = tab$path,
                    status = ifelse(is.na(found), "missing",
                                    ifelse(found == tab$blob, "ok", "differs")),
                    expected = tab$blob, found = found, stringsAsFactors = FALSE)
  attr(res, "data_tree") <- tree
  on_disk <- list.files(root, recursive = TRUE, all.files = FALSE)
  message(sprintf(paste0("[data-manifest] data tree %s: %d ok, %d missing, %d differ, ",
                         "of %d listed; %d file(s) under %s not listed"),
                  tree, sum(res$status == "ok"), sum(res$status == "missing"),
                  sum(res$status == "differs"), nrow(res),
                  length(setdiff(on_disk, tab$path)), root))
  invisible(res)
}

if (sys.nframe() == 0L) {
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) != 2L || !args[1] %in% c("write", "verify")) {
    stop("Usage: Rscript _shared/R/write_data_manifest.R write|verify <manifest path>",
         call. = FALSE)
  }
  if (args[1] == "write") {
    les_write_data_manifest(args[2])
  } else {
    res <- les_verify_data_manifest(args[2])
    bad <- res[res$status != "ok", , drop = FALSE]
    if (nrow(bad)) {
      message(paste0("  ", bad$status, ": ", bad$path, collapse = "\n"))
      quit(status = 1L)
    }
  }
}
