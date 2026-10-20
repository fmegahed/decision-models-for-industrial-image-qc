# CLIP ViT-L/14 functions from clip_image_inspection.qmd (Y: project), unchanged.
# Loaded from R with reticulate::source_python("clip_functions.py").
import clip
import torch
from PIL import Image
import numpy as np

clip_device = 'cuda' if torch.cuda.is_available() else 'cpu'
clip_model, clip_preprocess = clip.load('ViT-L/14', device=clip_device)
clip_model.eval()

def clip_encode_images(paths):
    features = []
    with torch.no_grad():
        for path in paths:
            with Image.open(path) as img:
                tensor = clip_preprocess(img.convert('RGB')).unsqueeze(0).to(clip_device)
            feature = clip_model.encode_image(tensor).float()
            feature = feature / feature.norm(dim=-1, keepdim=True)
            features.append(feature.squeeze(0).cpu().numpy())
    return np.stack(features)

def clip_zero_scores(image_features, labels):
    with torch.no_grad():
        tokens = clip.tokenize(labels).to(clip_device)
        text = clip_model.encode_text(tokens).float()
        text = text / text.norm(dim=-1, keepdim=True)
        text = text.cpu().numpy()
    logits = 100.0 * (image_features @ text.T)
    logits = logits - logits.max(axis=1, keepdims=True)
    scores = np.exp(logits)
    return scores / scores.sum(axis=1, keepdims=True)

def clip_few_scores(image_features, normal_features, defective_features):
    # As in the original notebook: softmax of the two raw maximum cosine similarities.
    normal_sim = image_features @ normal_features.T
    defective_sim = image_features @ defective_features.T
    logits = np.stack((normal_sim.max(axis=1), defective_sim.max(axis=1)), axis=1)
    logits = logits - logits.max(axis=1, keepdims=True)
    scores = np.exp(logits)
    return scores / scores.sum(axis=1, keepdims=True)
