I am going to give you a text that is a post to a mailing list.

The title of the post is the first line, indicated by the # symbol.

Is this post advertising a statistics or data science training course? For present purposes, if it is a training course that is clearly related to statistical or quantitative data analysis, then it counts as a statistics or data science training course, regardless of whether it also covers other topics, such as bioinformatics for example.

If it is about a training course, answer the following questions:

  - In one line, what is this course about?
  - In one word or term, what is the course about? For example, "causal inference", "general linear models", "Bayesian methods".
  - What are the major statistical or data science topics that are covered in the course? For example, generalized linear models, Bayesian data analysis, etc. Here, we are interested in *major* topics rather minor topics or general and non-specific topics like "data analysis". Provide this list of major topics list of keywords. 
  - Which academic or scientific fields, e.g., biology, economics, psychology, is the course primarily aimed at? Provide a list of academic or research fields as an answer.
  - What level --- beginner, intermediate, advanced --- is the course aimed at? 
  - What statistics software package or statistics programming language are used, e.g. Stata, R, Python? We are interested here in just the major statistics software or languages only rather than software that is not specifically for statistics or data analysis.
  - Is the course online or in person?
  - What is the duration of the course? For example, is it a half-day, one-day, two-day, five-day etc course?
  - Which institution or organization is providing the course?

If the post is *not* about a training course, or if you are unsure, the answers to these questions should all be left empty.

Return your answer as a json string with these keys:

  - a key named "description" that is a string providing a brief one-sentence description of the course.
  - a key named "topic" that is a single word or term that describes the course.
  - a key named "keywords" that is a list of keywords that describe the major topics.
  - a key named "field" with a list of academic fields.
  - a key named "level" that is a string like "beginner" or "advanced" etc.
  - a key named "software" that is the major statistics software used, which may be a list too.
  - a key named "delivery" with a string value like "online", "in person", "hybrid" indicating the course is delivered online or in person etc.
  - a key named "duration" with a string giving the course's duration.
  - a key named "provider" for the name of the course provider with a string value like for example "Imperial College London"

For example, 

```
{
  "description": "Generalized linear models for ecologists",
  "topic": "Generalized linear models",
  "keywords": ["logistic regression", "Poisson regression"],
  "field": ["biology", "ecology"],
  "level": "intermediate",
  "software": "R",
  "delivery": "online",
  "provider": "Imperial College London"
}

Do not return the json string as fenced markdown code. Just return the json string itself.
