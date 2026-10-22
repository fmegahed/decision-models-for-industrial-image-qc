# Size, work and GPU memory of CLIP ViT-L/14, for the compute notes.
# Loaded from R with reticulate::source_python("python/model_compute.py").
import clip
import torch
from torch.utils.flop_counter import FlopCounterMode

def clip_compute(name, prompts):
    # Counts on the CPU (float32): parameters, and the FLOPs of the matrix
    # products of one image encoding and of one encoding of the prompts. The
    # FLOPs do not depend on the image or the text: CLIP resizes each image to
    # its input size, and the text encoder always reads 77 positions.
    model, _ = clip.load(name, device='cpu')
    model.eval()
    size = model.visual.input_resolution
    image = torch.zeros(1, 3, size, size)
    with torch.no_grad():
        with FlopCounterMode(display=False) as counter:
            model.encode_image(image)
        image_flops = float(counter.get_total_flops())  # float: R integers stop at 2^31
        with FlopCounterMode(display=False) as counter:
            model.encode_text(clip.tokenize(list(prompts)))
        text_flops = float(counter.get_total_flops())
    out = dict(parameters=sum(p.numel() for p in model.parameters()),
               image_parameters=sum(p.numel() for p in model.visual.parameters()),
               embedding_dim=model.visual.output_dim, input_size=size,
               image_flops=image_flops, text_flops=text_flops,
               dtype_as_run='', weights_gb=float('nan'), peak_gb_one_image=float('nan'))
    del model
    # GPU memory as in clip_functions.py (clip.load on the GPU keeps float16):
    # the weights, and the peak while one image is encoded.
    if torch.cuda.is_available():
        torch.cuda.empty_cache()
        torch.cuda.reset_peak_memory_stats()
        model, _ = clip.load(name, device='cuda')
        model.eval()
        # The weight matrices; a few small tensors stay float32.
        out['dtype_as_run'] = str(model.dtype).replace('torch.', '')
        out['weights_gb'] = torch.cuda.memory_allocated() / 1e9
        with torch.no_grad():
            model.encode_image(image.to('cuda'))
        torch.cuda.synchronize()
        out['peak_gb_one_image'] = torch.cuda.max_memory_allocated() / 1e9
        del model
        torch.cuda.empty_cache()
    return out
