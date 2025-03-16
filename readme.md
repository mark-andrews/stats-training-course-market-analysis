# Code for analysis of the UK statistics training market

Currently, this repository primarily contains the following:

1. Python code for retrieving statistics training course descriptions from three archives:
    1. The [ALLSTAT](https://www.jiscmail.ac.uk/cgi-bin/webadmin?A0=allstat) mailing list archives
    2. The [NCRM](https://www.ncrm.ac.uk/)'s [training courses and events](https://www.ncrm.ac.uk/training/) database
    3. The [TeSS (Training eSupport System)](https://tess.elixir-europe.org/) database
2. JSON files with the retrieved data from these archives
3. R code for LLM based analysis of the course descriptions

## Python code installation

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

## Retrieve course descriptions from archives

There are three Python scripts for retrieving the course descriptions, one for each of the three archives:

### ALLSTAT

The following Python script will write a bz2 compressed json file that contains a list of URLs to every post to [ALLSTAT](https://www.jiscmail.ac.uk/cgi-bin/webadmin?A0=allstat) since its inception in 1998.
For each post, it gives its subject line and the URL to the content of the post.
```bash
python allstat.py get_links_to_all_posts --outfile data/allstat_course_list.json.bz2 --verbose
```

The following Python script will use the list of courses obtained in the previous command to get the contents of all posts to ALLSTAT that contain the term `training*` or `course`, case insensitive, in the title.
While this will not necessarily retrieve all posts to ALLSTAT about training courses, and will retrieve some posts that are not about training courses, it will get many of these posts about training courses and hopefully not too many irrelevant posts and so is hopefully a useful starting point.
The contents of the posts and their titles, URLs, and the month of the post are written to a bz2 compressed json file.
```bash
python allstat.py get_training_course_posts --posts_list data/allstat_course_list.json.bz2 --outfile data/allstat_training_course_posts.json.bz2 --verbose
```

### NCRM 

The following Python script will get the html page that contains the list of all the events in the [Research methods training courses and events](https://www.ncrm.ac.uk/training/) database, and write this html page to a bz2 compressed file:
```bash
python ncrm.py get_course_listing_page --outfile data/ncrm_course_listing_page.html.bz2 
```

The following Python script will get the details of each course om the list obtained in the previous step:
```bash
python ncrm.py extract_events --course_listing_page data/ncrm_course_listing_page.html.bz2 --outfile data/ncrm_events.json.bz2
```

### TESS

The following script writes a json file containing the list of all workshops or courses in the [TeSS (Training eSupport System)](https://tess.elixir-europe.org/) database:
```bash 
python tess.py get_course_list --outfile data/tess_course_list.json.bz2
```

For each training course in the list created by the previous command, the following will get the course's details, such as its description, keywords, etc:
```bash
python tess.py get_course_details --course_list data/tess_course_list.json.bz2 --outfile data/tess_courses.json.bz2 --backup data/tess_courses__backup.json
```

## Analysing posts using an LLM

The script [`llm_analysis.R`](llm_analysis.R) provides code for the analysis of posts using an LLM such as ChatGPT or Llama.
More information and guidance can be found in [this guide](https://mark-andrews.github.io/stats-training-course-market-analysis/llm_analysis_howto.html).

