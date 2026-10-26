# =============================================================================
# 06_manuscript_helpers.R  --  Reporting helpers shared by the two manuscripts
# =============================================================================
#
# Both manuscripts (paper_1_transfer/paper_1_morphosyntax.qmd and
# paper_2_plasticity/paper_2_neuroplasticity.qmd, with its supplement) source this file
# from their setup chunk, directly after their _config.R, so that one house style governs
# every figure and table of both papers. In order, the file defines
#   1. the colour, shape and level-order registry (LES_*), in which a hue means one
#      variable in every figure;
#   2. the figure themes les_theme(), les_forest_theme() and les_row_title_theme(), and
#      les_placeholder() for a figure whose results are withheld;
#   3. scales, axis-label formatters and factor builders (les_scale_*(), les_lab_*(),
#      les_minus(), les_wrap(), les_property_factor(), les_judgement_frame());
#   4. shared layers: reference lines, the judgement-series marks, blanked design cells
#      and the ERP time-course frame;
#   5. les_grid_table(), the one writer of manuscript tables, and its cell formatters;
#   6. the number formatter and artefact readers of the running text (apa_num(),
#      .read_csv_if(), prov(), flow_n(), pstat()).
# A change to sections 1-5 changes every figure or table in both papers, so render both
# PDFs, the Word outputs and the supplement after editing them.
#
# Some helpers read document-level inputs. The figure helpers take the text size from
# LES_FIG_BASE_SIZE, which each setup chunk sets before sourcing this file.
# LES_PROPERTY_LABELS_FIG is built from LES_PROPERTY_LABELS, and the tables use
# LES_PROPERTY_LABELS_TABLE; both come from _shared/R/03_data_manifest.R, which each
# _config.R sources. prov(), flow_n() and pstat() read .prov_tbl, flow_tbl and
# parts_tbl, which each setup chunk loads from its own results/ folder after sourcing
# this file. Quarto evaluates the chunks in the global environment, which is also where
# source() places these functions, so the lookups resolve at call time.
# =============================================================================

# --- 1. Colour, shape and level-order registry ----------------------------------
# Okabe and Ito (2008) colours, which stay distinguishable under the common colour-vision
# deficiencies. A hue named here encodes ONE variable in every figure of both papers, so
# blue means Mini-Norwegian wherever it appears and bluish green means "Ungrammatical".
# Mini-Norwegian comes first everywhere: legends, flow-diagram arms (left), table rows
# and contrasts ("Mini-Norwegian minus Mini-English").
LES_LANG_LEVELS  <- c("Mini-Norwegian", "Mini-English")
LES_LANG_COLS    <- c(`Mini-Norwegian` = "#0072B2", `Mini-English` = "#D55E00")
LES_LANG_SHAPES  <- c(`Mini-Norwegian` = 16, `Mini-English` = 17)
# Grammaticality takes colour only where language is already a facet (Paper 1's
# grand-average waveforms). Elsewhere it is a facet row, never a linetype.
LES_GRAM_LEVELS  <- c("Grammatical", "Ungrammatical")
LES_GRAM_COLS    <- c(Grammatical = "#000000", Ungrammatical = "#009E73")
# The two Part A model strata of Paper 2.
LES_MODEL_LEVELS <- c("Pooled model", "Gender-agreement model")
LES_MODEL_COLS   <- c(`Pooled model` = "#000000", `Gender-agreement model` = "#7A7A7A")
LES_MODEL_SHAPES <- c(`Pooled model` = 21, `Gender-agreement model` = 24)
LES_OTHER_COLS   <- c("#000000", "#CC79A7", "#E69F00")   # any other categorical variable, in this order
LES_REF_COL      <- "grey60"   # zero, chance, onset and band-edge lines
LES_BAND_COL     <- "grey45"   # ERP analysis-window bars
LES_PRESTIM_FILL <- "grey93"   # the decoding negative-control interval, and nothing else
LES_INK          <- "grey15"   # single-series ink and direct labels
LES_TEXT_PT      <- 8          # in-panel text in points, which is also the print floor
# Marks: mean-point size (mm), series and interval line width, dense 2-4 ms traces,
# reference lines, and the dodge between two groups on a discrete axis.
LES_PT <- 1.9; LES_LWD <- 0.55; LES_LWD_TRACE <- 0.45; LES_LWD_REF <- 0.3; LES_DODGE <- 0.35
LES_JUDGEMENT_SESSIONS <- c(2, 3, 4, 6)

# Endpoints and midpoint of the diverging scale used for signed quantities (the scalp
# topography in Paper 1; the predictor correlation matrix in Paper 2). Taken from
# depictr so both papers share one diverging scale. The fallback repeats depictr's
# diverging endpoints and midpoint. #005B96 is depictr's blue, and the red and the
# midpoint coincide with ColorBrewer RdBu.
les_div <- if (requireNamespace("depictr", quietly = TRUE))
  depictr::depictr_palette(5, "diverging")[c(5, 3, 1)] else
  c("#005B96", "#F7F7F7", "#B2182B")

# --- 2. Figure themes -------------------------------------------------------------
# depictr's theme_depictr() is the base when it is installed, and ggplot2's
# theme_minimal() otherwise. theme_depictr() boxes the legend (a grey85 outline),
# centres a bold legend title, colours the plot title and fills the facet strips grey96,
# and each of those is overridden here once, so that no chunk has to repeat the fix.
# `grid` keeps the major grid in one direction: "y" gives horizontal lines (time
# courses, trajectories, box plots), "x" vertical lines (forests, the design schedule)
# and "none" no grid (heat maps, flow diagrams). The depictr flag is an argument,
# defaulting to whether the package is installed, so the helper does not depend on a
# variable of the calling document.
# Chunk-level overrides use absolute point sizes. rel() on a child element compounds with
# the parent's rel() and prints below the 8 pt floor.
les_theme <- function(base_size = LES_FIG_BASE_SIZE, grid = c("y", "x", "xy", "none"),
                      has_depictr = requireNamespace("depictr", quietly = TRUE)) {
  grid <- match.arg(grid)
  base <- if (has_depictr) depictr::theme_depictr(base_size = base_size, grid = grid) else {
    th <- ggplot2::theme_minimal(base_size = base_size)
    if (grid %in% c("x", "none")) th <- th + ggplot2::theme(panel.grid.major.y = ggplot2::element_blank())
    if (grid %in% c("y", "none")) th <- th + ggplot2::theme(panel.grid.major.x = ggplot2::element_blank())
    th
  }
  base + ggplot2::theme(
    text              = ggplot2::element_text(colour = "black"),
    axis.title        = ggplot2::element_text(size = ggplot2::rel(1)),
    axis.text         = ggplot2::element_text(size = ggplot2::rel(0.85), colour = "grey20"),
    axis.ticks        = ggplot2::element_line(colour = "grey70", linewidth = 0.3),
    axis.ticks.length = ggplot2::unit(2, "pt"),
    panel.grid.major  = ggplot2::element_line(colour = "grey92", linewidth = 0.3),
    panel.grid.minor  = ggplot2::element_blank(),
    panel.spacing     = ggplot2::unit(10, "pt"),
    # Strips carry no fill and read as plain labels: column strips left-aligned over
    # their panel, row strips horizontal. clip = "off" lets a long label run past the
    # strip instead of being cut.
    strip.background  = ggplot2::element_blank(),
    strip.text        = ggplot2::element_text(size = ggplot2::rel(0.9), face = "plain", colour = "black",
                                              hjust = 0, margin = ggplot2::margin(t = 2, b = 4)),
    strip.text.y      = ggplot2::element_text(angle = 0, hjust = 0, margin = ggplot2::margin(l = 4)),
    strip.text.y.left = ggplot2::element_text(angle = 0, hjust = 1, margin = ggplot2::margin(r = 4)),
    strip.placement   = "outside",
    strip.clip        = "off",
    # One legend row at the top, flush with the left edge of the whole plot, unboxed.
    # A legend title is set only where the levels are ambiguous without one; the scales
    # otherwise pass name = NULL.
    legend.position   = "top",
    legend.justification.top = "left",
    legend.location   = "plot",
    legend.background = ggplot2::element_blank(),
    legend.box.background = ggplot2::element_blank(),
    legend.key        = ggplot2::element_blank(),
    legend.title      = ggplot2::element_text(size = ggplot2::rel(0.9), face = "plain", hjust = 0),
    legend.text       = ggplot2::element_text(size = ggplot2::rel(0.9), margin = ggplot2::margin(l = 3, r = 10)),
    legend.key.width  = ggplot2::unit(16, "pt"),
    legend.key.height = ggplot2::unit(10, "pt"),
    legend.key.spacing.x = ggplot2::unit(6, "pt"),
    legend.key.spacing.y = ggplot2::unit(3, "pt"),
    legend.margin     = ggplot2::margin(0, 0, 0, 0),
    legend.box.spacing = ggplot2::unit(4, "pt"),
    # Block titles (patchwork blocks). The colour is set explicitly because a theme
    # addition only replaces the properties it names, and depictr colours the title.
    plot.title        = ggplot2::element_text(size = ggplot2::rel(0.95), face = "bold", colour = "black",
                                              hjust = 0, margin = ggplot2::margin(b = 2)),
    plot.title.position = "plot",
    plot.margin       = ggplot2::margin(4, 8, 4, 4),
    # Defaults for the geoms: fontsize is in points, so annotation text prints at 8 pt.
    geom = ggplot2::element_geom(ink = "black", linewidth = 0.5, pointsize = 1.8, fontsize = LES_TEXT_PT))
}

# Forests: vertical grid only and a thin grey80 frame per panel (the only framed panels
# in either paper), which holds each column of estimates together; the term labels on
# the y axis need no ticks.
les_forest_theme <- function(base_size = LES_FIG_BASE_SIZE)
  les_theme(base_size, grid = "x") + ggplot2::theme(
    panel.border = ggplot2::element_rect(colour = "grey80", fill = NA, linewidth = 0.3),
    axis.ticks.y = ggplot2::element_blank())

# A measure-row strip moved left (facet_grid(..., switch = "y")) that replaces the y-axis
# title, as in "Sensitivity (d')" over "Criterion (c)". It is styled exactly like an axis
# title: 10 pt, rotated, no box, with axis.title.y blanked.
les_row_title_theme <- function() ggplot2::theme(
  strip.text.y.left = ggplot2::element_text(angle = 90, hjust = 0.5, size = LES_FIG_BASE_SIZE,
                                            lineheight = 0.95, margin = ggplot2::margin(r = 4)),
  axis.title.y = ggplot2::element_blank())

# What a withheld figure shows until its results are in: one grey30 sentence at the base
# size. The chunk sizes itself with fig-height: !expr if (<ready flag>) H else 1.
les_placeholder <- function(text) ggplot2::ggplot() +
  ggplot2::annotate("text", x = 0, y = 0, label = text, size = LES_FIG_BASE_SIZE / ggplot2::.pt,
                    colour = "grey30") + ggplot2::theme_void(base_size = LES_FIG_BASE_SIZE)

# --- 3. Scales, label formatters and factors ----------------------------------------
# Colour and shape scales that share name = NULL and identical breaks, so ggplot2 merges
# them into one legend per variable. `aesthetics` lets one call cover colour and fill
# (the ERP figures key line plus ribbon from a single scale).
les_scale_language <- function(aesthetics = c("colour", "fill"), ...)
  ggplot2::scale_colour_manual(values = LES_LANG_COLS, breaks = LES_LANG_LEVELS, name = NULL,
                               aesthetics = aesthetics, ...)
les_scale_language_shape <- function(...)
  ggplot2::scale_shape_manual(values = LES_LANG_SHAPES, breaks = LES_LANG_LEVELS, name = NULL, ...)
les_scale_grammaticality <- function(aesthetics = c("colour", "fill"), ...)
  ggplot2::scale_colour_manual(values = LES_GRAM_COLS, breaks = LES_GRAM_LEVELS, name = NULL,
                               aesthetics = aesthetics, ...)
les_scale_other <- function(levels, aesthetics = c("colour", "fill"), ...)
  ggplot2::scale_colour_manual(values = stats::setNames(LES_OTHER_COLS[seq_along(levels)], levels),
                               breaks = levels, name = NULL, aesthetics = aesthetics, ...)

# True minus sign (U+2212) for a hyphen-minus that starts a number: at the start of the
# string or after a character that cannot end a word or a number, such as a space or an
# opening bracket. A hyphen inside a word, a range ("2-4") or a date is left alone, and
# so is the second hyphen of a pandoc en dash ("2--4"). The fonts of both outputs (TeX
# Gyre Termes X in the PDF, Times New Roman in Word) carry the glyph. Not for $...$ maths.
les_minus <- function(x) gsub("(^|[^0-9A-Za-z.-])-(?=[0-9.])", "\\1\u2212", x, perl = TRUE)
# Signed continuous axes and colour bars: true minus, and no trailing zeros, so zero
# prints as "0". ggplot2's own scale functions are not masked.
les_lab_num  <- scales::label_number(style_negative = "minus", drop0trailing = TRUE, big.mark = ",")
# Proportions (bounded by 1) without the leading zero, per APA 7: .00 .25 .50 .75 1.00.
les_lab_prop <- function(x) ifelse(is.na(x), NA_character_,
                                   sub("^0\\.", ".", formatC(x, format = "f", digits = 2)))
# Correlations and other quantities bounded by 1 in absolute value: ".87", "-.35" with a
# true minus.
les_lab_r    <- function(x) ifelse(is.na(x), NA_character_,
                                   les_minus(sub("^(-?)0\\.", "\\1.", formatC(x, format = "f", digits = 2))))

# LES_PROPERTY_LABELS (03_data_manifest.R) keeps a hyphen in "Verb-object" because it is
# the key the importer writes and several lookups match on it. Figures convert it to the
# en dash at display time.
les_prop_label <- function(x) gsub("([Vv]erb)-(object)", "\\1\u2013\\2", x)
if (exists("LES_PROPERTY_LABELS"))
  LES_PROPERTY_LABELS_FIG <- les_prop_label(LES_PROPERTY_LABELS)   # keyed like the others
# Facet labeller that converts the property dash and wraps at a fixed width: 18 for the
# narrow free-width columns of the behavioural figures, 20 for three equal columns with
# right-hand strips, 22 for forest term strips.
les_wrap <- function(width) ggplot2::as_labeller(function(x)
  unname(vapply(les_prop_label(x), function(s) paste(strwrap(s, width), collapse = "\n"), "")))
# Property factor in design order with the display labels. Accepts the snake_case keys
# or any of the three label forms (the hyphenated one is what the ERP CSVs store).
les_property_factor <- function(x) {
  x <- as.character(x)
  keys <- names(LES_PROPERTY_LABELS)
  forms <- list(keys, unname(LES_PROPERTY_LABELS), unname(LES_PROPERTY_LABELS_FIG),
                if (exists("LES_PROPERTY_LABELS_TABLE")) unname(LES_PROPERTY_LABELS_TABLE))
  key <- rep(NA_character_, length(x))
  for (f in Filter(Negate(is.null), forms)) {
    todo <- is.na(key)
    key[todo] <- keys[match(x[todo], f)]
  }
  f <- factor(unname(LES_PROPERTY_LABELS_FIG[key]), levels = unname(LES_PROPERTY_LABELS_FIG))
  if (anyNA(f[!is.na(x)])) warning("les_property_factor(): unrecognised property label(s): ",
                                   paste(unique(x[is.na(f) & !is.na(x)]), collapse = ", "))
  f
}
# The three factors every judgement figure needs, from the columns the accuracy CSVs
# carry. Session is discrete and equally spaced (the models' 0-3 coding).
les_judgement_frame <- function(d) {
  d$Property <- les_property_factor(d$grammatical_property)
  d$Language <- factor(d$mini_language, levels = LES_LANG_LEVELS)
  d$Session  <- factor(d$session, levels = LES_JUDGEMENT_SESSIONS)
  d
}

# --- 4. Layers ------------------------------------------------------------------------
# Reference lines (zero, chance, onset, band edges): solid grey60, thin. Add them first,
# so the data are drawn over them.
les_ref_h <- function(y = 0, ...) ggplot2::geom_hline(yintercept = y, colour = LES_REF_COL, linewidth = LES_LWD_REF, ...)
les_ref_v <- function(x = 0, ...) ggplot2::geom_vline(xintercept = x, colour = LES_REF_COL, linewidth = LES_LWD_REF, ...)

# Group means by session: line, uncapped interval and point, dodged as one. The interval
# is kept out of the legend, so the key shows line and point.
les_judgement_layers <- function(ymin = "ci_low", ymax = "ci_high") {
  pd <- ggplot2::position_dodge(width = LES_DODGE)
  list(ggplot2::geom_line(position = pd, linewidth = LES_LWD),
       ggplot2::geom_linerange(ggplot2::aes(ymin = .data[[ymin]], ymax = .data[[ymax]]),
                               position = pd, linewidth = LES_LWD, show.legend = FALSE),
       ggplot2::geom_point(position = pd, size = LES_PT))
}
les_judgement_theme <- function() les_theme() + ggplot2::theme(
  panel.spacing.x = ggplot2::unit(12, "pt"), panel.spacing.y = ggplot2::unit(14, "pt"),
  strip.text.x = ggplot2::element_text(size = 9, lineheight = 0.95, hjust = 0,
                                       margin = ggplot2::margin(t = 3, b = 3)))

# Blank the facet_grid cells the design leaves structurally empty (a property at a session
# before it was introduced). Add it as the LAST layer: it paints each absent cell white
# over the grid, the reference lines and the window bars. `rows` and `cols` name factor
# columns of `data`.
les_blank_cells <- function(data, rows, cols) {
  all <- expand.grid(r = levels(data[[rows]]), c = levels(data[[cols]]), stringsAsFactors = FALSE)
  e <- all[!paste(all$r, all$c) %in% unique(paste(data[[rows]], data[[cols]])), , drop = FALSE]
  e <- stats::setNames(data.frame(factor(e$r, levels(data[[rows]])),
                                  factor(e$c, levels(data[[cols]]))), c(rows, cols))
  ggplot2::geom_rect(data = e, xmin = -Inf, xmax = Inf, ymin = -Inf, ymax = Inf,
                     fill = "white", colour = NA, inherit.aes = FALSE)
}

# ERP time courses. The frame is data-driven, so a reprocessed session cannot clip: pass
# the lowest and highest value to be drawn (ribbons included) and the y breaks. A gutter
# taking the bottom `gut` of the panel, below the data, holds the three stacked
# analysis-window bars (200-500, 300-600 and 400-900 ms from the top; the sample ends are
# 498, 598 and 898 ms) and the next-word triangle, so neither overlaps a waveform.
LES_ERP_WINDOWS <- data.frame(start = c(200, 300, 400), end = c(498, 598, 898))
les_erp_frame <- function(lo, hi, breaks, gut = 0.15) {
  lo <- min(lo, min(breaks)); hi <- max(hi, max(breaks))
  g <- gut * (hi - lo) / (1 - gut)
  list(ylim = c(lo - g, hi), bars = lo - g * c(0.12, 0.30, 0.48), tri = lo - g * 0.82, breaks = breaks)
}
# Zero and onset lines, the window bars, the next-word triangle (skipped when the onset is
# unknown) and the axes: -100 to 1100 ms without expansion, breaks every 200 ms, labelled
# at 0, 400 and 800 ms for narrow panels.
les_erp_layers <- function(fr, next_word_ms = NA_real_) list(
  les_ref_h(0), les_ref_v(0),
  ggplot2::annotate("segment", x = LES_ERP_WINDOWS$start, xend = LES_ERP_WINDOWS$end,
                    y = fr$bars, yend = fr$bars, colour = LES_BAND_COL, linewidth = 0.8, lineend = "butt"),
  if (isTRUE(is.finite(next_word_ms)))
    ggplot2::annotate("point", x = next_word_ms, y = fr$tri, shape = 24, size = 1.4,
                      colour = "grey35", fill = "grey35"),
  ggplot2::scale_x_continuous(breaks = seq(0, 1000, 200),
    labels = function(x) ifelse(x %% 400 == 0, format(x, trim = TRUE), ""), expand = c(0, 0)),
  ggplot2::scale_y_continuous(breaks = fr$breaks, labels = les_lab_num),
  ggplot2::coord_cartesian(xlim = c(-100, 1100), ylim = fr$ylim, expand = FALSE))

# --- 5. Table writer ------------------------------------------------------------------
# les_grid_table() writes every manuscript table of both papers and the supplement as a
# Pandoc grid table. Pandoc (>= 3) reads column spanners and full-width group rows from a
# grid table into the ordinary Table AST, so apaquarto's captions and notes, its
# apa-longtable path and Quarto's @tbl- cross-references work unchanged, and both outputs
# carry the spans: \multicolumn in the PDF's longtable and w:gridSpan in Word, where the
# header rows also repeat on each page. A pipe table (knitr::kable()) can carry neither.
# The heads of spanners and of numeric columns are centred by
# _shared/lua/apa-table-heads.lua, which both papers register as a filter.
#
# body     data.frame of already-formatted character columns. NA prints as a blank cell
#          (not applicable by design); pass an em dash for a value expected but not
#          obtained. A hyphen-minus that starts a number becomes a true minus, except in
#          a cell holding $...$ maths.
# header   one column head per column, Markdown allowed ("*Mdn*", "*p*~d~",
#          "$\\widehat{R}$")
# align    "l", "r" or "c" per column
# widths   NULL for the table's natural width, so a small table is not stretched across
#          the measure; otherwise relative column widths as fractions of the text width
#          (sum <= 1). Pandoc takes a grid table's widths from its dash counts, and
#          Quarto's tbl-colwidths option is not applied to grid tables, so widths are set
#          here and nowhere else.
# spanners optional list of list(label = , cols = contiguous integer columns)
# group    optional character vector, one per row; a full-width group row is inserted
#          whenever it changes and the first column beneath it is indented
# subgroup optional second level nested in `group`, indented one step further
# decimals names of columns padded to a common number of decimals, so that right
#          alignment is also decimal alignment
les_grid_table <- function(body, header = names(body), align, widths = NULL,
                           spanners = NULL, group = NULL, subgroup = NULL,
                           decimals = character()) {
  latex <- knitr::is_latex_output()
  body[] <- lapply(body, function(x) { x <- as.character(x); x[is.na(x)] <- ""; x })
  body[] <- lapply(body, function(x) {
    k <- !grepl("$", x, fixed = TRUE)
    x[k] <- les_minus(x[k])
    x
  })
  nc <- ncol(body)
  stopifnot(length(header) == nc, length(align) == nc)
  # Pandoc trims trailing Unicode spaces from a cell, and TeX Gyre Termes X has no figure
  # space, so the PDF pads with \phantom{0} and Word with U+2007 closed by a word joiner
  # (U+2060), which stops Pandoc trimming the padding.
  pad_dec <- function(x) {
    dec <- ifelse(grepl("\\.[0-9]+", x), nchar(sub("^[^.]*\\.([0-9]+).*$", "\\1", x)), 0L)
    dec[!grepl("[0-9]", x)] <- NA
    m <- suppressWarnings(max(dec, na.rm = TRUE))
    if (!is.finite(m)) return(x)
    k <- !is.na(dec) & dec < m
    fig <- if (latex) "\\phantom{0}" else intToUtf8(0x2007)
    x[k] <- paste0(x[k], strrep(fig, m - dec[k]), if (latex) "" else intToUtf8(0x2060))
    x
  }
  for (j in intersect(decimals, names(body))) body[[j]] <- pad_dec(body[[j]])
  # A grid-table cell is block Markdown: a leading "> " opens a block quote (the "> .999"
  # of a capped p_d vanished from the cell in testing), and a leading "#", "+", "*" or "- "
  # starts a heading or a list. Escape them; the no-break space keeps "> .999" together.
  nb <- intToUtf8(0x00A0)
  esc <- function(x) {
    x <- sub("^> ", paste0("\\\\>", nb), x)
    sub("^([#+*]|- )", "\\\\\\1", x)
  }
  body[] <- lapply(body, esc)
  indent <- strrep(nb, 3L)
  lvl <- (!is.null(group)) + (!is.null(subgroup))
  if (lvl > 0) body[[1]] <- paste0(strrep(indent, lvl), body[[1]])
  # Display width, not code points: Pandoc aligns grid-table cells by display width, so a
  # zero-width word joiner counted as one character shifts every later cell boundary
  nw <- function(x) nchar(x, type = "width")
  w <- pmax(nw(header), vapply(body, function(x) max(c(nw(x), 0L)), 1L), 3L)
  span_w <- function(cols) sum(w[cols]) + 3L * (length(cols) - 1L)
  for (s in spanners) {
    need <- nw(s$label) - span_w(s$cols)
    if (need > 0) w[max(s$cols)] <- w[max(s$cols)] + need
  }
  labels <- unique(c(group, if (!is.null(subgroup)) paste0(indent, subgroup)))
  if (length(labels)) {
    need <- max(nw(labels)) - span_w(seq_len(nc))
    if (need > 0) w[1] <- w[1] + need
  }
  if (!is.null(widths)) {
    stopifnot(length(widths) == nc)
    total <- max(ceiling((w + 3L) / widths))
    w <- pmax(w, round(widths * total) - 3L)
  }
  full_w <- span_w(seq_len(nc))
  padr <- function(x, n) paste0(x, strrep(" ", n - nw(x)))
  rule <- function(ch = "-", colons = FALSE) {
    segs <- vapply(seq_len(nc), function(j) {
      s <- strrep(ch, w[j] + 2L)
      if (colons && align[j] %in% c("l", "c")) substr(s, 1, 1) <- ":"
      if (colons && align[j] %in% c("r", "c")) substr(s, w[j] + 2L, w[j] + 2L) <- ":"
      s
    }, "")
    paste0("+", paste(segs, collapse = "+"), "+")
  }
  line <- function(cells, widths_) paste0("| ", paste(mapply(padr, cells, widths_), collapse = " | "), " |")
  out <- rule()
  if (length(spanners)) {
    cells <- character(); cw <- integer(); j <- 1L
    starts <- vapply(spanners, function(s) min(s$cols), 1L)
    while (j <= nc) {
      k <- match(j, starts)
      if (!is.na(k)) {
        s <- spanners[[k]]; cells <- c(cells, s$label); cw <- c(cw, span_w(s$cols))
        j <- max(s$cols) + 1L
      } else { cells <- c(cells, ""); cw <- c(cw, w[j]); j <- j + 1L }
    }
    out <- c(out, line(cells, cw), rule())
  }
  out <- c(out, line(header, w), rule("=", colons = TRUE))
  prev_g <- prev_s <- NULL
  for (i in seq_len(nrow(body))) {
    if (!is.null(group) && !identical(group[i], prev_g)) {
      out <- c(out, line(group[i], full_w), rule()); prev_g <- group[i]; prev_s <- NULL
    }
    if (!is.null(subgroup) && !identical(subgroup[i], prev_s)) {
      out <- c(out, line(paste0(indent, subgroup[i]), full_w), rule()); prev_s <- subgroup[i]
    }
    out <- c(out, line(unlist(body[i, ]), w), rule())
  }
  knitr::asis_output(paste(c("", out, ""), collapse = "\n"))
}

# Cell formatters. Each returns "" for NA, which les_grid_table() prints as a blank cell.
# les_num: fixed decimals with a true minus. les_int: whole numbers with a comma
# thousands separator (ESS "1,711"). les_fmt_bounded: quantities bounded by 1 (r,
# reliability, proportions) without the leading zero. les_range: an en-dash range.
les_num <- function(x, digits = 2, big.mark = "")
  ifelse(is.na(x), "", les_minus(formatC(x, format = "f", digits = digits, big.mark = big.mark)))
les_int <- function(x) ifelse(is.na(x), "", formatC(round(x), format = "d", big.mark = ","))
les_fmt_bounded <- function(x, digits = 2)
  ifelse(is.na(x), "", les_minus(sub("^(-?)0\\.", "\\1.", formatC(x, format = "f", digits = digits))))
les_range <- function(a, b) paste0(a, "–", b)

# --- 6. Number formatters and artefact readers of the running text ---------------------
# papaja's apa_num() formats the numbers of the running text. It is required, not
# optional: a base-R stand-in would print some values differently (papaja writes 1,234.5
# where formatC() writes 1234.5), so a render without papaja would change reported
# numbers without any sign of it. papaja is pinned in renv.lock (0.1.5).
if (!requireNamespace("papaja", quietly = TRUE)) {
  stop("papaja is required to format the reported numbers; install the version pinned ",
       "in renv.lock (0.1.5).", call. = FALSE)
}
apa_num <- papaja::apa_num

# One probability-of-direction format for both papers (ISSUES.md X6-02). pd is bounded by 1
# like a p value, so the leading zero is dropped (APA 7) and it is reported as a proportion
# everywhere: inline reporters, ranges and tables. A percentage in one place and a
# proportion in another invited misreading of borderline values (".95" against "95").
# Values at or above .995 keep a third decimal, so that near-certainty does not round up to
# 1.00, and values above .9995 print as "> .999".
#   x  numeric vector of probabilities of direction
# Returns a character vector, "NA" where x is not finite.
.fmt_pd <- function(x) {
  vapply(x, function(v) {
    if (!is.finite(v)) return("NA")
    if (v > 0.9995) return("> .999")
    sub("^0", "", formatC(v, format = "f", digits = if (v >= 0.995) 3 else 2))
  }, "")
}
# The math-mode fragment "p_d = .95", or "p_d > .999" for the capped case, so that the
# relation sign is never doubled after an equals sign.
.pd_math <- function(x) {
  s <- .fmt_pd(x)
  if (startsWith(s, ">")) paste0("p_d ", s) else paste0("p_d = ", s)
}
# Read a results CSV when it exists, NULL otherwise: the render-anytime design rests on
# every artefact reader tolerating an absent file.
.read_csv_if <- function(path) if (file.exists(path)) utils::read.csv(path, stringsAsFactors = FALSE) else NULL

# Computational provenance recorded at fit time by _shared/R/04_provenance.R, read from
# the document's .prov_tbl, so the reported versions are those of the run that produced
# the results and not of the machine rendering the document. Absent until the pipeline
# is next run. Returns `fallback` when .prov_tbl is NULL or `component` does not match
# exactly one row with a non-NA version.
prov <- function(component, fallback = "*[version pending a pipeline run]*") {
  if (is.null(.prov_tbl)) return(fallback)
  r <- .prov_tbl[.prov_tbl$component == component, , drop = FALSE]
  if (nrow(r) != 1 || is.na(r$version[1])) return(fallback)
  as.character(r$version[1])
}

# Participant-flow count for a stage of the document's flow_tbl; `col` picks total or a
# per-language column, one of n_total, n_mini_english and n_mini_norwegian. Returns the
# count as a character string, or "NN" when flow_tbl is NULL or `stage` does not match
# exactly one row with a non-NA value in `col`.
flow_n <- function(stage, col = "n_total") {
  if (is.null(flow_tbl)) return("NN")
  r <- flow_tbl[flow_tbl$stage == stage, , drop = FALSE]
  if (nrow(r) != 1 || is.na(r[[col]])) return("NN")
  as.character(r[[col]])
}

# Demographic metric from the document's parts_tbl (value / sd / n / vmin / vmax).
# A numeric value is formatted by apa_num() with `digits` decimals, so a count is printed
# with digits = 0 and a mean that happens to be whole still shows its decimals ("25.0",
# not "25"); a non-numeric value comes back through as.character(). Returns "NN" when
# parts_tbl is NULL or `metric` does not match exactly one row with a non-NA value in
# `col`.
pstat <- function(metric, col = "value", digits = 1) {
  if (is.null(parts_tbl)) return("NN")
  r <- parts_tbl[parts_tbl$metric == metric, , drop = FALSE]
  if (nrow(r) != 1 || is.na(r[[col]])) return("NN")
  v <- r[[col]]
  if (is.numeric(v)) apa_num(v, digits = digits) else as.character(v)
}
