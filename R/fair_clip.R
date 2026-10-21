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
