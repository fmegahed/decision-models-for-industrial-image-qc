# Size, work and GPU memory of the two local models, for the compute notes of
# the analysis document and the paper (no API call, no cost).
#
# RETICULATE_PYTHON=<env>/python.exe Rscript scripts/model_compute.R
#   CLIP ViT-L/14 (python/model_compute.py): the parameters, the FLOPs of one
#   image encoding and of one encoding of the two zero-shot prompts (PyTorch
#   FlopCounterMode), and on the GPU the memory of the weights and the peak
#   while one image is encoded.
#   Clef-Flash: the parameters and their type from the Hugging Face API, at the
#   revision of the model on the day of the run. The model is dense when its
#   config.json has no expert setting. The GPU memory of the SGLang server
#   (24.8 GB) is the measurement of experiment_log.md (2026-10-20); SGLang
#   reserves memory for its cache, so it is not a minimum.
# Writes model_compute.csv to FAIR_TIMING_DIR (default results/fair/timing).
# A second run stops: delete model_compute.csv first. Run the script when no
# other process uses the GPU.

source("R/fair_runner.R")
reticulate::source_python("python/model_compute.py")

out_file <- file.path(fair_timing_dir(), "model_compute.csv")
if (file.exists(out_file)) stop("The file exists: ", out_file, ". Delete it first.")
retrieved <- format(Sys.time(), "%Y-%m-%dT%H:%MZ", tz = "UTC")

# The FLOPs do not depend on the text of the prompts (77 positions).
clip <- clip_compute("ViT-L/14", c("a photo of a nominal part", "a photo of a defective part"))

clef_api <- "https://huggingface.co/api/models/Cloudflare/clef-flash"
clef <- httr2::request(clef_api) |> httr2::req_perform() |> httr2::resp_body_json()
config <- httr2::request(stringr::str_c("https://huggingface.co/Cloudflare/clef-flash/resolve/",
                                        clef$sha, "/config.json")) |>
  httr2::req_perform() |>
  httr2::resp_body_json(check_type = FALSE) # served as text/plain
clef_type <- names(clef$safetensors$parameters)
stopifnot(length(clef_type) == 1, clef_type == "BF16")

compute <- tibble::tibble(
  model = c("clip", "clef"),
  name = c("ViT-L/14", "Cloudflare/clef-flash"),
  parameters = c(clip$parameters, clef$safetensors$total),
  image_parameters = c(clip$image_parameters, NA),
  dense = c(TRUE, !any(stringr::str_detect(names(unlist(config)), "expert"))),
  dtype_as_run = c(clip$dtype_as_run, "bfloat16"),
  bytes_per_parameter = 2,
  weights_gb = c(clip$weights_gb, clef$safetensors$total * 2 / 1e9),
  gpu_gb_measured = c(clip$peak_gb_one_image, 24.8),
  gpu_gb_note = c("peak while one image is encoded (torch.cuda.max_memory_allocated)",
                  "SGLang server with its cache reserve (experiment_log.md, 2026-10-20)"),
  embedding_dim = c(clip$embedding_dim, NA),
  input_size = c(clip$input_size, NA),
  image_flops = c(clip$image_flops, NA),
  text_flops = c(clip$text_flops, NA),
  hardware = gpu_name(),
  source = c("OpenAI CLIP package (clip.load), commit d05afc4", stringr::str_c(clef_api, "@", clef$sha)),
  retrieved_utc = retrieved
)
dir.create(dirname(out_file), recursive = TRUE, showWarnings = FALSE)
readr::write_csv(compute, out_file)
print(compute, width = Inf)
