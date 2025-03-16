# standard lib imports
from datetime import datetime
import argparse
import sys
import bz2
import json
import re
import os

# third party imports
from bs4 import BeautifulSoup

# local imports
import allstat

# ======================================


def write_ncrm_courses_list_page(outfile):
    """
    A single URL with query string can seemingly return a single html page with a list of all
    NCRM training courses in the NCRM training course database.
    This function will write that page to a file.
    We can in principle run this function repeatedly, but it is easier to do it once
    and then do further processing by reading in the html file itself.

    The html file is large, around 15MB, so it will be compressed using bz2.
    """

    NCRM_COURSES_LIST_URL = "https://www.ncrm.ac.uk/training/index.php?search_type=&action=results&type=&do_advanced_search=&q=&ncrm=&ncrmPartner=&region=&time_happening=&level=&format=&time=past&date_start=&date_end=&scroll=scroll&show=100000"
    ncrm_courses_list_page = allstat.render(NCRM_COURSES_LIST_URL)

    with bz2.open(outfile, "wt") as f:
        f.write(ncrm_courses_list_page)


def get_ncrm_events(path):
    """
    This reads in the comprssed html page with all events.
    It returns a list of dicts, one for each event.
    The dict contains an id from which that event's webpage
    can be obtained.
    """

    # Load and decompress the bz2-compressed HTML file
    with bz2.open(path, "rt", encoding="utf-8") as f:
        soup = BeautifulSoup(f, "html.parser")

    # Find all event-block divs
    events = soup.find_all("div", class_="event-block")

    # Extract information from each event
    event_data = []
    for event in events:
        # Extract article number from href attribute
        link = event.find("a", href=True)
        article_number = link["href"].split("article=")[-1] if link else None

        # Extract event date
        event_date_tag = event.find("strong", class_="event-date")
        event_date = event_date_tag.get_text(strip=True) if event_date_tag else None

        # Extract event title
        event_title_tag = event.find("strong", class_="event text-blue")
        event_title = event_title_tag.get_text(strip=True) if event_title_tag else None

        # Extract presenter
        presenter_tag = event.find("span", class_="presenter")
        presenter = presenter_tag.get_text(strip=True) if presenter_tag else None

        # Extract place
        place_tag = event.find("span", class_="place")
        place = place_tag.get_text(strip=True) if place_tag else None

        # Store the extracted data
        event_data.append(
            {
                "article": article_number,
                "event-date": event_date,
                "event": event_title,
                "presenter": presenter,
                "place": place,
            }
        )

    return event_data


# def write_events_list(events, outfile):
#     """Save events list as a bz2-compressed JSON file."""
#     # Save to a JSON file
#     with bz2.open(outfile, "wt") as f:
#         json.dump(events, f, indent=4)


# def read_events_list(path):
#     '''
#     Read event list from bz2-compressed JSON file.
#     '''
#     with bz2.open(path, "rt") as f:
#         return json.load(f)


def get_event_info(event):
    """
    Get Date, Organized by, Presenter, Level, Contact, Venue, Description
    The Description is a block of text, but inside there are labels like
    'keywords', 'region', etc. These can be extracted later.
    """

    def _get_article(id):
        """
        Return render article html page
        """
        return allstat.render("https://www.ncrm.ac.uk/training/show.php?article=" + id)

    def _get_description(soup):
        description_header = soup.find(
            "h3", string=re.compile(r"\bDescription:", re.IGNORECASE)
        )

        # Collect all the following <p> elements until another <h3> or end of section
        description_text = []
        if description_header:
            for sibling in description_header.find_next_siblings():
                if sibling.name == "h3":  # Stop if another section starts
                    break
                if (
                    sibling.name == "p"
                    and "Related publications and presentations from our eprints archive:"
                    in sibling.get_text()
                ):
                    break
                if sibling.name == "p":
                    description_text.append(sibling.get_text(strip=True))

        # Join all paragraphs into a single text block
        return " ".join(description_text)

    def _extract_costs_etc(description):
        """
        Try to extract costs, region, and keywords from the Description
        """
        try:
            cost_pattern = re.search(
                r"Cost:\s*([^\n]*)Region:", description, re.IGNORECASE
            )
            region_pattern = re.search(
                r"Region:\s*([^\n]*)Keywords:", description, re.IGNORECASE
            )
            keywords_pattern = re.search(
                r"Keywords:\s*([^\n]*)", description, re.IGNORECASE
            )

            # Extract values if found
            cost = (
                cost_pattern.group(1).strip("Website and registration:").strip()
                if cost_pattern
                else ""
            )
            region = region_pattern.group(1).strip() if region_pattern else ""
            keywords = (
                keywords_pattern.group(1).strip().split(", ")
                if keywords_pattern
                else ""
            )

        except:
            cost = ""
            region = ""
            keywords = [""]

        return {"Cost": cost, "Region": region, "Keywords": keywords}

    id = event["article"]
    soup = BeautifulSoup(_get_article(id), "html.parser")

    # Dictionary to store extracted data
    data = {}

    try:
        # Find all <b> tags inside the div
        for b_tag in soup.select(".column-test b"):
            key = b_tag.get_text(strip=True).rstrip(
                ":"
            )  # Extract label name, remove trailing colon
            value_p = b_tag.find_next("p")  # Get the next <p> tag which contains the value

            if value_p:
                # If contact, extract email separately
                if "Contact" in key:
                    email_tag = value_p.find("a", href=True)
                    email = email_tag["href"].replace("mailto:", "") if email_tag else None
                    value = value_p.get_text(" ", strip=True)
                    data[key] = {"name": value, "email": email}
                else:
                    data[key] = value_p.get_text(strip=True)
    except:
        pass

    # Venue =====================================================
    try:
        venue = (
            soup.find("b", string=re.compile(r"\bVenue:", re.IGNORECASE))
            .find_next(string=True)
            .find_next(string=True)
        )
    except:
        venue = ""

    data["Venue"] = ""

    # Description ================================================
    try:
        description = _get_description(soup)
    except:
        description = ''

    data["Description"] = description

    # Costs_etc ================================================
    try:
        costs_etc = _extract_costs_etc(description)
    except:
        costs_etc = ''



    # Update ====================================================
    new_event = event.copy()  # safer to copy and return new dict
    new_event.update(data)  # add the extracted data
    new_event.update(costs_etc)

    return new_event


def extract_events(events_list_page, outfile, backup_file=None):

    if backup_file is None:
        backup_file = datetime.now().strftime(
            "extract_events_backup_%d_%B_%Y_%H_%M.json"
        )

    events = get_ncrm_events(events_list_page)
    n = len(events)
    new_events_list = []
    for i, event in enumerate(events):
        print(
            "Processing article {id}, {i} of {n} ({r:.2f})%".format(
                id=event["article"], i=i + 1, n=n, r=100 * (i + 1) / n
            )
        )
        new_events_list.append(get_event_info(event))

        with open(backup_file, "wt", encoding="utf-8") as f:
            json.dump(new_events_list, f, indent=4, ensure_ascii=False)

    with bz2.open(outfile, "wt", encoding="utf-8") as f:
        json.dump(new_events_list, f, indent=4, ensure_ascii=False)

    os.remove(backup_file)


def parse_arguments():
    """Parse command line arguments with subcommands."""
    parser = argparse.ArgumentParser(
        description="Process course listings and extract events."
    )

    # Create subparsers for different commands
    subparsers = parser.add_subparsers(dest="command", help="Command to execute")
    subparsers.required = True

    # get_course_listing_page subcommand
    get_page_parser = subparsers.add_parser(
        "get_course_listing_page", help="Download the course listing page"
    )
    get_page_parser.add_argument(
        "--outfile",
        required=True,
        help="Output file for the course listing page (HTML, bz2 compressed)",
    )

    # extract_events subcommand
    extract_parser = subparsers.add_parser(
        "extract_events", help="Extract events from the course listing page"
    )
    extract_parser.add_argument(
        "--course_listing_page",
        required=True,
        help="Input course listing page file (HTML, bz2 compressed)",
    )
    extract_parser.add_argument(
        "--outfile",
        required=True,
        help="Output file for extracted events (JSON, bz2 compressed)",
    )

    return parser.parse_args()


if __name__ == "__main__":

    args = parse_arguments()

    if args.command == "get_course_listing_page":
        write_ncrm_courses_list_page(args.outfile)

    elif args.command == "extract_events":
        extract_events(args.course_listing_page, outfile=args.outfile)
