"""
Utilities from webscraping all posts to the ALLSTAT mailing list

It seems necessary, and probably does no harm even if it is not necessary, to render
all the webpages with Selenium rather than using the raw html pages.

This module can be used as a command line script.


"""

import platform
from pathlib import Path
import bz2
import os
import ipdb
import sys
from dotenv import load_dotenv  # for reading .env
from bs4 import BeautifulSoup
from selenium import webdriver
from selenium.common.exceptions import TimeoutException
from selenium.webdriver.common.by import By
from selenium.webdriver.firefox.options import Options
from selenium.webdriver.firefox.service import Service
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.support.ui import WebDriverWait


# You need to install the GeckoDriverManager
# You can install it with
# from webdriver_manager.firefox import GeckoDriverManager
# GeckoDriverManager().install()
# and save the output, which is the executable path,
# You just need to install this once.
# So this command needs to be run once, probably as part of a
# installation script, e.g. install.sh
# We then need the executable path and I think the best way to do
# that is to write the path as an environment variable, see e.g
# .env

# Get the GECKO_PATH
load_dotenv()  # Load environment variables from .env file
system = platform.system()
if system == "Windows":
    home = Path(os.environ.get("USERPROFILE"))
    GECKO_DRIVER_PATH = home / Path(os.getenv("GECKO_PATH_WINDOWS"))
elif system == "Linux":
    home = Path(os.environ.get("HOME"))
    GECKO_DRIVER_PATH = home / Path(os.getenv("GECKO_PATH_LINUX"))
elif system == "Darwin":  # macOS
    home = Path(os.environ.get("HOME"))
    GECKO_DRIVER_PATH = home / Path(os.getenv("GECKO_PATH_MAC"))
else:
    raise OSError("Unsupported operating system")


def render(url, k=10):
    """
    Render a webpage with Firefox and return the resulting HTML string.
    Uses an explicit wait instead of time.sleep().
    k is the maximum number of seconds to wait for the page to load.
    """

    # Configure Selenium options
    options = Options()
    options.add_argument("--headless")  # Run in headless mode (no GUI)
    options.add_argument("--width=1920")
    options.add_argument("--height=1080")

    # Initialize WebDriver
    service = Service(GECKO_DRIVER_PATH)
    driver = webdriver.Firefox(service=service, options=options)

    rendered_html = ""
    try:
        # Load the webpage
        driver.get(url)

        try:
            # Wait up to k seconds for the page's body to be present
            WebDriverWait(driver, k).until(
                EC.presence_of_element_located((By.CSS_SELECTOR, "body"))
            )
            # If successful, get the rendered HTML
            rendered_html = driver.page_source
        except TimeoutException:
            # If the page doesn't load within k seconds, handle it here
            print(f"Timed out waiting for page to load: {url}")
            rendered_html = None

    finally:
        driver.quit()

    return rendered_html


def get_post_text(post_url, k=60, max_retries=10):
    """
    Get the text of the ALLSTAT post.
    This function could be obsolete in favour of get_post_plaintext
    """

    clip = "You may leave the list at any time by sending the command\n\nSIGNOFF allstat\n\nto [log in to unmask], leaving the subject line blank.\n"
    for _ in range(max_retries):
        try:
            soup = BeautifulSoup(render(post_url, k=k), "html.parser")
            return soup.find(id="awesomepre").find("pre").text.replace(clip, "")
        except:
            print("Retrying {url}".format(url=post_url))
    else:
        ipdb.set_trace()


def get_post_plaintext(post_url, k=60, max_retries=3, pdb=False):
    """
    Get the text of the ALLSTAT post.
    Each ALLSTAT post has, or should have, a link to plaintext version of the post.
    Sometimes, this is not there but a link to almost plaintext but technically html
    version of the post is available instead.
    This function tries to get the text/plain first and then tries the text/html.
    """

    for _ in range(max_retries):
        try:
            clip = "You may leave the list at any time by sending the command\n\nSIGNOFF allstat\n\nto [log in to unmask], leaving the subject line blank.\n"
            soup = BeautifulSoup(render(post_url, k=k), "html.parser")
            try:
                plaintext_link = soup.find("a", string="text/plain")
                plaintext_url = "https://www.jiscmail.ac.uk" + plaintext_link["href"]
                soup2 = BeautifulSoup(render(plaintext_url, k=k), "html.parser")
                return soup2.find("pre").text.replace(clip, "").strip()
            except:
                # try to get the html counterpart
                htmltext_link = soup.find("a", string="text/html")
                htmltext_url = "https://www.jiscmail.ac.uk" + htmltext_link["href"]
                soup2 = BeautifulSoup(render(htmltext_url, k=k), "html.parser")
                return soup2.find("body").text.replace(clip, "").strip().strip('Print').strip()

        except:
            print("Retrying {url}".format(url=post_url))
    else:
        if pdb:
            ipdb.set_trace()
        else:
            print('Giving up and moving on.')


def get_list_of_posts_for_month(url, k=60, max_retries=10):
    """
    ALLSTAT's website archives all posts from 1998 to the present.
    These can be found at https://www.jiscmail.ac.uk/cgi-bin/webadmin?A0=allstat.
    For each year from 1998 to 2006 inclusive, it provides one list, which
    contains all the posts to ALLSTAT each year.
    From January 2007, it provides monthly lists, i.e. all posts to ALLSTAT each month
    from January 2007 to the present.

    This function takes as the `url` argument, the url to one of the yearly or monthly
    list of posts.
    For example, the url https://www.jiscmail.ac.uk/cgi-bin/wa-jisc.exe?A1=ind1003&L=ALLSTAT
    provides the list of all posts to ALLSTAT in March 2010 (note "1003" where "10" is the year
    and "03" is the month).

    It returns a dictionary

    In the rendered html page, find the html table with all the posts.
    That table will have 'Subject', 'From', 'Date', 'Size' as the
    values of its first row.
    """

    posts = {}
    for _ in range(max_retries):
        try:
            html_string = render(url, k=k)
            soup = BeautifulSoup(html_string, "html.parser")

            # Find all tables in file
            tables = soup.find_all("table")

            # Extract the first row of each table
            # Stop and return the table if it has the correct first row,
            # i.e. 'Subject', 'From', 'Date', 'Size'
            for i, table in enumerate(tables, start=1):
                headers = [th.get_text(strip=True) for th in table.find_all("th")]
                first_row = table.find("tr")  # Get the first row

                if first_row:
                    row_data = [
                        td.get_text(strip=True) for td in first_row.find_all("td")
                    ]
                    if row_data == ["Subject", "From", "Date", "Size"]:
                        break

            for row in [x.find("td").find("a") for x in table.find_all("tr")][1:]:
                post_title, post_url = row.text, row["href"]
                # posts[post_title] = (post_url, get_post_text(post_url))
                posts[post_title] = post_url
            break
        except:
            # Sometimes problems arise with the above for some as yet unknown
            # reasons.
            # We will drop into a debug shell.
            print("Retrying {url}".format(url=url))
    else:
        ipdb.post_mortem()

    return posts


def get_list_of_monthly_post_lists(
    allstat_url="https://www.jiscmail.ac.uk/cgi-bin/webadmin?A0=allstat",
    url_root="https://www.jiscmail.ac.uk",
):
    """
    Get the list of monthly, or at the beginning, yearly lists of posts to ALLStat.
    Return as a dictionary whose keys are the name of the month/year (or year) and
    whose values are the url to the month's list of posts.
    """

    results = []

    html = render(allstat_url)
    soup = BeautifulSoup(html, "html.parser")
    tables = soup.find_all("table")

    for table in tables:
        first_row = table.find("tr")

        try:
            text = first_row.text
            if text == "ALLSTAT ":
                break

        except AttributeError as e:
            pass

    lists_dict = {}
    for li in table.find_all("li"):
        a = li.find("a")
        lists_dict[a.text] = url_root + a["href"]

    return lists_dict


def get_links_to_all_posts(verbose=False):
    """
    Return dict with url links to all posts to ALLSTAT.
    Each element of the dict is a dictionary of all posts
    made in any given month or year.
    Each of these dicts is a key, value pair where
    the key is the post's title and the value is the post's url.
    """

    posts = {}
    for month, month_list in get_list_of_monthly_post_lists().items():
        if verbose:
            print(month)
        posts[month] = get_list_of_posts_for_month(month_list)

    return posts


if __name__ == "__main__":

    import argparse
    import json

    parser = argparse.ArgumentParser(description="Script to get ALLSTAT posts.")

    subparsers = parser.add_subparsers(dest="command", required=True)

    # sub-command to get list of all posts (list of titles and urls)
    parser_get_posts_lists = subparsers.add_parser(
        "get_links_to_all_posts", help="Get list of all posts"
    )
    parser_get_posts_lists.add_argument(
        "--outfile", required=True, help="Output json file for saving list of posts"
    )
    parser_get_posts_lists.add_argument(
        "--verbose", action="store_true", help="Print out each ALLSTAT month"
    )

    # sub-command to get list of posts, post contents this time, that are about training courses
    parser_get_training_posts = subparsers.add_parser(
        "get_training_course_posts",
        help="Get contents of posts with 'training' or 'course' in title",
    )
    parser_get_training_posts.add_argument(
        "--posts_list", required=True, help="json file with list of URLs of all posts"
    )
    parser_get_training_posts.add_argument(
        "--outfile", required=True, help="Output json file for saving posts"
    )
    parser_get_training_posts.add_argument(
        "--verbose", action="store_true", help="Print out each matching post's title"
    )

    args = parser.parse_args()

    if args.command == "get_links_to_all_posts":
        list_of_all_posts = get_links_to_all_posts(args.verbose)

        with bz2.open(args.outfile, "wt", encoding="utf-8") as f:
            json.dump(list_of_all_posts, f, indent=4, ensure_ascii=False)

    elif args.command == "get_training_course_posts":

        with bz2.open(args.posts_list, "rt", encoding='utf-8') as f:
            post_list = json.load(f)

        posts = []
        for month, month_post_list in post_list.items():
            if args.verbose:
                print(month)
            for post_title, post_url in month_post_list.items():
                if "training" in post_title.lower() or "course" in post_title.lower():
                    if args.verbose:
                        print(post_title)
                    post_text = get_post_plaintext(post_url)
                    posts.append(
                        dict(
                            month=month, title=post_title, url=post_url, text=post_text
                        )
                    )

                    with bz2.open(args.outfile, "wt", encoding='utf-8') as f:
                        json.dump(posts, f, indent=4, ensure_ascii=False)
