# League of Legends the affect of Team Composition on Win Rate | League of legends a data analysis

<https://cram678.github.io/league-of-legends-data-analysis/>

[Skip to the content.](https://cram678.github.io/league-of-legends-data-analysis/#content)

# League of Legends the affect of Team Composition on Win Rate

## a data analysis for league of legends

[View on GitHub](https://github.com/cram678/league-of-legends-data-analysis)

# League of Legends the affect of Team Composition on Win Rate

by Marc Rosenberg (cramr@umich.edu)

* * *

## Introduction

League of Legends is a massively popular multiplayer online battle arena game produced by riot games and played by more than 150 million players worldwide making it the most popular multiplayer online battle arena of all time. In league of legends two teams of five players compete to destroy each other’s nexus each of the players chooses a champion from among League of Legends roster of 170 champions. In casual games and even more so in professional games the team composition or the set of 5 champions that a team decides to play is often a deciding factor in who wins or loses a match. The aim of this project is to answer the question: does team composition affect the likelihood of winning a game of winning a game of league of legends?

To begin with we need to slightly redefine the meaning of team composition. Since there are 170 champions currently within league of legends the number of possible team compositions we could have would be 170\*169\*168\*167\*166 or 133,804,114,080 which is far too many. So instead I used official league of legends data to match each champion to their corresponding class of which there are 7 (shown below) meaning that the maximum number of team compositions would be 7^5 or 16,807 which although still alot is far more manageable.

| Class |
| --- |
| Marksman |
| Fighter |
| Slayer |
| Tank |
| Mage |
| Controller |
| Specialist |

The main data set has a total of 115152 rows with every 12 rows representing a single game between two teams each team has 6 rows of data one for each player and one for an overall team summary. In addition I used a second supplementary data set that I created using the league of legends wiki this data set has a list of champions and their corresponding classes.

In the main data set I used the following columns:

| Column | Contents |
| --- | --- |
| pick1 | Champion name |
| pick2 | Champion name |
| pick3 | Champion name |
| pick4 | Champion name |
| pick5 | Champion name |
| result | 1 if win 0 if loss |

The second data set has the following columns:

| Column | Contents |
| --- | --- |
| Champion | Champion name |
| Class | Class name |

* * *

## Data Cleaning and Exploratory Analysis

### Data Cleaning

#### Column and Row Selection

> First we select the relevant columns in the main data frame I selected pick1 pick2 pick3 pick4 pick5 an result in the second data frame no column selection is needed since both columns are important. In the main data frame we select only the summary rows which include all the picks as well as the result.

#### Merging Tables

> I merged the data tables in two different ways, the first way was simply replacing each champion name in pick1 through pick5 with the champion class this is used later in order to compare total team compositions. The second way I merged my datasets was by first counting the number of wins and losses each champion had individually before merging on champion names then grouping by champion class and adding up the wins and losses per class.

#### Win Rate and Data Filtering

> Since the main question of the project relates team composition to win rate I added a win rate calculation to both data frames the first table has win rates by class while the second has win rate by team composition. The second graph that has win rate by team composition has two additional steps as well the first is agregating the team compositions any team composition with the same number of each class is considered the same and added together. The other additional step is filtering by the count of number of team compositions, since some compositions are much more popular than others it is necessary to only consider the compositions where there are enough games which for this project I will consider to be 50.

| compisition | count | wins | win\_rate |
| --- | --- | --- | --- |
| (Fighter, Fighter, Mage, Mage, Marksman) | 70 | 41 | 0.59 |

| Class | Wins | Losses | Win Percentage |
| --- | --- | --- | --- |
| Marksman | 10959 | 10875 | 50.19 |

### Univerate Analysis

The above plot shows the win rate by class the graph is zoomed in to a 3% range around 50% and although there appears to be a large difference between classes it is mostly due to the zoom. The difference between classes is actually relativley small suggesting a relative parity in winrates between classes.

### Bivariate Analysis

The above plot demonstrates the relationship between the number of unique classes in a team composition against their win rate. Although the medians arent very different between the three different types of team composition the teams with 5 different classes have a much more concentrated distribution suggesting that more balanced teams are more consistent.

### Interesting Aggregates

I aggregated the number of games played in the data set with 3, 4, and 5 different champion classes on a team in order to look at the data in the bivariate analysis. As shown below there arent nearly as many games with 3 different champion classes suggesting that the above might not be as accurate for the teams with 3 different champion classes.

| num\_unique\_roles | count |
| --- | --- |
| 3 | 754 |
| 4 | 8566 |
| 5 | 9286 |

### Imputation

No missing values were imputed. However in the dataset of champions associated with their roles some champions were assigned multiple roles by the wiki so I selected one of the roles based on which I believed to be more representative of the champion for example Jhin was labeled as both a Marksman and Controller I felt the Marksman was a much better representation of Jhin so I put him as only a Marksman.

* * *

## Framing a Prediction Problem

My prediction problem answers the following question: given a teams class composition can we predict whether a team will or will not win a match? This is a binary classification problem outputing 1 for a win and 0 for a loss. I will mainly use accuracy to evaluate the model since the classes win and loss are balanced, if class imbalance is observed I may also use AUROC and F1 score. I will only be using the team class compositon since it will be known before the game.

* * *

## Baseline Model

I tried several different models all with the same parameters those being the classes used for picks 1 through 5 which was nominal data as well as the number of unique roles on a team which was quantitative data and used those features to attempt to predict the result (1 for a win 0 for a loss). I tried several different models all with very similar results of an accuracy extremely close to .5 my attempt with gradient boosting for example had an accuracy of .516 while my attempt with SVM had an accuracy of .515. Due to the accuracy being so close to .5 I dont believe any of the models I tried are currently good models since they are barely better than random chance. This might suggest that team composition has little impact on game outcome.

* * *

## Final Model

My final model used a total of 26 parameters where my baseline model only used 6. The first change I made to my parameters was instead of using classes for each pick I used the actual champion names, I decided to do this since unlike in my exploratory analysis where I may have had to analyze my data as an entire team compisition the models used in this section don’t have a problem with that and I figured the granularity might help the model. I kept the number of unique roles column the same, but then added 7 columns to represent how many of each class a team had. I thought this could help my model since certain roles might be stronger than others or having more than a certain threshold of a role could be bad. For example generally having three marksman on a team could be bad since a team likely wouldnt be able to survive long due to marksmans low health pools. Finally I decided to add all of those columns except for the opponent the team was facing I think this was likely the most impactful change since a good team composition is often dependant on the team composition it is playing against.

I tested several different types of models but in the end decided to go with an SVM model since on my first pass through of models it achieved an accuracy of .55 much better than my baseline model. I then decided to test various hyper parameters for my SVM model I used grid search to test the following parameters:

```
param_grid = {
    "classifier__C": [0.1, 1, 3, 5, 10],
    "classifier__gamma": [0.01, 0.1, 1, 'scale', 'auto'],
    "classifier__kernel": ["rbf"]
}
```

I found that the best parameters were actual the default parameters with an accuracy of .55 which significantly improved on the .51 accuracy from the baseline model.

[league-of-legends-data-analysis](https://github.com/cram678/league-of-legends-data-analysis) is maintained by [cram678](https://github.com/cram678). This page was generated by [GitHub Pages](https://pages.github.com/).
