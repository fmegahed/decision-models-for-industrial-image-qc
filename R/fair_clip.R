# Leave-one-out CLIP scores for the pan baseline calibration (design 4.4).
# features: one row per image (unit length); labels: "nominal" or "defective";
# md5: file hash of each image. An image is never compared with itself or with
# a copy of itself. The score is the one of clip_few_scores(): the softmax of
# the two maximum cosine similarities, as a plain logistic of their difference.
clip_loo_probability <- function(features, labels, md5) {
  similarity <- features %*% t(features)
  similarity[outer(md5, md5, "==")] <- -Inf
  normal_max <- apply(similarity[, labels == "nominal", drop = FALSE], 1, max)
  defective_max <- apply(similarity[, labels == "defective", drop = FALSE], 1, max)
  stats::plogis(defective_max - normal_max)
}

# The v0.0.1 zero-shot prompts, copied from scripts/run_clip.R (nominal first).
clip_prompts <- list(
  pan_images = c(
    "A metallic pan free of black scuff marks",
    "A metallic pan with a simulated scuff mark drawn by a black marker"
  ),
  extrusion = c(
    "An image of a normal extrusion profile from an additive manufacturing process",
    "An image of an over-extruded or under-extruded profile from an additive manufacturing process"
  ),
  textiles = c(
    "An image of a textile material with consistent weave patterns, showing no visible defects or irregularities.",
    "A woven textile, featuring a visible tear, defect, or a disruption in the material's weave structure."
  ),
  pipe_staple = c(
    "A close-up of an automotive assembly process showing a flexible cable secured by a metallic rectangular clamp with rounded edges.",
    "A close-up of an automotive assembly process focusing on a flexible cable, where the clamp that typically secures the pipe during assembly is notably absent."
  ),
  microstructure = c(
    "A microstructure image showing a uniform microstructure.",
    "A microstructure image showing a non-uniform microstructure with banding, bimodality, or single-crystal features."
  )
)
