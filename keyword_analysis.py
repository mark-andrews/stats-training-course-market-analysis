from transformers import pipeline
import pandas

keywords = [line.strip() for line in open("data/example_keywords.txt")]
labels = pandas.read_csv("data/statistics_topics.csv").subtopic.values

clf = pipeline("zero-shot-classification", model="facebook/bart-large-mnli") #device_map="auto" for GPU

def best_label(txt):
    out = clf(txt, candidate_labels=labels, multi_label=False)
    return out["labels"][:3], out["scores"][:3]

results = [best_label(k) for k in keywords] 

clf = pipeline("zero-shot-classification",
               model="facebook/bart-large-mnli",
               device=0,                 # 0 = first GPU
               batch_size=64)            # try 32–64, watch GPU RAM

results = clf(
    keywords,                       # <-- list[str]
    candidate_labels=labels,
    hypothesis_template="This text is about {}.",
    multi_label=False,
    batch_size=64                   # batches the premises on-GPU
)

groups = [
    ["logistic regression", "odds ratio", "binary outcome"],
    ["longitudinal data analysis", "mixed effects", "time-varying"],
    ["cost effectiveness", "quality-adjusted life years", "incremental cost"],
]

def group_premise(kw_list):
    # join them into a short, human-ish sentence
    return "; ".join(kw_list) + "."

group_texts = [group_premise(kws) for kws in groups]

out = clf(
    group_texts,                 # list[str]  (one per group)
    candidate_labels=labels,
    multi_label=False,           # get the single best label
    batch_size=len(groups)       # they can all be evaluated together
)

best_labels = [r["labels"][0] for r in out]

from collections import defaultdict
import numpy as np

def label_scores(text):
    """Returns dict: label → entail_prob (0-1)."""
    out = clf(text, candidate_labels=labels, multi_label=True)
    return dict(zip(out["labels"], out["scores"]))

def classify_group(kws):
    # accumulate scores
    agg = defaultdict(float)
    for kw in kws:
        for lab, score in label_scores(kw).items():
            agg[lab] += score            # sum or use +=
    # pick the label with the highest total / average
    best = max(agg.items(), key=lambda x: x[1])[0]
    return best

best_labels = [classify_group(kws) for kws in groups]
