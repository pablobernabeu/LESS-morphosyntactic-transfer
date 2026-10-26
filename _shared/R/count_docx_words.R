# Body word count of an apaquarto .docx, re-implementing the method recorded in
# paper_2_plasticity/journal_requirements.json (measured_2026_09_10): parse the document
# XML properly, take the paragraphs from the Introduction's first paragraph to the first
# appendix heading, and treat a paragraph as table content only when it has a w:tbl
# ancestor. Counting tag nesting in a token stream (the withdrawn 6 Sep method) is what
# misattributed half the body to tables, hence the ancestor test via XPath.
#
# Words are whitespace-delimited tokens, which is what Word's counter does. Variants are
# reported (math text included or not, non-breaking space as separator or not, reference
# list in or out) because the JSON does not say which were used; the variant that
# reproduces 10,114 on the 8 Sep docx (commit 107a569) is the one to trust.
#
# Opt-in, run by hand on a rendered .docx; not called by any pipeline stage. Needs xml2.
# Usage, from the project root:
#   Rscript --vanilla _shared/R/count_docx_words.R <label>=<file.docx> [...]
suppressPackageStartupMessages(library(xml2))

count_tokens <- function(x, nbsp_splits) {
  if (nbsp_splits) x <- gsub(" | | ", " ", x, perl = TRUE)
  # \s in PCRE without UCP does not match U+00A0, so a non-breaking space joins tokens
  # unless it was converted above.
  toks <- unlist(strsplit(x, "[ \t\r\n]+", perl = TRUE))
  sum(nzchar(toks))
}

read_paras <- function(docx) {
  tmp <- tempfile("docx_"); dir.create(tmp)
  utils::unzip(docx, files = "word/document.xml", exdir = tmp)
  doc <- read_xml(file.path(tmp, "word", "document.xml"))
  ns <- xml_ns(doc)
  paras <- xml_find_all(doc, "//w:body//w:p", ns)
  # Runs are concatenated without a separator because Word splits runs mid-word; tabs and
  # line breaks inside a paragraph do separate words, so they become spaces.
  ptext <- function(p, with_math) {
    xp <- if (with_math) ".//w:t | .//w:tab | .//w:br | .//w:cr | .//m:t"
          else ".//w:t | .//w:tab | .//w:br | .//w:cr"
    nodes <- xml_find_all(p, xp, ns)
    if (!length(nodes)) return("")
    nm <- xml_name(nodes)
    paste(ifelse(nm %in% c("tab", "br", "cr"), " ", xml_text(nodes)), collapse = "")
  }
  data.frame(
    i = seq_along(paras),
    style = vapply(paras, function(p) {
      s <- xml_attr(xml_find_first(p, "./w:pPr/w:pStyle", ns), "val")
      if (is.na(s)) "" else s
    }, character(1)),
    in_tbl = vapply(paras, function(p) length(xml_find_all(p, "ancestor::w:tbl", ns)) > 0,
                    logical(1)),
    text = vapply(paras, ptext, character(1), with_math = FALSE),
    text_m = vapply(paras, ptext, character(1), with_math = TRUE),
    has_math = vapply(paras, function(p) length(xml_find_all(p, ".//m:oMath", ns)) > 0,
                      logical(1)),
    stringsAsFactors = FALSE
  )
}

analyse <- function(label, docx) {
  d <- read_paras(docx)
  h1 <- which(d$style == "Heading1")
  abs_h <- which(d$style %in% c("Heading1", "AbstractTitle") & trimws(d$text) == "Abstract")[1]
  method_h <- h1[trimws(d$text[h1]) == "Method"][1]
  # The Introduction carries no heading of its own in APA style. The apaquarto docx
  # repeats the title as a Heading1 after the abstract page, and the Introduction begins
  # with the paragraph after it. The plain Quarto docx of 8 Sep (107a569) has no repeat,
  # and the Introduction begins with the first body paragraph after the abstract.
  title_rep <- h1[h1 > abs_h & h1 < method_h][1]
  if (!is.na(title_rep)) {
    start <- title_rep + 1L
  } else {
    cand <- which(seq_len(nrow(d)) > abs_h & d$style %in% c("FirstParagraph", "BodyText") &
                    nzchar(trimws(d$text)))
    start <- cand[1]
    title_rep <- start
  }
  # The first appendix heading: apaquarto labels it "Appendix A"; the plain docx has the
  # first Heading1 after "Supplementary material" (the reference list is not a heading
  # there, being placed after the appendices).
  app <- h1[grepl("^Appendix\\b", trimws(d$text[h1]))][1]
  if (is.na(app)) {
    supp <- h1[trimws(d$text[h1]) == "Supplementary material"][1]
    app <- h1[h1 > supp & trimws(d$text[h1]) != "References"][1]
  }
  end <- app - 1L
  refs_h <- h1[trimws(d$text[h1]) == "References" & h1 > start & h1 < app][1]
  rng <- start:end
  b <- d[rng, ]
  is_ref <- if (!is.na(refs_h)) b$i >= refs_h else rep(FALSE, nrow(b))
  is_cap <- b$style %in% c("FigureTitle", "Caption")
  is_note <- b$style %in% c("FigureNote")
  is_head <- grepl("^Heading", b$style)
  out <- list()
  for (with_math in c(FALSE, TRUE)) for (nb in c(FALSE, TRUE)) {
    tx <- if (with_math) b$text_m else b$text
    n <- vapply(tx, count_tokens, numeric(1), nbsp_splits = nb)
    out[[length(out) + 1]] <- data.frame(
      doc = label, math = with_math, nbsp_splits = nb,
      body_nontable_all = sum(n[!b$in_tbl]),
      table_words = sum(n[b$in_tbl]),
      references = sum(n[!b$in_tbl & is_ref]),
      body_nontable_excl_refs = sum(n[!b$in_tbl & !is_ref]),
      captions = sum(n[!b$in_tbl & !is_ref & is_cap]),
      notes = sum(n[!b$in_tbl & !is_ref & is_note]),
      headings = sum(n[!b$in_tbl & !is_ref & is_head]),
      prose_excl_refs_caps_notes = sum(n[!b$in_tbl & !is_ref & !is_cap & !is_note])
    )
  }
  res <- do.call(rbind, out)
  # Abstract: the paragraphs between the Abstract heading and the next page break or
  # heading, excluding the Keywords line.
  abs_rng <- (abs_h + 1L):(title_rep - 1L)
  abs_par <- d[abs_rng, ]
  abs_par <- abs_par[nzchar(trimws(abs_par$text)) & !grepl("^\\s*Keywords", abs_par$text), ]
  abs_words <- sum(vapply(abs_par$text, count_tokens, numeric(1), nbsp_splits = FALSE))
  # Display items in the main text: numbered titles before the first appendix heading.
  # apaquarto writes "Figure 1" as its own FigureTitle paragraph; the plain docx writes
  # "Figure 1: Title" as an ImageCaption.
  ttl_sty <- c("FigureTitle", "ImageCaption", "TableCaption")
  # apaquarto joins the label and its number with a non-breaking space ("Figure 1").
  ttl <- gsub(" ", " ", sub(":.*$", "", d[d$i < app & d$style %in% ttl_sty, "text"]))
  n_fig <- sum(grepl("^Figure [0-9]+$", trimws(ttl)))
  n_tab <- sum(grepl("^Table [0-9]+$", trimws(ttl)))
  app_ttl <- gsub(" ", " ", sub(":.*$", "", d[d$i > app & d$style %in% ttl_sty, "text"]))
  cat(sprintf("\n== %s (%s)\n", label, basename(docx)))
  cat(sprintf("paragraphs: %d; abstract heading p%d; title repeat p%d; intro starts p%d; references heading p%s; first appendix heading p%d ('%s')\n",
              nrow(d), abs_h, title_rep, start, refs_h, app, trimws(d$text[app])))
  cat(sprintf("intro first paragraph: %s...\n", substr(d$text[start], 1, 80)))
  cat(sprintf("paragraph before appendix: [%s] %s\n", d$style[end], substr(d$text[end], 1, 80)))
  cat(sprintf("abstract: %d paragraph(s), %d words; keywords line: %s\n", nrow(abs_par), abs_words,
              paste(substr(d$text[abs_rng][grepl("Keywords", d$text[abs_rng])], 1, 160), collapse = " | ")))
  cat(sprintf("main-text display items: %d figures, %d tables (%s); appendix items: %s\n",
              n_fig, n_tab, paste(trimws(ttl), collapse = ", "), paste(trimws(app_ttl), collapse = ", ")))
  cat(sprintf("paragraphs with OMML math in range: %d\n", sum(b$has_math)))
  print(res, row.names = FALSE)
  invisible(res)
}

args <- commandArgs(trailingOnly = TRUE)
options(width = 250)
for (a in args) {
  kv <- strsplit(a, "=", fixed = TRUE)[[1]]
  analyse(kv[1], paste(kv[-1], collapse = "="))
}
