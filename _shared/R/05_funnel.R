# =============================================================================
# 05_funnel.R  --  Shared participant-flow figure generator
# =============================================================================
#
# Both manuscripts report participant flow, but they draw on DIFFERENT stages of
# the same cohort: Paper 1 uses the four EEG sessions and its ERP/judgement samples,
# Paper 2 uses the Session-1 and Session-5 cognitive battery, the Session-2
# resting-state recording, and the learning trajectory. A single shared figure would
# therefore show each paper stages it does not use -- which is exactly the defect the
# methods audit found in Paper 1's original flow diagram, where four Paper 2 stages
# were rendered into Paper 1's chain. The generator is shared so the two figures are
# visually identical; the CONTENT is paper-specific.
#
# les_flow() draws a CONSORT-style diagram (Schulz et al., 2010): enrolment split into
# the two mini-language arms, the attendance of each arm at each session, and the
# analysis samples. It is monochrome and has no legend; the arms are placed in
# LES_LANG_LEVELS order (06_manuscript_helpers.R), so Mini-Norwegian is on the left.
# The stages are not strictly nested, and the layout says so without a note:
#   * attendance is not monotonic (a participant who missed Session 5 returned for
#     Session 6), so each session is a line in one box per arm, with its absences,
#     and no arrows run between sessions;
#   * the analysis samples pool data across sessions, so they can exceed the last
#     session's attendance and hang from no attendance box;
#   * only a genuinely nested chain (Paper 2's Part A sample) is joined by arrows,
#     with the participants removed at each step in a box beside the arrow.
# Every count is passed in or derived here (a difference of two passed counts); none
# is typed into the figure.
#
# les_flow() replaced les_funnel(), a ghost-bar funnel that labelled each step with the
# difference of two stage totals and so misstated attrition wherever the stages were not
# nested (ISSUES.md G02-01).
#
# les_flow(enrolled, arms, attendance, analysis_arms = NULL, analysis_pooled = NULL,
#          pooled_footnote = NULL, headings, base_size = LES_FIG_BASE_SIZE)
# enrolled         total enrolled and assigned a mini-language
# arms             named count per arm, in LES_LANG_LEVELS order (left arm first)
# attendance       data.frame(session, n_a, n_b): attendance per session, n_a the left arm
# analysis_arms    (Paper 1) data.frame(label, n_a, n_b), one line per analysis sample
#                  in each arm's box; an optional `short` column names each sample in the
#                  "Not analysed" box when the arm's shortfalls differ between samples
# analysis_pooled  (Paper 2) data.frame(label, n, dropped): a nested chain of pooled
#                  samples; dropped[i] names the reason for the step into row i (NA
#                  for the first row)
# pooled_footnote  optional c(label, n), set in italics under the last chain box
# headings         the section headings: enrolment, attendance and, when an analysis
#                  section is drawn, analysis
# Returns a ggplot drawn on a 6.5 in wide canvas in which one data unit is one inch.
# The height the diagram needs is attached as attr(p, "les_flow_height") (inches); the
# chunk's fig-height should equal it, and a warning is raised when it is smaller.
les_flow <- function(enrolled, arms, attendance, analysis_arms = NULL,
                     analysis_pooled = NULL, pooled_footnote = NULL, headings,
                     base_size = LES_FIG_BASE_SIZE) {
  has_arms_sec   <- !is.null(analysis_arms)
  has_pooled_sec <- !is.null(analysis_pooled)
  stopifnot(length(arms) == 2L, !is.null(names(arms)), is.data.frame(attendance),
            all(c("session", "n_a", "n_b") %in% names(attendance)),
            !(has_arms_sec && has_pooled_sec),
            length(headings) >= 2L + (has_arms_sec || has_pooled_sec))
  num <- function(x) suppressWarnings(as.integer(x))
  enrolled <- num(enrolled); arm_n <- num(arms); arm_lab <- names(arms)
  att_a <- num(attendance$n_a); att_b <- num(attendance$n_b)
  # Guards: no subset may exceed the arm it is drawn from.
  le <- function(x, cap) all(is.na(cap) | is.na(x) | x <= cap)
  stopifnot(le(att_a, arm_n[1]), le(att_b, arm_n[2]))
  if (!anyNA(c(enrolled, arm_n)) && sum(arm_n) != enrolled)
    warning("les_flow(): the two arms (", sum(arm_n), ") do not add up to the enrolled total (",
            enrolled, ").")
  if (has_arms_sec) {
    an_a <- num(analysis_arms$n_a); an_b <- num(analysis_arms$n_b)
    stopifnot(le(an_a, arm_n[1]), le(an_b, arm_n[2]))
  }
  if (has_pooled_sec) {
    pool_n <- num(analysis_pooled$n)
    stopifnot(le(pool_n, enrolled))
  }

  # Geometry, in inches on the 6.5 in canvas.
  W     <- 6.5
  fs    <- 0.85 * base_size        # box text, pt
  lh    <- fs * 1.3 / 72           # line height
  pad   <- 0.075                   # box padding, top and bottom
  hs    <- base_size / 72          # heading text height
  inset <- 0.12                    # left inset of left-aligned box text
  row_gap <- 0.22                  # between two rows of boxes
  arm_x <- c(2.15, 4.35); arm_w <- 1.95
  edge  <- 0.01                    # keeps a flush box's outline inside the canvas
  box_h <- function(k) k * lh + 2 * pad

  # Labels are plotmath, so that n can be italic. Each is framed by a phantom pair of
  # parentheses, which gives every line the same ascent and descent, so vertically
  # centred lines keep a common baseline whatever glyphs they contain. The section
  # headings carry the pair after the text (pm_r), so that they start exactly where
  # their rule does.
  q  <- function(s) paste0('"', gsub('(["\\\\])', "\\\\\\1", s), '"')
  pm <- function(e) paste0('phantom("(")*', e, '*phantom(")")')
  pm_r <- function(e) paste0(e, '*phantom("()")')
  nn <- function(n) {
    v <- num(n)
    if (length(v) != 1L || is.na(v)) '~"pending"' else paste0("==", v)
  }
  lab_n <- function(prefix, n, suffix = NULL, italic_prefix = FALSE) {
    pre <- if (italic_prefix) paste0("italic(", q(prefix), ")") else q(prefix)
    pm(paste0(pre, "~italic(n)", nn(n), if (!is.null(suffix)) paste0("~", q(suffix))))
  }
  sess_line <- function(s, n, arm) {
    absent <- arm - num(n)
    lab_n(paste0("Session ", s, ":"), n,
          if (!is.na(absent) && absent > 0) paste0("(", absent, " absent)"))
  }

  boxes <- data.frame(xmin = numeric(), xmax = numeric(), top = numeric(), bot = numeric())
  texts <- data.frame(x = numeric(), y = numeric(), label = character(), hjust = numeric())
  segs  <- data.frame(x = numeric(), y = numeric(), xend = numeric(), yend = numeric(),
                      arrow = logical())
  heads <- data.frame(y = numeric(), label = character())
  rules <- numeric()
  add_box <- function(xmin, xmax, top, h, lines, hjust = 0.5) {
    boxes <<- rbind(boxes, data.frame(xmin = xmin, xmax = xmax, top = top, bot = top + h))
    x <- if (hjust == 0) xmin + inset else (xmin + xmax) / 2
    texts <<- rbind(texts, data.frame(x = x, y = top + pad + lh * (seq_along(lines) - 0.5),
                                      label = unname(lines), hjust = hjust, row.names = NULL))
  }
  add_seg <- function(x, y, xend, yend, arrow = FALSE)
    segs <<- rbind(segs, data.frame(x = x, y = y, xend = xend, yend = yend, arrow = arrow))
  y <- 0.02                        # the cursor runs down the page
  heading <- function(label, first = FALSE) {
    if (!first) y <<- y + 0.12
    heads <<- rbind(heads, data.frame(y = y, label = label))
    y <<- y + hs + 0.02
    rules <<- c(rules, y)
    y <<- y + 0.20
  }

  # Enrolment and group assignment.
  heading(headings[1], first = TRUE)
  h1 <- box_h(1)
  add_box(3.25 - 1.45, 3.25 + 1.45, y, h1, lab_n("Enrolled and assigned a mini-language,", enrolled))
  enrol_bot <- y + h1
  y <- enrol_bot + row_gap
  bar <- enrol_bot + row_gap / 2
  add_seg(3.25, enrol_bot, 3.25, bar)
  add_seg(arm_x[1], bar, arm_x[2], bar)
  for (i in 1:2) add_seg(arm_x[i], bar, arm_x[i], y, arrow = TRUE)
  for (i in 1:2) add_box(arm_x[i] - arm_w / 2, arm_x[i] + arm_w / 2, y, h1,
                         lab_n(paste0(arm_lab[i], ","), arm_n[i]))
  arm_bot <- y + h1
  y <- arm_bot

  # Attendance: one box per arm, one line per session, and no arrows between sessions.
  heading(headings[2])
  for (i in 1:2) add_seg(arm_x[i], arm_bot, arm_x[i], y, arrow = TRUE)
  ha <- box_h(nrow(attendance))
  att <- list(att_a, att_b)
  for (i in 1:2) add_box(arm_x[i] - arm_w / 2, arm_x[i] + arm_w / 2, y, ha,
                         mapply(sess_line, attendance$session, att[[i]], arm_n[i]), hjust = 0)
  y <- y + ha

  # Paper 1: the analysis samples of each arm, and beside each arm, on its outer side and
  # joined to it by a line, a "Not analysed" box counting the participants that arm
  # enrolled who are missing from each of its samples (enrolment minus the sample n).
  # When every sample lacks the same number it shows that one count; otherwise one line
  # per sample. The counts alone cannot say whether the same participants are missing
  # from every sample, so the box does not claim that they contribute to no sample.
  if (has_arms_sec) {
    heading(headings[3])
    short <- if ("short" %in% names(analysis_arms)) analysis_arms$short else
      sub("^Single-trial ", "", sub(" data$", "", analysis_arms$label))
    an <- list(an_a, an_b)
    lines_arm <- lapply(1:2, function(i) mapply(function(l, n) lab_n(paste0(l, ","), n),
                                                analysis_arms$label, an[[i]]))
    lines_na <- lapply(1:2, function(i) {
      sh <- arm_n[i] - an[[i]]
      if (all(is.na(sh) | sh <= 0)) return(NULL)
      if (length(unique(sh)) == 1L) return(c(pm(q("Not analysed")), pm(paste0("italic(n)", nn(sh[1])))))
      k <- which(!is.na(sh) & sh > 0)
      c(pm(q("Not analysed")), mapply(function(l, s) lab_n(paste0(l, ":"), s), short[k], sh[k]))
    })
    hr <- box_h(max(nrow(analysis_arms), lengths(lines_na)))
    for (i in 1:2) add_box(arm_x[i] - arm_w / 2, arm_x[i] + arm_w / 2, y, hr, lines_arm[[i]], hjust = 0)
    for (i in 1:2) if (length(lines_na[[i]])) {
      # 1.05 in wide, flush with the outer edge of the canvas; wider only when the text
      # needs it (the shortfalls differ between samples), with a warning if it would
      # then reach the arm's box.
      bw <- 1.05
      if (length(lines_na[[i]]) > 2L && requireNamespace("systemfonts", quietly = TRUE)) {
        plain <- c("Not analysed", paste0(short, ": n = ", arm_n[i] - an[[i]]))
        need <- max(systemfonts::string_width(plain, family = "sans", size = fs, res = 72)) / 72 + 0.1
        bw <- max(bw, need)
      }
      gap_in <- if (i == 1) (arm_x[1] - arm_w / 2) - bw else (W - bw) - (arm_x[2] + arm_w / 2)
      if (gap_in < 0.06) warning("les_flow(): the 'Not analysed' box of ", arm_lab[i],
                                 " reaches its arm's analysis box; shorten the `short` labels.")
      if (i == 1) add_box(edge, bw, y, hr, lines_na[[i]]) else add_box(W - bw, W - edge, y, hr, lines_na[[i]])
      # The line ties the box to its own arm, as an exclusion box is tied to its flow.
      arm_edge <- if (i == 1) arm_x[1] - arm_w / 2 else arm_x[2] + arm_w / 2
      add_seg(if (i == 1) bw else W - bw, y + hr / 2, arm_edge, y + hr / 2)
    }
    y <- y + hr
  }

  # Paper 2: the pooled chain. Each box is a subset of the one above it, so the boxes are
  # joined by arrows, and the participants removed at each step (the previous n minus
  # the current n) are counted in a box beside the arrow when there are any.
  if (has_pooled_sec) {
    heading(headings[3])
    cx <- 2.17; cw <- 3.1; xw <- 2.2
    ok <- !anyNA(pool_n) && all(diff(pool_n) <= 0)
    if (!ok) warning("les_flow(): the pooled chain is not non-increasing or has a missing ",
                     "count, so it is drawn without arrows or exclusion boxes.")
    drop <- c(NA_integer_, utils::head(pool_n, -1L) - utils::tail(pool_n, -1L))
    show_x <- ok & !is.na(drop) & drop > 0
    hb <- box_h(1)
    gap <- if (any(show_x)) hb + 2 * 0.09 else row_gap
    for (i in seq_along(pool_n)) {
      if (i > 1) {
        prev_bot <- y
        y <- y + gap
        if (ok) add_seg(cx, prev_bot, cx, y, arrow = TRUE)
        if (show_x[i]) {
          mid <- prev_bot + gap / 2
          add_seg(cx, mid, W - xw, mid)
          add_box(W - xw, W - edge, mid - hb / 2, hb,
                  lab_n(paste0(analysis_pooled$dropped[i], ","), drop[i]))
        }
      }
      add_box(cx - cw / 2, cx + cw / 2, y, hb, lab_n(paste0(analysis_pooled$label[i], ","), pool_n[i]))
      y <- y + hb
    }
    if (!is.null(pooled_footnote)) {
      y <- y + 0.05
      texts <- rbind(texts, data.frame(x = cx, y = y + lh / 2,
                                       label = lab_n(pooled_footnote[1], pooled_footnote[2],
                                                     italic_prefix = TRUE),
                                       hjust = 0.5))
      y <- y + lh
    }
  }

  H <- y + 0.03
  # Outside a chunk opts_current returns knitr's default of 7 in, so read it only while
  # knitr is running.
  fh <- if (isTRUE(getOption("knitr.in.progress"))) knitr::opts_current$get("fig.height") else NULL
  if (is.numeric(fh) && fh + 1e-6 < H)
    warning(sprintf("les_flow(): the diagram needs %.2f in but fig-height is %.2f in, so it is compressed vertically.", H, fh))
  # One data unit per inch in both directions: a taller canvas extends below the diagram.
  ylim <- c(if (is.numeric(fh) && fh > H) H - fh else 0, H)

  # The cursor ran down the page; the plot's y axis runs up it.
  segs$y <- H - segs$y; segs$yend <- H - segs$yend
  boxes$ymin <- H - boxes$bot; boxes$ymax <- H - boxes$top
  texts$y <- H - texts$y
  heads$y <- H - heads$y
  heads$label <- pm_r(paste0("bold(", q(heads$label), ")"))
  ink <- "grey20"
  xy <- ggplot2::aes(x = x, y = y, xend = xend, yend = yend)
  lines_  <- segs[!segs$arrow, , drop = FALSE]
  arrows_ <- segs[segs$arrow, , drop = FALSE]

  p <- ggplot2::ggplot() +
    ggplot2::annotate("segment", x = 0, xend = W, y = H - rules, yend = H - rules,
                      colour = "grey75", linewidth = 0.3)
  if (nrow(lines_))
    p <- p + ggplot2::geom_segment(data = lines_, mapping = xy, colour = ink, linewidth = 0.35,
                                   lineend = "butt")
  if (nrow(arrows_))
    p <- p + ggplot2::geom_segment(data = arrows_, mapping = xy, colour = ink, linewidth = 0.35,
                                   linejoin = "mitre", arrow.fill = ink,
                                   arrow = ggplot2::arrow(length = ggplot2::unit(0.055, "in"),
                                                          type = "closed"))
  p <- p +
    ggplot2::geom_rect(data = boxes, ggplot2::aes(xmin = xmin, xmax = xmax, ymin = ymin, ymax = ymax),
                       fill = "white", colour = ink, linewidth = 0.35) +
    ggplot2::geom_text(data = texts, ggplot2::aes(x = x, y = y, label = label, hjust = hjust),
                       parse = TRUE, vjust = 0.5, size = fs / ggplot2::.pt, colour = "black") +
    ggplot2::geom_text(data = heads, ggplot2::aes(x = 0, y = y, label = label), parse = TRUE,
                       hjust = 0, vjust = 1, size = base_size / ggplot2::.pt, colour = "black") +
    ggplot2::coord_cartesian(xlim = c(0, W), ylim = ylim, expand = FALSE, clip = "off") +
    ggplot2::theme_void(base_size = base_size) +
    ggplot2::theme(plot.margin = ggplot2::margin(0, 0, 0, 0))
  attr(p, "les_flow_height") <- H
  p
}
