# Standard library imports
import os
import re
import bz2
import json
import argparse
import time

#  third party imports
from bs4 import BeautifulSoup

# local imports
import allstat

TESS_COURSE_LIST_PAGE = "https://tess.elixir-europe.org/events?event_types=Workshops+and+courses&include_expired=true&page={i}"


def get_course_list():

    def _extract_course_info(course_dict):
        """Extracts key information from a course description dictionary."""

        course_instance = course_dict.get("hasCourseInstance")

        try:
            address = course_instance[0]["location"]["address"]
        except:
            address = {}

        info = {
            "url": course_dict.get("@id"),
            "name": course_dict.get("name"),
            "startDate": course_instance[0].get("startDate"),
            "endDate": course_instance[0].get("endDate"),
        }

        info.update(address)

        info.pop("@type", None)  # remove '@type' if it exists

        return info

    def _get_last_page():
        """
        We will iterate through the course listing pages from 1 to N.
        This function returns the value of N.
        """
        article = allstat.render(TESS_COURSE_LIST_PAGE.format(i=1))
        soup = BeautifulSoup(article, "html.parser")
        s = (
            soup.find("ul", class_="pagination pagination")
            .find("li", class_="last")
            .find("a")["href"]
        )
        pattern = re.compile(r".*&page=(\d+)")
        return int(pattern.search(s).group(1))

    courses = []
    N = _get_last_page()
    for i in range(N):
        print(f"Page {i+1} of {N}, {100*(i+1)/N:.2f}%")
        article = allstat.render(TESS_COURSE_LIST_PAGE.format(i=i + 1))
        soup = BeautifulSoup(article, "html.parser")
        # all the courses listed on the page are in json scripts
        for script in soup.find_all("script", {"type": "application/ld+json"}):
            courses.append(_extract_course_info(json.loads(script.string.strip())))

    return courses


def get_course_details(courses, max_attempts=10, wait_time=3, backup='course_details_backup.json'):

    def _get_course_details(course, max_attempts, wait_time):
        "Get details of one single course"

        course = course.copy()

        url = course["url"]

        def _clean_about(about):
            if about:
                return [x["name"] for x in about]

        def _clean_organizer(organizer):
            if organizer:
                return organizer.get("name")

        attempt = 0 
        while attempt < max_attempts:
            try:

                post = allstat.render(url)
                soup = BeautifulSoup(post, "html.parser")
                script = soup.find_all("script", {"type": "application/ld+json"})[0]
                details = json.loads(script.string.strip())

                instance = details["hasCourseInstance"][0]
                details.update(instance)

                new_details = {
                    "name": details.get("name"),
                    "mode": details.get("courseMode"),
                    "description": details.get("description"),
                    "keywords": details.get("keywords"),
                    "organizer": _clean_organizer(details.get("organizer")),
                    "about": _clean_about(details.get("about")),
                }

                course.update(new_details)

                return course
            except Exception as e:
                print(f"Attempt {attempt + 1} failed: {e}")
                attempt += 1
                time.sleep(wait_time)

        return course # all else fails

    courses_details = []
    N = len(courses)
    for i, course in enumerate(courses):
        print(f"Extracting details of course {i+1} of {N}, {100*(i+1)/N:.2f}%")
        course_details = _get_course_details(course, max_attempts=max_attempts, wait_time=wait_time)

        courses_details.append(course_details)

        with open(backup, "wt", encoding="utf-8") as f:
            json.dump(courses_details, f, indent=4, ensure_ascii=False)


    return courses_details


def parse_args():
    parser = argparse.ArgumentParser(description="Get eTESS course listing script")

    # Create subparsers for "get_course_list" and "get_course_details"
    subparsers = parser.add_subparsers(dest="command", required=True)

    # "get_course_list" command
    parser_list = subparsers.add_parser(
        "get_course_list", help="Fetch course list and save to a file"
    )
    parser_list.add_argument(
        "--outfile", required=True, help="Output file for the course list"
    )

    # "get_course_details" command
    parser_details = subparsers.add_parser(
        "get_course_details", help="Fetch course details based on a course list"
    )
    parser_details.add_argument(
        "--course_list", required=True, help="Input file containing course list"
    )
    parser_details.add_argument(
        "--outfile", required=True, help="Output file for course details"
    )
    parser_details.add_argument(
        "--backup", required=True, help="Backup file for course details"
    )



    # Parse the arguments
    return parser.parse_args()


if __name__ == "__main__":

    args = parse_args()

    if args.command == 'get_course_list':
        courses = get_course_list()
        with bz2.open(args.outfile, "wt", encoding="utf-8") as f:
            json.dump(courses, f, indent=4, ensure_ascii=False)

    elif args.command == 'get_course_details':

        with bz2.open(args.course_list, "rt") as f:
            courses = json.load(f)

        course_details = get_course_details(courses, backup=args.backup)
        with bz2.open(args.outfile, "wt", encoding="utf-8") as f:
            json.dump(course_details, f, indent=4, ensure_ascii=False)

        os.unlink(args.backup)