# Tally ISSUES.md audit entries by status class, for the counts its header and the
# trackers quote. Opt-in, run by hand; not called by any pipeline stage.
# Usage, from the project root:
#   Rscript --vanilla _shared/R/tally_issues.R ISSUES.md [out.csv]
args <- commandArgs(trailingOnly = TRUE)
x <- readLines(args[1], warn = FALSE, encoding = "UTF-8")

# Entries live between "## BLOCKING (20)" and "## Carried over".
start <- grep("^## BLOCKING \\(", x)[1]
stop_ <- grep("^## Carried over", x)[1]
h <- grep("^### [A-Z0-9]+-[0-9]+\\. ", x)
h <- h[h > start & h < stop_]
ends <- c(h[-1] - 1, stop_ - 1)

rows <- lapply(seq_along(h), function(i) {
  blk <- x[h[i]:ends[i]]
  id  <- sub("^### ([A-Z0-9]+-[0-9]+)\\..*$", "\\1", x[h[i]])
  sev <- grep("^- \\*\\*Severity:\\*\\*", blk, value = TRUE)
  st  <- grep("^- \\*\\*Status:\\*\\*", blk, value = TRUE)
  data.frame(id = id,
             severity = if (length(sev)) sub("^- \\*\\*Severity:\\*\\* *", "", sev[1]) else NA,
             n_status = length(st),
             status = if (length(st)) sub("^- \\*\\*Status:\\*\\* *", "", st[1]) else NA,
             stringsAsFactors = FALSE)
})
d <- do.call(rbind, rows)

cls <- function(s) {
  s <- tolower(trimws(s))
  if (is.na(s)) return("MISSING")
  if (grepl("^resolved in part", s)) return("partly")
  if (grepl("^partly resolved", s)) return("partly")
  if (grepl("^resolved", s)) return("resolved")
  if (grepl("^obsolete", s)) return("resolved")
  if (grepl("^no change needed", s)) return("resolved")
  if (grepl("^moot", s)) return("resolved")
  if (grepl("^author decision", s)) return("author_decision")
  if (grepl("^open", s)) return("open")
  if (grepl("^deferred", s)) return("deferred")
  if (grepl("^proposed: do not apply", s)) return("declined")
  paste0("UNCLASSIFIED: ", substr(s, 1, 40))
}
d$class <- vapply(d$status, cls, character(1))
d$blocking <- grepl("^BLOCKING", d$severity)
d$det <- grepl("^DET-", d$id)

cat("entries parsed:", nrow(d), " (DET:", sum(d$det), ")\n")
cat("entries with != 1 status line:", paste(d$id[d$n_status != 1], collapse = ", "), "\n")
e <- d[!d$det, ]
cat("audit entries (excl. DET):", nrow(e), "\n")
print(table(e$class))
cat("\nBLOCKING:", sum(e$blocking), "\n")
print(table(e$class[e$blocking]))
cat("\nBLOCKING not resolved:", paste(e$id[e$blocking & e$class != "resolved"], collapse = ", "), "\n")
for (k in c("author_decision", "open", "deferred", "declined")) {
  cat(k, ":", paste(e$id[e$class == k], collapse = ", "), "\n")
}
cat("partly:", paste(e$id[e$class == "partly"], collapse = ", "), "\n")
cat("non-standard resolved wording:",
    paste(e$id[e$class == "resolved" & !grepl("^resolved", tolower(e$status))], collapse = ", "), "\n")
cat("DET statuses:\n"); print(d[d$det, c("id", "class")])
if (length(args) > 1) utils::write.csv(d, args[2], row.names = FALSE)
