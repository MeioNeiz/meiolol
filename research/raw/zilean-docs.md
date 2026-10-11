# zilean’s documentation — zilean 0.0.1 documentation

<https://zilean.readthedocs.io/en/main/>

# zilean’s documentation[¶](https://zilean.readthedocs.io/en/main/#zilean-s-documentation "Permalink to this heading")

Contents:

-   [SnapShots class](https://zilean.readthedocs.io/en/main/snapshots.html)
-   [TimelineCrawler class](https://zilean.readthedocs.io/en/main/timeline_crawler.html)
-   [zilean.core](https://zilean.readthedocs.io/en/main/zilean.html)
-   [Developer Doc](https://zilean.readthedocs.io/en/main/developer.html)
    -   [Ways to Contribute](https://zilean.readthedocs.io/en/main/developer.html#ways-to-contribute)
    -   [How to Contribute](https://zilean.readthedocs.io/en/main/developer.html#how-to-contribute)

`zilean` is designed to facilitate data analysis of the Riot [MatchTimelineDto](https://developer.riotgames.com/apis#match-v5/GET_getTimeline). The `MatchTimelineDto` is a powerful object that contains information of a specific [League of Legends](https://leagueoflegends.com/) match at **every minute mark**. Naturally, the `MatchTimelineDto` became an **ideal object for various machine learning tasks**. For example, predicting match results using game statistics before the 16 minute mark.

Different from traditional sports, esports such as League of Legends has an innate advantage with respect to the data collection process. Since every play was conducted digitally, it opened up a huge potential to explore and perform all kinds of data analysis. `zilean` hopes to explore the infinite potentials provided by the [Riot Games API](https://developer.riotgames.com/), **and through the power of computing, make our community a better place.**

GL;HF!

## Demo[¶](https://zilean.readthedocs.io/en/main/#demo "Permalink to this heading")

Here is a quick look of how to do League of Legends data analysis with `zilean`

from zilean import TimelineCrawler, SnapShots, read\_api\_key
import pandas as pd

\# Use the TimelineCrawler to fetch \`MatchTimelineDto\`s
\# from Riot. The \`MatchTimelineDto\`s have game stats
\# at each minute mark.

\# We need a API key to fetch data. See the Riot Developer
\# Portal for more info.
api\_key \= read\_api\_key(you\_api\_key\_here)
\# Crawl 2000 Diamond RANKED\_SOLO\_5x5 timelines from the Korean server.
crawler \= TimelineCrawler(api\_key, region\="kr",
                          tier\="DIAMOND", queue\="RANKED\_SOLO\_5x5")
result \= crawler.crawl(2000, match\_per\_id\=30, file\="results.json")
\# This will take a long time!

\# We will look at the player statistics at 10 and 15 minute mark.
snaps \= SnapShots(result, frames\=\[10, 15\])

\# Store the player statistics using in a pandas DataFrame
player\_stats \= snaps.summary(per\_frame\=True)
data \= pd.DataFrame(player\_stats)

\# Look at the distribution of totalGold difference for \`player 0\` (TOP player)
\# at 15 minutes mark.
sns.displot(x\="totalGold\_0", data\=data\[data\['frame'\] \== 15\], hue\="win")

demo\_1.png[¶](https://zilean.readthedocs.io/en/main/#id1 "Permalink to this image")

Here is an example of some quick machine learning.

\# Do some simple modelling
from sklearn.model\_selection import train\_test\_split
from sklearn.ensemble import RandomForestClassifier

\# Define X and y for training data
train, test \= train\_test\_split(player\_stats, test\_size\=0.33)
X\_train \= train.drop(\["matchId", "win"\], axis\=1)
y\_train \= train\["win"\].astype(int)

\# Build a default random forest classifier
rf \= RandomForestClassifier()
rf.fit(X\_train, y\_train)
y\_fitted \= rf.predict(X\_train)
print(f"Training accuracy: {mean(y\_train \== y\_fitted)}")

## Indices and tables[¶](https://zilean.readthedocs.io/en/main/#indices-and-tables "Permalink to this heading")

-   [Index](https://zilean.readthedocs.io/en/main/genindex.html)
    
-   [Module Index](https://zilean.readthedocs.io/en/main/py-modindex.html)
    
-   [Search Page](https://zilean.readthedocs.io/en/main/search.html)
    

# [zilean](https://zilean.readthedocs.io/en/main/#)

### Navigation

Contents:

-   [SnapShots class](https://zilean.readthedocs.io/en/main/snapshots.html)
-   [TimelineCrawler class](https://zilean.readthedocs.io/en/main/timeline_crawler.html)
-   [zilean.core](https://zilean.readthedocs.io/en/main/zilean.html)
-   [Developer Doc](https://zilean.readthedocs.io/en/main/developer.html)

### Quick search

 

[**Accelerate your agentic workflows.** Set dependencies and environment in Python with Union.ai. **Try free.**](https://server.ethicalads.io/proxy/click/10987/01a128a1-b322-7de0-b3ae-1e1a7bb33a2f/)

_[Ad by EthicalAds](https://www.ethicalads.io/?ref=rtd-sidebar)_   ·   [ℹ️](https://www.ethicalads.io/advertisers/topics/data-science/?ref=rtd-sidebar-buy-ads)

©2022, Zhihao (Johnson) Du. | Powered by [Sphinx 5.0.2](http://sphinx-doc.org/) & [Alabaster 0.7.12](https://github.com/bitprophet/alabaster) | [Page source](https://zilean.readthedocs.io/en/main/_sources/index.rst.txt)
