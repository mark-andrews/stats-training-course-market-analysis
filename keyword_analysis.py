from transformers import pipeline
import pandas

keywords = [line.strip() for line in open("ncrm_keywords.txt")]
labels = pandas.read_csv("statistics_topics.csv").subtopic.values

clf = pipeline("zero-shot-classification", model="facebook/bart-large-mnli") #device_map="auto" for GPU

def best_label(txt):
    out = clf(txt, candidate_labels=labels, multi_label=False)
    return out["labels"][:3], out["scores"][:3]

results = [best_label(k) for k in keywords] 
