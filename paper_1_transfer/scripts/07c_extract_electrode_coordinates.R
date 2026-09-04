# =============================================================================
# paper_1_transfer/scripts/07c_extract_electrode_coordinates.R
# Scalp coordinates of the recording montage, read from the study's OWN headers
# -----------------------------------------------------------------------------
# The interpolated scalp-topography figure needs a two-dimensional position for each
# recorded sensor. Those positions are not a matter of convention to be looked up: the
# study recorded with a specific Brain Products cap, and every BrainVision header
# (data/raw data/EEG/Session*/Raw/*.vhdr) carries the montage it was recorded with, in
# a [Coordinates] section, together with the cap that generated it:
#
#     ; Electrode Position File: C:\Vision\Workfiles\CACS-32_REF.bvef
#
# We therefore read the montage straight from those headers rather than from a generic
# electrode table. This is both more accurate and more reproducible: the coordinates
# come from the study's own read-only data, no external package is involved, and the
# manuscript reads the small CSV written here rather than depending on anything at
# render time.
#
# WHY NOT A STANDARD 10-20 TABLE?  An earlier version of this script took positions
# from `eegkit::eegcoord`. Checked against the recorded montage, that generic table is
# measurably wrong for this cap: its 2-D projection is not azimuthal-equidistant, so
# electrodes that are anatomically equidistant from the vertex (T7, T8, Oz, Fp1, Fp2,
# F7, F8, P7, P8, O1, O2 -- all 90 degrees from Cz) land at radii spanning 0.876 to
# 1.115 instead of a common radius, and it is not exactly left-right symmetric. The
# worst sensors sit ~0.17 head-radii from their true position (FT9/FT10), and the
# distortion runs along the lateral-vs-posterior axis -- precisely the axis the P600
# topography claim is about. The recorded montage has zero radial spread and exact
# mirror symmetry, as a manufactured cap must.
#
# COORDINATE CONVENTION.  BrainVision stores (radius, theta, phi) in degrees, where
# |theta| is the polar angle from the vertex (Cz is theta = 0) and phi is the azimuth;
# theta's sign distinguishes the hemispheres. The standard planar projection places a
# sensor at radius |theta|/90 (so the equator, |theta| = 90, is the unit circle) and
# azimuth phi for theta >= 0, or 180 + phi for theta < 0. Verified against the montage:
# Cz -> (0, 0); T7/T8 -> (-+1, 0); Fz/Pz/Oz -> x = 0 exactly; Fp1 -> (-0.309, 0.951),
# the textbook 10-20 position. Sensors below the equator (FT9/FT10, TP9/TP10 at
# |theta| = 113) correctly project outside the unit circle.
#
# Output: paper_1_transfer/results/_electrode_coordinates.csv
#   columns: electrode, brain_region, macroregion, hemisphere, caudality, theta, phi, x, y
#            (x > 0 = right, y > 0 = anterior; unit circle = the equator)
#
# USAGE (local, once):  Rscript paper_1_transfer/scripts/07c_extract_electrode_coordinates.R
# The output CSV is committed, so this only needs re-running if the montage changes.
# =============================================================================

suppressPackageStartupMessages({
  source(here::here("_shared", "R", "00_paths.R"))
})

# --- the electrode -> brain_region map used by the study's importer -------------
# (data/R_functions/import_trialbytrial_EEG_data.R; reproduced here because data/ is
# read-only and the map is defined inline there rather than exported.)
montage <- list(
  "left anterior"     = c("Fp1", "F3", "F7", "FT9", "FC5"),
  "midline anterior"  = c("Fz", "FC1", "FC2"),
  "right anterior"    = c("Fp2", "F4", "F8", "FT10", "FC6"),
  "left medial"       = c("T7", "C3", "CP5"),
  "midline medial"    = c("Cz", "CP1", "CP2"),
  "right medial"      = c("T8", "C4", "CP6"),
  "left posterior"    = c("P7", "P3", "O1"),
  "midline posterior" = c("Pz", "Oz"),
  "right posterior"   = c("P8", "P4", "O2")
)

# --- parse one BrainVision header ----------------------------------------------
.vhdr_section <- function(L, tag) {
  i <- grep(paste0("^[[]", tag, "[]]"), L)
  if (!length(i)) return(character(0))
  j <- grep("^[[]", L)
  nx <- j[j > i[1]][1]
  if (is.na(nx)) nx <- length(L) + 1L
  L[(i[1] + 1):(nx - 1)]
}

.parse_vhdr_montage <- function(f) {
  L  <- readLines(f, warn = FALSE)
  co <- grep("^Ch[0-9]+=", .vhdr_section(L, "Coordinates"), value = TRUE)
  if (!length(co)) return(NULL)                      # header without a montage
  ci <- grep("^Ch[0-9]+=", .vhdr_section(L, "Channel Infos"), value = TRUE)
  if (!length(ci)) return(NULL)
  nm <- sub("^Ch[0-9]+=([^,]*),.*$", "\\1", ci)
  names(nm) <- sub("=.*", "", ci)
  vals <- strsplit(sub("^Ch[0-9]+=", "", co), ",")
  if (!all(lengths(vals) >= 3)) return(NULL)
  cp <- t(vapply(vals, function(v) as.numeric(v[1:3]), numeric(3)))
  out <- data.frame(electrode = unname(nm[sub("=.*", "", co)]),
                    radius = cp[, 1], theta = cp[, 2], phi = cp[, 3],
                    stringsAsFactors = FALSE)
  # radius 0 marks the non-EEG auxiliary channels (the accelerometer x_dir/y_dir/z_dir)
  out <- out[!is.na(out$electrode) & out$radius > 0, , drop = FALSE]
  out[order(out$electrode), , drop = FALSE]
}

vhdr_files <- list.files(data_path("raw data", "EEG"), pattern = "[.]vhdr$",
                         recursive = TRUE, full.names = TRUE)
if (!length(vhdr_files)) stop("No BrainVision headers found under data/raw data/EEG.")

parsed <- Filter(Negate(is.null), lapply(vhdr_files, .parse_vhdr_montage))
if (!length(parsed)) stop("No BrainVision header carried a [Coordinates] section.")

# --- BrainVision spherical -> planar projection ---------------------------------
.project <- function(theta, phi) {
  rr <- abs(theta) / 90                                   # equator -> 1
  az <- ifelse(theta >= 0, phi, 180 + phi) * pi / 180     # hemisphere-signed azimuth
  cbind(x = rr * cos(az), y = rr * sin(az))               # +x right, +y anterior
}

# --- every header that names an electrode must place it in the same spot ---------
# Headers legitimately differ in which channels they CONTAIN -- the Raw headers carry
# the 32 recorded sensors, the Export headers additionally carry FCz (the online
# reference, restored when the data were re-referenced to linked mastoids), and the
# resting-state files differ again -- so we check position per electrode rather than
# requiring one common channel set.
#
# A sub-degree tolerance is allowed because the cap definition was evidently saved from
# two slightly different versions of the position file: FC5 is theta = -69 everywhere
# but phi = -22 in most headers and -21 in a minority, which moves it by ~0.013
# head-radii. That is negligible for a topography (and an order of magnitude below the
# error of the generic table this script used to rely on), so we take the modal
# position and report the spread rather than failing.
all_m <- do.call(rbind, parsed)
key <- paste(all_m$theta, all_m$phi)
elecs <- sort(unique(all_m$electrode))
POS_TOL <- 0.05   # head-radii; ~3 degrees of azimuth at the equator

pos <- do.call(rbind, lapply(elecs, function(e) {
  s  <- all_m[all_m$electrode == e, , drop = FALSE]
  vr <- unique(s[, c("theta", "phi")])
  P  <- .project(vr$theta, vr$phi)
  spread <- if (nrow(P) > 1) max(stats::dist(P)) else 0
  tb <- sort(table(paste(s$theta, s$phi)), decreasing = TRUE)
  md <- vr[paste(vr$theta, vr$phi) == names(tb)[1], , drop = FALSE][1, ]
  data.frame(electrode = e, theta = md$theta, phi = md$phi,
             n_variants = nrow(vr), spread = spread, stringsAsFactors = FALSE)
}))

bad <- pos[pos$spread > POS_TOL, , drop = FALSE]
if (nrow(bad))
  stop("BrainVision headers disagree substantively about: ",
       paste(sprintf("%s (%.3f head-radii)", bad$electrode, bad$spread), collapse = ", "))

sets <- length(unique(vapply(parsed, function(d)
  paste(sort(d$electrode), collapse = "|"), character(1))))
message(sprintf(paste("[coords] %d of %d headers carry a montage (%d without);",
                      "%d distinct channel sets"),
                length(parsed), length(vhdr_files),
                length(vhdr_files) - length(parsed), sets))
if (any(pos$n_variants > 1)) {
  v <- pos[pos$n_variants > 1, ]
  message(sprintf(paste("[coords] %s vary between cap-file versions (max %.4f head-radii,",
                        "below the %.2f tolerance); modal position used"),
                  paste(v$electrode, collapse = ", "), max(v$spread), POS_TOL))
}

m <- pos
m <- cbind(m, .project(m$theta, m$phi))

# --- attach the study's regional labels, keep only the mapped sensors -----------
elec <- data.frame(
  electrode    = unlist(montage, use.names = FALSE),
  brain_region = rep(names(montage), lengths(montage)),
  stringsAsFactors = FALSE
)
missing <- setdiff(elec$electrode, m$electrode)
if (length(missing))
  stop("Electrodes in the region map are absent from the recorded montage: ",
       paste(missing, collapse = ", "))

elec <- merge(elec, m[, c("electrode", "theta", "phi", "x", "y")], by = "electrode")
elec$macroregion <- ifelse(grepl("midline", elec$brain_region), "midline", "lateral")
elec$hemisphere  <- ifelse(grepl("^left", elec$brain_region), "left",
                    ifelse(grepl("^right", elec$brain_region), "right", "midline"))
elec$caudality   <- sub("^(left|right|midline) ", "", elec$brain_region)
elec <- elec[, c("electrode", "brain_region", "macroregion", "hemisphere",
                 "caudality", "theta", "phi", "x", "y")]
elec <- elec[order(elec$brain_region, elec$electrode), ]

# --- geometry checks against the montage's known anatomy ------------------------
# NOTE the study's "midline" brain_region is a coarse CLUSTER label, not a claim that
# every member lies on the midline: only Fz, Cz, Pz and Oz are true midline sensors,
# whereas FC1/CP1 and FC2/CP2 are paraxial, sitting ~0.24 head-radii either side of it.
# They are exact mirror pairs, so each midline cluster stays centred on the midline.
gx <- function(e) elec$x[elec$electrode == e]
gy <- function(e) elec$y[elec$electrode == e]
stopifnot(
  nrow(elec) == 30L,
  # Cz is the vertex, i.e. the projection's origin.
  isTRUE(all.equal(c(gx("Cz"), gy("Cz")), c(0, 0))),
  # True midline sensors lie exactly on x = 0.
  all(abs(vapply(c("Fz", "Cz", "Pz", "Oz"), gx, numeric(1))) < 1e-9),
  # The paraxial members of the "midline" clusters fall either side of it, and are
  # exact mirror pairs, so the cluster mean is midline-centred.
  gx("FC1") < 0, gx("CP1") < 0, gx("FC2") > 0, gx("CP2") > 0,
  isTRUE(all.equal(gx("FC1"), -gx("FC2"))),
  isTRUE(all.equal(gx("CP1"), -gx("CP2"))),
  # Lateral clusters fall on the correct side; anterior sites sit in front.
  all(elec$x[elec$hemisphere == "left"]  < 0),
  all(elec$x[elec$hemisphere == "right"] > 0),
  gy("Fz") > gy("Pz"), gy("Fp1") > gy("O1"),
  # Sensors 90 degrees from the vertex share the unit radius (the projection is
  # azimuthal-equidistant); this is what the generic table got wrong.
  {
    eq <- c("T7", "T8", "Oz", "Fp1", "Fp2", "F7", "F8", "P7", "P8", "O1", "O2")
    rad <- sqrt(vapply(eq, gx, numeric(1))^2 + vapply(eq, gy, numeric(1))^2)
    max(abs(rad - 1)) < 1e-9
  }
)

out <- paper1_results("_electrode_coordinates.csv")
utils::write.csv(elec, out, row.names = FALSE)
message(sprintf("[coords] wrote %s (%d electrodes; x %.3f..%.3f, y %.3f..%.3f)",
                basename(out), nrow(elec), min(elec$x), max(elec$x),
                min(elec$y), max(elec$y)))
