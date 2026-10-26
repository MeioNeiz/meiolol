# Help:Leaguepedia API - Leaguepedia | League of Legends Esports Wiki

<https://lol.fandom.com/wiki/Help:Leaguepedia_API>

[Sign In](https://auth.fandom.com/signin?source=mw&redirect=https%3A%2F%2Flol.fandom.com%2Fwiki%2FHelp%3ALeaguepedia_API&metadata=header-signin-button)

[Create a Free Account](https://auth.fandom.com/register?source=mw&redirect=https%3A%2F%2Flol.fandom.com%2Fwiki%2FHelp%3ALeaguepedia_API&metadata=header-registration-button)

Leaguepedia API Leaguepedia | League of Legends Esports Wiki

[Sign In](https://auth.fandom.com/signin?source=mw&redirect=https%3A%2F%2Flol.fandom.com%2Fwiki%2FHelp%3ALeaguepedia_API&metadata=header-signin-button)

[Create Free Account](https://auth.fandom.com/register?source=mw&redirect=https%3A%2F%2Flol.fandom.com%2Fwiki%2FHelp%3ALeaguepedia_API&metadata=header-registration-button)

[Home](https://www.fandom.com/)

[Saved](https://www.fandom.com/saved)

[Progress](https://www.fandom.com/progress)

[Utilities](https://www.fandom.com/utilities)

[Pick'ems](https://lol.fandom.com/wiki/Special:GameUtility/LeaguepediaPickems)

[Skip to content](https://lol.fandom.com/wiki/Help:Leaguepedia_API#page-header)

-   Explore
    
-   Navigation
    
-   Regions
    
-   Competitive
    
-   Editing Help
    
-   More
    

# Help:Leaguepedia API

[Save](https://auth.fandom.com/register?redirect=https%3A%2F%2Flol.fandom.com%2Fwiki%2FHelp%3ALeaguepedia_API%3Fcollections%3Dsave&uselang=en&metadata=collections-save-button "Sign In to Save")

## Contents

-   [1 Projects Using the API](https://lol.fandom.com/wiki/Help:Leaguepedia_API#Projects_Using_the_API)
-   [2 MediaWiki API](https://lol.fandom.com/wiki/Help:Leaguepedia_API#MediaWiki_API)
    -   [2.1 Resources](https://lol.fandom.com/wiki/Help:Leaguepedia_API#Resources)
    -   [2.2 Python Packages](https://lol.fandom.com/wiki/Help:Leaguepedia_API#Python_Packages)
    -   [2.3 River's libraries](https://lol.fandom.com/wiki/Help:Leaguepedia_API#River's_libraries)
-   [3 Cargo](https://lol.fandom.com/wiki/Help:Leaguepedia_API#Cargo)
    -   [3.1 Limits](https://lol.fandom.com/wiki/Help:Leaguepedia_API#Limits)
    -   [3.2 Fields](https://lol.fandom.com/wiki/Help:Leaguepedia_API#Fields)
    -   [3.3 Sample Code](https://lol.fandom.com/wiki/Help:Leaguepedia_API#Sample_Code)
        -   [3.3.1 Example 1: Basic Search](https://lol.fandom.com/wiki/Help:Leaguepedia_API#Example_1:_Basic_Search)
        -   [3.3.2 Example 2: Results before/after date](https://lol.fandom.com/wiki/Help:Leaguepedia_API#Example_2:_Results_before/after_date)
        -   [3.3.3 Example 3: Multiple table search](https://lol.fandom.com/wiki/Help:Leaguepedia_API#Example_3:_Multiple_table_search)
        -   [3.3.4 Example 4: Results in a day, joining ScoreboardGames and ScoreboardPlayers](https://lol.fandom.com/wiki/Help:Leaguepedia_API#Example_4:_Results_in_a_day,_joining_ScoreboardGames_and_ScoreboardPlayers)
        -   [3.3.5 Example 5.1: Save Player image](https://lol.fandom.com/wiki/Help:Leaguepedia_API#Example_5.1:_Save_Player_image)
        -   [3.3.6 Example 5.2: Save Team image](https://lol.fandom.com/wiki/Help:Leaguepedia_API#Example_5.2:_Save_Team_image)
        -   [3.3.7 Example 6: Fetching post-game data files](https://lol.fandom.com/wiki/Help:Leaguepedia_API#Example_6:_Fetching_post-game_data_files)
        -   [3.3.8 Example 7: Fetching information for all players who played in the LEC](https://lol.fandom.com/wiki/Help:Leaguepedia_API#Example_7:_Fetching_information_for_all_players_who_played_in_the_LEC)
        -   [3.3.9 More Examples](https://lol.fandom.com/wiki/Help:Leaguepedia_API#More_Examples)
    -   [3.4 Possible Issues and Solutions](https://lol.fandom.com/wiki/Help:Leaguepedia_API#Possible_Issues_and_Solutions)
-   [4 Cargo Table Overviews](https://lol.fandom.com/wiki/Help:Leaguepedia_API#Cargo_Table_Overviews)
    -   [4.1 Player Queries](https://lol.fandom.com/wiki/Help:Leaguepedia_API#Player_Queries)
    -   [4.2 Stats Queries](https://lol.fandom.com/wiki/Help:Leaguepedia_API#Stats_Queries)
    -   [4.3 Schedule Queries](https://lol.fandom.com/wiki/Help:Leaguepedia_API#Schedule_Queries)
    -   [4.4 Team Queries](https://lol.fandom.com/wiki/Help:Leaguepedia_API#Team_Queries)
    -   [4.5 Roster Queries](https://lol.fandom.com/wiki/Help:Leaguepedia_API#Roster_Queries)
    -   [4.6 Picks and Bans Queries](https://lol.fandom.com/wiki/Help:Leaguepedia_API#Picks_and_Bans_Queries)

This page documents Leaguepedia's API, which can be used for querying League of Legends esports schedules, statistics, players, rosters, roster changes, articles, interviews, tournament results, and nearly any other piece of data available on the wiki.

This page is intended to be used by developers who want to query our data. It is not a tutorial for people without previous development experience. **This is not an official Riot resource.** We are a third-party site. There may be errors or omissions in our data, and the API is made available without guarantee of stability or accuracy.

Our API is made available as a courtesy. As such, beyond this documentation you're on your own for figuring things out. We have a Discord Server if you need help, but in-depth help is not guaranteed.

Row IDs should NOT be used as permanent primary keys in your data. They change every time the Cargo data is recreated. In general, you shouldn't rely on any field we have as a permanent primary key, as the wiki's content always will come first for development concerns.

Please join our [Discord Server](https://discord.gg/6SNQ4c6) and ask in the `api-help` channel if you have questions about the API, please note the the API is not part of our primary content offering, so in depth support is not guaranteed.

An unofficial wrapper for this API is available [here](https://github.com/mrtolkien/leaguepedia_parser). Ping Tolki in the channel linked above for support.

Commonly-addressed issues:

-   The API works by you making SQL queries to our database, it's not what you might expect when you first hear "API for getting data." Even if you want 1 piece of information, you make a query that will return that one data point.
-   Please do not ever use `_pageName` as a condition or a value, this field is automatically populated in tables but will almost never be what you actually want. See [Don't use \_pageName](https://river.me/blog/dont-use-pagename/) for more information (this is a very indepth, technical, not very relevant article, only read if you are extremely curious). Generally `OverviewPage` is populated in a table for use instead of `_pageName`, sometimes there's another intended key. Ask in the support server if you need help.

## Projects Using the API

Below is a list of projects that use the API. Feel free to add any other examples for reference. Please only include links to OSS projects' source code.

-   [League of Elo](https://jprmesh.github.io/LeagueOfElo/): Elo-based team strength model. All data is acquired through the API.
-   [Lol Worlds Predictions](https://github.com/Arakkun/LolWorldsPredictions/): Regional and Temporal Elo-based team strength model trained with a Genetic Algorithm for the maximization of the Worlds Pick'Em score. All data is acquired through the API.

## MediaWiki API

The MediaWiki action API is a web service that allows access to some wiki functions like page operations, search and user authentication so that you may be able to edit or query the wiki using a bot or program.

The API endpoint is `[https://lol.fandom.com/api.php](https://lol.fandom.com/api.php)`. For example, to list all pages in the wiki `[https://lol.fandom.com/api.php?action=query&format=json&list=allpages](https://lol.fandom.com/api.php?action=query&format=json&list=allpages)` could be used. It is generally recommended to use libraries to interact with the API instead of directly making requests. See [Python Packages](https://lol.fandom.com/wiki/Help:Leaguepedia_API#Python_Packages) and [Libraries in other languages](https://www.mediawiki.org/wiki/API:Client_code "mw:API:Client code").

### Resources

-   See [API help on mediawiki.org](https://www.mediawiki.org/wiki/API:Main_page "mediawikiwiki:API:Main page").
-   Use [Special:ApiSandbox](https://lol.fandom.com/wiki/Special:ApiSandbox "Special:ApiSandbox") to test the API.
-   See [Logging in to third-party tools](https://help.gamepedia.com/Logging_in_to_third-party_tools "gphelp:Logging in to third-party tools") on the Help wiki for getting a bot password (the token you will use to log into the wiki to make requests).
    -   This is only needed if you want to EDIT the wiki. Just to make queries you do NOT need a token.
-   [API libraries in various languages](https://www.mediawiki.org/wiki/API:Client_code "mw:API:Client code") on mediawiki.org, in case you're not using Python/mwclient.

### Python Packages

The documentation provides code examples using the following python packages:

-   [mwrogue](https://github.com/RheingoldRiver/mwrogue): Python client used to interact with Fandom/Gamepedia esports wikis
-   [mwparserfromhell](https://mwparserfromhell.readthedocs.io/en/latest/): Python client that makes editing the wiki easier

Example code to log into the wiki using **mwrogue**:

from mwrogue.esports\_client import EsportsClient
from mwrogue.auth\_credentials import AuthCredentials

credentials \= AuthCredentials(user\_file\="me")
site \= EsportsClient('lol', credentials\=credentials)

The first time you try to log in using mwrogue, it will prompt you to enter your username, your bot password name, and your bot password secret, and will create a configuration file named "me".

Read more about bot passwords [here](https://www.mediawiki.org/wiki/Manual:Bot_passwords "mediawikiwiki:Manual:Bot passwords").

### River's libraries

-   [mwcleric](https://github.com/RheingoldRiver/mwcleric) - also available on [PyPI](https://pypi.org/project/mwcleric/) and [AUR](https://aur.archlinux.org/packages/python-mwcleric-git/). This library is a general MediaWiki API wrapper that's an extension of `mwclient`, with several improvements for working with Fandom wikis.
-   [mwrogue](https://github.com/RheingoldRiver/mwrogue) - also available on [PyPI](https://pypi.org/project/mwrogue/) and [AUR](https://aur.archlinux.org/packages/python-mwrogue-git/). This library extends `mwcleric` further for Leaguepedia and the other esports wikis. You will want to include and work with this library, while most methods are fully documented at `mwcleric`.

## Cargo

_Full list of tables at [Special:CargoTables](https://lol.fandom.com/wiki/Special:CargoTables "Special:CargoTables")_

[Cargo](https://www.mediawiki.org/wiki/Extension:Cargo "mediawikiwiki:Extension:Cargo") is an SQL wrapper that we use for all of our databases. You may access information in the database in a few ways:

1.  Use [Special:CargoTables](https://lol.fandom.com/wiki/Special:CargoTables "Special:CargoTables") on a web browser
2.  Run the forms located at [Category:Query\_Forms](https://lol.fandom.com/wiki/Category:Query_Forms "Category:Query Forms") on a web browser (eg. [Special:RunQuery/MatchHistoryGame](https://lol.fandom.com/wiki/Special:RunQuery/MatchHistoryGame "Special:RunQuery/MatchHistoryGame"))
3.  Use the API through the MediaWiki API using mwrogue

Note that the Forms in 2 are actually just custom queries running on top of 1. You can see how these queries are made by looking at the settings of the modules (eg. [Module:MatchHistoryGame/Settings](https://lol.fandom.com/wiki/Module:MatchHistoryGame/Settings "Module:MatchHistoryGame/Settings"))

If you want to make cargo queries through the API, it is really important **to log in with a Bot Password and have your email address confirmed first**, as Fandom added ratelimits that make it practically impossible to execute queries while logged out. See [#MediaWiki API](https://lol.fandom.com/wiki/Help:Leaguepedia_API#MediaWiki_API) and [User:Arbolitoloco/Avoiding cargo ratelimits](https://lol.fandom.com/wiki/User:Arbolitoloco/Avoiding_cargo_ratelimits "User:Arbolitoloco/Avoiding cargo ratelimits") for more information.

You can see generic Cargo API documentation [here](https://lol.fandom.com/api.php?action=help&modules=cargoquery).

### Limits

-   5,000 results per query if you are an admin
-   500 result per query otherwise

### Fields

_See also: [Special:ViewData](https://lol.fandom.com/wiki/Special:CargoQuery "Special:CargoQuery")_ (must be logged in)

To run a Cargo query, you will need to specify:

| Field | Required | Description |
| --- | --- | --- |
| `tables` | Yes | One or more table names ([Special:CargoTables](https://lol.fandom.com/wiki/Special:CargoTables "Special:CargoTables"), more information [below](https://lol.fandom.com/wiki/Help:Leaguepedia_API#Cargo_Table_Overviews)) |
| `fields` | Yes | Columns to return. Full list of fields in [Category:Cargo Declaration Modules](https://lol.fandom.com/wiki/Category:Cargo_Declaration_Modules "Category:Cargo Declaration Modules"). (Cargo does not support `*` or wildcards) |
| `limit` | No | Maximum number of results to return. Can be 'max' or integer (default: 50) |
| `offset` | No | Query offset. Must be non-negative integer. (Default: 0) |
| `where` | No | The conditions for the query, corresponding to an SQL WHERE clause |
| `join_on` | Only if 2 or more `tables` | Conditions for joining multiple tables, corresponding to an SQL JOIN ON clause |
| `order_by` | No | The order of results, corresponding to an SQL ORDER BY clause |
| `group_by` | No | Field(s) on which to group results, corresponding to an SQL GROUP BY clause |
| `having` | No | Conditions for grouped values, corresponding to an SQL HAVING clause |

### Sample Code

#### Example 1: Basic Search

Query to see which teams faced against each other on which day.

**Warning:** this query will try to fetch all rows in `[[ScoreboardGames](https://lol.fandom.com/wiki/Special:CargoTables/ScoreboardGames "Special:CargoTables/ScoreboardGames")]`, which may take several minutes.

from mwrogue.esports\_client import EsportsClient
site \= EsportsClient("lol")

response \= site.cargo\_client.query(
    tables\="ScoreboardGames=SG, Tournaments=T",
    join\_on\="SG.OverviewPage=T.OverviewPage",
    fields\="T.Name, SG.DateTime\_UTC, SG.Team1, SG.Team2"
)

See this query in the [API Sandbox](https://lol.fandom.com/wiki/Special:ApiSandbox#action=cargoquery&format=json&tables=ScoreboardGames%3DSG%2C%20Tournaments%3DT&fields=T.Name%2C%20SG.DateTime_UTC%2C%20SG.Team1%2C%20SG.Team2&join_on=SG.OverviewPage%3DT.OverviewPage) and in [Special:CargoQuery](https://lol.fandom.com/wiki/Special:CargoQuery?tables=ScoreboardGames%3DSG%2C+Tournaments%3DT&fields=T.Name%2C+SG.DateTime_UTC%2C+SG.Team1%2C+SG.Team2&where=&join_on=SG.OverviewPage%3DT.OverviewPage&group_by=&having=&order_by%5B0%5D=&order_by_options%5B0%5D=ASC&limit=&offset=&format=). Note that to get more results you need to add an offset to the query. For example, if your limit is set to 50, set the offset to the same value in order to get the next 50 results.

Result

#### Example 2: Results before/after date

from mwrogue.esports\_client import EsportsClient
site \= EsportsClient("lol")

response \= site.cargo\_client.query(
    tables\="ScoreboardGames=SG, Tournaments=T",
    join\_on\="SG.OverviewPage=T.OverviewPage",
    fields\="T.Name, SG.DateTime\_UTC, SG.Team1, SG.Team2",
    where\="SG.DateTime\_UTC >= '2019-08-01 00:00:00'",  \# Results after Aug 1, 2019
    limit\=50
)

To search between Aug 8, 2019 and Aug 10, 2019 (inclusive), you can use:

`where = "SG.DateTime_UTC >= '2019-08-08' AND SG.DateTime_UTC <= '2019-08-10'"`

#### Example 3: Multiple table search

Query that returns fields from one table that are ordered based on criteria from another table. We want to get values from `[[MatchScheduleGame](https://lol.fandom.com/wiki/Special:CargoTables/MatchScheduleGame "Special:CargoTables/MatchScheduleGame")]`, but we use the page number, number of match in page, and number of game in match, from `[[MatchSchedule](https://lol.fandom.com/wiki/Special:CargoTables/MatchSchedule "Special:CargoTables/MatchSchedule")]` to order the results.

from mwrogue.esports\_client import EsportsClient
site \= EsportsClient("lol")

page\_to\_query \= "Data:2023 Mid-Season Invitational"
response \= site.cargo\_client.query(
    limit\=3,
    tables\="MatchScheduleGame=MSG,MatchSchedule=MS",
    fields\="MSG.OverviewPage, MSG.RiotPlatformGameId",
    where\='MSG.\_pageName="%s" AND MSG.RiotPlatformGameId IS NOT NULL' % page\_to\_query,
    join\_on\="MSG.MatchId=MS.MatchId",
    order\_by\="MS.N\_Page, MS.N\_MatchInPage, MSG.N\_GameInMatch"
)

Result

#### Example 4: Results in a day, joining ScoreboardGames and ScoreboardPlayers

from mwrogue.esports\_client import EsportsClient
import datetime as dt

date \= "2020-01-25"
date \= dt.datetime.strptime(date, "%Y-%m-%d").date()

site \= EsportsClient("lol")
response \= site.cargo\_client.query(
    tables\="ScoreboardGames=SG, ScoreboardPlayers=SP, Tournaments=T",
    join\_on\="SG.GameId=SP.GameId, SG.OverviewPage=T.OverviewPage",
    fields\="T.Name=Tournament, SG.DateTime\_UTC, SG.Team1, SG.Team2, SG.Winner, SG.Patch, SP.Link, SP.Team, SP.Champion, SP.SummonerSpells, SP.KeystoneMastery, SP.KeystoneRune, SP.Role, SP.GameId, SP.Side",
    where\="SG.DateTime\_UTC >= '" + str(date) + " 00:00:00' AND SG.DateTime\_UTC <= '" + str(date+dt.timedelta(1)) + " 00:00:00'"
)

Result

#### Example 5.1: Save Player image

This example would let you save locally the image of a player. It can also be adapted to save team logos.

from mwrogue.esports\_client import EsportsClient
import urllib.request

def get\_filename\_url\_to\_open(site: EsportsClient, filename, player, width\=None):
    response \= site.client.api(
        action\="query",
        format\="json",
        titles\=f"File:{filename}",
        prop\="imageinfo",
        iiprop\="url",
        iiurlwidth\=width,
    )

    image\_info \= next(iter(response\["query"\]\["pages"\].values()))\["imageinfo"\]\[0\]

    if width:
        url \= image\_info\["thumburl"\]
    else:
        url \= image\_info\["url"\]

    #In case you would like to save the image in a specific location, you can add the path after 'url,' in the line below.
    urllib.request.urlretrieve(url, player + '.png')

player \= "Perkz"

site \= EsportsClient("lol")
response \= site.cargo\_client.query(
    limit\=1,
    tables\="PlayerImages=PI, Tournaments=T",
    fields\="PI.FileName",
    join\_on\="PI.Tournament=T.OverviewPage",
    where\='Link="%s"' % player,
    order\_by\="PI.SortDate DESC, T.DateStart DESC"
)
url \= response\[0\]\['FileName'\]
get\_filename\_url\_to\_open(site, url, player)

#### Example 5.2: Save Team image

This is a variation of the previous example, that will download the square logo for a list of given teams.

from mwrogue.esports\_client import EsportsClient
import urllib.request

def get\_filename\_url\_to\_open(site: EsportsClient, filename, team, width\=None):
    response \= site.client.api(
        action\="query",
        format\="json",
        titles\=f"File:{filename}",
        prop\="imageinfo",
        iiprop\="url",
        iiurlwidth\=width,
    )

    image\_info \= next(iter(response\["query"\]\["pages"\].values()))\["imageinfo"\]\[0\]

    if width:
        url \= image\_info\["thumburl"\]
    else:
        url \= image\_info\["url"\]

    #In case you would like to save the image in a specific location, you can add the path after 'url,' in the line below.
    urllib.request.urlretrieve(url, team + '.png')

teams \= \["Furious Gaming"\]

site \= EsportsClient("lol")
for team in teams:
    url \= f"{team}logo square.png"
    get\_filename\_url\_to\_open(site, url, team)

As you can see, the `get_filename_url_to_open` function is the same as the one used in the previous example.

#### Example 6: Fetching post-game data files

See [Help:ACS archive & post-game JSONs#Library\_support](https://lol.fandom.com/wiki/Help:ACS_archive_%26_post-game_JSONs#Library_support "Help:ACS archive & post-game JSONs").

#### Example 7: Fetching information for all players who played in the LEC

from mwrogue.esports\_client import EsportsClient

site \= EsportsClient("lol")

response \= site.cargo\_client.query(
    tables\="Tournaments=T, TournamentPlayers=TP, PlayerRedirects=PR, Players=P",
    fields\="P.Player, P.Name, P.Country, P.Birthdate, P.Residency, P.Role",
    where\="T.League = 'LoL EMEA Championship'",
    join\_on\="T.OverviewPage=TP.OverviewPage, TP.Player=PR.AllName, PR.OverviewPage=P.OverviewPage",
    group\_by\="P.OverviewPage"
)

For a full list of Leagues, see [Metadata:Leagues](https://lol.fandom.com/wiki/Metadata:Leagues "Metadata:Leagues").

#### More Examples

For more examples, you can see [River's Python code](https://github.com/RheingoldRiver/leaguepedia_util) or [Arbolitoloco's scripts](https://github.com/arbolitoloco1/leaguepedia_scripts) at their GitHub pages. None of this code is intended to be extended but it contains several example queries.

### Possible Issues and Solutions

One common issue is that if you are querying the `_pageName` field, which is automatically added to every row in every table and returns the name of the page on which the row is stored, you must alias the field name, e.g. `MSG._pageName=DataPage`; returned field names are not allowed to begin or end with an underscore.

If one field is a `List` type field, you may wish to use the `HOLDS` condition in your `where`; however, this sometimes doesn't work well when you have multiple conditions specified. Also, if you are querying to return a `List` type field, you should append `__full` to the name of the field, e.g. `SP.Items__full=Items` instead of `SP.Items=Items`.

## Cargo Table Overviews

You can see a full list of tables at [Special:CargoTables](https://lol.fandom.com/wiki/Special:CargoTables "Special:CargoTables"). Note that some tables, such as `[[StandingsArgs](https://lol.fandom.com/wiki/Special:CargoTables/StandingsArgs "Special:CargoTables/StandingsArgs")]`, are useless out of the context of the wiki and are used only for wiki maintenance.

### Player Queries

To query player information, there are three relevant tables, `[[Players](https://lol.fandom.com/wiki/Special:CargoTables/Players "Special:CargoTables/Players")]`, `[[PlayerRedirects](https://lol.fandom.com/wiki/Special:CargoTables/PlayerRedirects "Special:CargoTables/PlayerRedirects")]`, and `[[Disambiguations](https://lol.fandom.com/wiki/Special:CargoTables/Disambiguations "Special:CargoTables/Disambiguations")]`.

-   `[[Players](https://lol.fandom.com/wiki/Special:CargoTables/Players "Special:CargoTables/Players")]` contains information about a player from `{{[Infobox Player](https://lol.fandom.com/wiki/Template:Infobox_Player "Template:Infobox Player")}}`: name, position, current team, etc. It should **never** be queried directly because players rename.
-   `[[PlayerRedirects](https://lol.fandom.com/wiki/Special:CargoTables/PlayerRedirects "Special:CargoTables/PlayerRedirects")]` can be joined to `[[Players](https://lol.fandom.com/wiki/Special:CargoTables/Players "Special:CargoTables/Players")]` on the field `OverviewPage`. It has one row per redirect that we have on the wiki to that player page, which will be a superset of the names the player has used in competition (sometimes common typos may also be redirected). The names here are case-insensitive and ignore special characters, so no duplication will occur when joining this between `[[Players](https://lol.fandom.com/wiki/Special:CargoTables/Players "Special:CargoTables/Players")]` and another table.
-   `[[Disambiguations](https://lol.fandom.com/wiki/Special:CargoTables/Disambiguations "Special:CargoTables/Disambiguations")]` will never need to be used if you have a controlled data set, but if you are taking user input you may want to query it first in case a user enters, for example, [Amazing](https://lol.fandom.com/wiki/Amazing "Amazing").
-   `[[TournamentResults](https://lol.fandom.com/wiki/Special:CargoTables/TournamentResults "Special:CargoTables/TournamentResults")]` can be joined to `[[TournamentPlayers](https://lol.fandom.com/wiki/Special:CargoTables/TournamentPlayers "Special:CargoTables/TournamentPlayers")]` to query player tournament results.

### Stats Queries

The tables containing in-game stats are:

-   `[[ScoreboardPlayers](https://lol.fandom.com/wiki/Special:CargoTables/ScoreboardPlayers "Special:CargoTables/ScoreboardPlayers")]`
-   `[[ScoreboardGames](https://lol.fandom.com/wiki/Special:CargoTables/ScoreboardGames "Special:CargoTables/ScoreboardGames")]`
-   `[[ScoreboardTeams](https://lol.fandom.com/wiki/Special:CargoTables/ScoreboardTeams "Special:CargoTables/ScoreboardTeams")]`.

You can join them on the field `GameId`. As with `[[Players](https://lol.fandom.com/wiki/Special:CargoTables/Players "Special:CargoTables/Players")]`, if querying a player's stats, do not query directly to this table; instead join `[[PlayerRedirects](https://lol.fandom.com/wiki/Special:CargoTables/PlayerRedirects "Special:CargoTables/PlayerRedirects")]`.

### Schedule Queries

-   `[[MatchSchedule](https://lol.fandom.com/wiki/Special:CargoTables/MatchSchedule "Special:CargoTables/MatchSchedule")]`
-   `[[MatchScheduleGame](https://lol.fandom.com/wiki/Special:CargoTables/MatchScheduleGame "Special:CargoTables/MatchScheduleGame")]`

You may also want to join to `[[Tournaments](https://lol.fandom.com/wiki/Special:CargoTables/Tournaments "Special:CargoTables/Tournaments")]`. The field `OverviewPage` is kept constant across these tables.

### Team Queries

-   `[[Teams](https://lol.fandom.com/wiki/Special:CargoTables/Teams "Special:CargoTables/Teams")]` has infobox information about teams.
-   `[[ScoreboardGames](https://lol.fandom.com/wiki/Special:CargoTables/ScoreboardGames "Special:CargoTables/ScoreboardGames")]` contains team stats (gold, kills, etc), `[[ScoreboardPlayers](https://lol.fandom.com/wiki/Special:CargoTables/ScoreboardPlayers "Special:CargoTables/ScoreboardPlayers")]` can be queried for stats of players on a team.
-   `[[SisterTeams](https://lol.fandom.com/wiki/Special:CargoTables/SisterTeams "Special:CargoTables/SisterTeams")]` associates sister teams together.
-   `[[TournamentResults](https://lol.fandom.com/wiki/Special:CargoTables/TournamentResults "Special:CargoTables/TournamentResults")]` can be queried for team results.
-   `[[TournamentRosters](https://lol.fandom.com/wiki/Special:CargoTables/TournamentRosters "Special:CargoTables/TournamentRosters")]` contains the rosters from a given tournament.

### Roster Queries

-   `[[RosterChanges](https://lol.fandom.com/wiki/Special:CargoTables/RosterChanges "Special:CargoTables/RosterChanges")]`
-   `[[Tenures](https://lol.fandom.com/wiki/Special:CargoTables/Tenures "Special:CargoTables/Tenures")]`
-   `[[TenuresUnbroken](https://lol.fandom.com/wiki/Special:CargoTables/TenuresUnbroken "Special:CargoTables/TenuresUnbroken")]`
-   `[[NewsItems](https://lol.fandom.com/wiki/Special:CargoTables/NewsItems "Special:CargoTables/NewsItems")]`

### Picks and Bans Queries

To connect pick and ban data from `[[PicksAndBansS7](https://lol.fandom.com/wiki/Special:CargoTables/PicksAndBansS7 "Special:CargoTables/PicksAndBansS7")]` to data from other tables, such as `[[ScoreboardGames](https://lol.fandom.com/wiki/Special:CargoTables/ScoreboardGames "Special:CargoTables/ScoreboardGames")]`, use the following joins:

-   `PicksAndBansS7.GameId = MatchScheduleGame.GameId`, `MatchScheduleGame.GameId = ScoreboardGames.GameId`

Categories

[Category](https://lol.fandom.com/wiki/Special:Categories "Special:Categories"):

-   [Developer Documentation](https://lol.fandom.com/wiki/Category:Developer_Documentation "Category:Developer Documentation")

Fandom's League of Legends Esports wiki covers tournaments, teams, players, and personalities in League of Legends. Pages that were modified between April 2014 and June 2016 are adapted from information taken from Esportspedia.com. Pages modified between June 2016 and September 2017 are adapted from information taken from EsportsWikis.com. Content is available under [CC BY-SA 3.0](https://www.fandom.com/licensing) unless otherwise noted.

More Fandoms

-   [Fantasy](https://www.fandom.com/fancentral/fantasy)
-   [Sci-fi](https://www.fandom.com/fancentral/sci-fi)

[

**Pick'ems**

Predict LoL esports match winners, brackets, and champions across LEC, LCK, Worlds and more, then climb global, event, and private-group leaderboards.

Try it now

](https://lol.fandom.com/wiki/Special:GameUtility/LeaguepediaPickems)

## 

### Explore properties

-   [Fandom](https://www.fandom.com/)
-   [Fanatical](https://www.fanatical.com/)
-   [GameSpot](https://www.gamespot.com/)
-   [Metacritic](https://www.metacritic.com/)
-   [TV Guide](https://www.tvguide.com/)
-   [Honest Entertainment](https://www.youtube.com/user/screenjunkies)

### Follow Us

-   
-   
-   
-   
-   

### Overview

-   [What is Fandom?](https://www.fandom.com/what-is-fandom)
-   [Essentials](https://www.fandom.com/essentials)
-   [About](https://www.fandom.com/about)
-   [Careers](https://www.fandom.com/careers)
-   [Press](https://www.fandom.com/press)
-   [Contact](https://www.fandom.com/about#contact)
-   [Terms of Use](https://www.fandom.com/terms-of-use)
-   [Privacy Policy](https://www.fandom.com/privacy-policy)
-   [Digital Services Act](https://www.fandom.com/digital-services-act)
-   [Global Sitemap](https://community.fandom.com/Sitemap)
-   [Local Sitemap](https://lol.fandom.com/wiki/Local_Sitemap)
-   

### Community

-   [Community Central](https://community.fandom.com/wiki/Community_Central)
-   [Support](https://fandom.zendesk.com/)
-   [Help](https://community.fandom.com/wiki/Help:Contents)
-   [Accessibility Statement](https://community.fandom.com/wiki/Fandom_accessibility_statement)

### Advertise

-   [Media Kit](https://about.fandom.com/mediakit)
-   [Contact](https://about.fandom.com/mediakit#contact)

### Fandom Apps

Take your favorite fandoms with you and never miss a beat.

-   
-   

Leaguepedia | League of Legends Esports Wiki is a Fandom Games Community.

## We Care About Your Privacy

We and our 751 partner(s) store and access personal data, like browsing data or unique identifiers, on your device. Selecting I Accept enables tracking technologies to support the purposes shown under we and our partners process data to provide. Selecting Reject All or withdrawing your consent will disable them. If trackers are disabled, some content and ads you see may not be as relevant to you. You can resurface this menu to change your choices or withdraw consent at any time by clicking the Manage Preferences link on the bottom of the webpage \[or the floating icon on the bottom-left of the webpage, if applicable\]. Your choices will have effect within our Website. For more details, refer to our Privacy Policy.[Privacy Policy](https://www.fandom.com/privacy-policy)

### We and our partners process data to provide:

Use precise geolocation data. Identify devices based on information actively requested. Store and/or access information on a device. Personalised advertising and content, advertising and content measurement, audience research and services development.
