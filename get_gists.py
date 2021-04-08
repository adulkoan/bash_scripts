# Github API
# Write a script that uses the Github API to query a user’s publicly available gists. When the script is first run, it should 
# display a listing of all the user’s publicly available gists. On subsequent runs the script should list any gists that have 
# been published since the last run. The script may optionally provide other functionality (possibly via additional command line 
# flags) but the above functionality must be implemented.

import os
import json
import requests
import sys

if len(sys.argv) != 2:
    print ("usage: " + sys.argv[0] + " <github_user_id>")
    sys.exit()

my_config_dir = os.getenv("HOME") + "/.gistsdb"
github_id = sys.argv[(len(sys.argv) - 1)]
github_api_url = "https://api.github.com/"
github_api_users_url = github_api_url + "users/"
github_api_user_url = "https://api.github.com/users/" + github_id
github_user_gists_url = github_api_user_url + "/gists"
github_gists_url = github_api_url + "gists/"
my_gists_db_file = my_config_dir + "/" + github_id

gist_ids = []
users_previous_gists = []
new_gists = []

if not os.path.isdir(my_config_dir):
    try:
        os.mkdir(my_config_dir)
        print ("INFO: created gistsdb directory" + my_config_dir)
    except OSError:
        print ("ERROR: unable to create gistsdb directory" + my_config_dir + ". Exiting")
        sys.exit()

request_status_code = requests.get(github_api_user_url).status_code

if request_status_code == 200:
    if os.path.isfile(my_gists_db_file):
        with open(my_gists_db_file, 'r') as f:
            users_previous_gists = json.loads(f.read())
            f.close()

if request_status_code == 200:
    gists = requests.get(github_user_gists_url).json()

    for gist in gists:
        gist_ids.append(gist["id"])

    with open(my_gists_db_file, 'w') as f:
        f.write(json.dumps(gist_ids))
        f.close()

    new_gists = list (set(gist_ids) - set(users_previous_gists))

    for gist_id in new_gists:
        gist_details = requests.get(github_gists_url + gist_id).json()
        print ("gist url: " + gist_details["url"] + "\n" + "gist description: " + gist_details["description"] + "\n\n")
    
else :
    print ("unable to find Github user " + github_id + ".")
