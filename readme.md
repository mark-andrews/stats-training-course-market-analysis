# Code etc for analysis of the UK statistics training market

Currently, this code is just for the retrieval of all posts to the ALLSTAT mailing list.

## Installation

Currently, the code is all Python based. 

It is recommended to use a virtual environment, which can be created as follows:
```bash
# run this command in a Linux, MacOS, or DOS terminal
python -m venv .venv
```
This will create a hidden virtual environment sub-directory named `.venv`.
This virtual environment can be activated as follows:
```bash
source .venv/bin/activate  # Linux or MacOS
```
```bat
:: Windows/DOS
.venv\Scripts\activate 
```

The required packages can be installed with
```bash
pip install -r include/requirements.txt
```

One minor annoyance is the installation of the Gecko driver for using the Selenium Firefox webdriver.
This can be installed from within a Python shell as follows:
```python
from webdriver_manager.firefox import GeckoDriverManager
path = GeckoDriverManager().install()
```
Where the last line also returns the path to `geckodriver`.
Currently, I have these paths, one for Windows and one for Linux, written into the [`.env`](.env) file which is the read by the Python script that runs the webdriver.

## Get list of links to all posts to ALLSTAT

The following Python script will write a json file, named `posts_19_feb.json`, that contains a list of URLs to every post to ALLSTAT since its inception in 1998.
For each post, it gives its subject line and the URL to the content of the post.
```bash
python allstat.py get_links_to_all_posts --output_file posts_19_feb.json --verbose
```

## Get posts about training courses

The following Python script will get the contents of all posts to ALLSTAT with the term `training*` or `course`, case insensitive, in the title.
While this will not necessarily retrieve all posts to ALLSTAT about training courses, and will retrieve some posts that are not about training courses, it will get many of these posts about training courses and hopefully not too many irrelevant posts and so is hopefully a useful starting point.
The contents of the posts and their titles, URLs, and the month of the post are written to a json file.
This script uses the list of links obtained from the above `get_links_to_all_posts`.
```bash
python allstat.py get_training_course_posts --posts_list posts_19_feb.json --output_file training_course_posts.json --verbose
```

## Analysing posts using an LLM

The script [`llm_analysis.R`](llm_analysis.R) provides code for the analysis of posts using an LLM such as ChatGPT or Llama.
More information and guidance can be found in [this guide](https://mark-andrews.github.io/stats-training-course-market-analysis/llm_analysis_howto.html).