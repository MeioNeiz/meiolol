# League of Legends: Predicting Wins In Champion Select With Machine Learning | by Jihan Yin | Medium

<https://medium.com/@jihan_yin/league-of-legends-predicting-wins-in-champion-select-with-machine-learning-6496523a7ea7>

[

Write

](https://medium.com/m/signin?operation=register&redirect=https%3A%2F%2Fmedium.com%2Fnew-story&source=---top_nav_layout_nav-----------------------new_post_topnav--------------------)

[Sign in](https://medium.com/m/signin?operation=login&redirect=https%3A%2F%2Fmedium.com%2F%40jihan_yin%2Fleague-of-legends-predicting-wins-in-champion-select-with-machine-learning-6496523a7ea7&source=post_page---top_nav_layout_nav-----------------------global_nav--------------------)

1.  [Goals](https://medium.com/?source=post_page-----6496523a7ea7-----------------------------------------#9e6d "Goals")
2.  [Dataset](https://medium.com/?source=post_page-----6496523a7ea7-----------------------------------------#0867 "Dataset")
3.  [Model Selection](https://medium.com/?source=post_page-----6496523a7ea7-----------------------------------------#c6f1 "Model Selection")
4.  [Feature Importance](https://medium.com/?source=post_page-----6496523a7ea7-----------------------------------------#a32e "Feature Importance")
5.  [Potential Biases](https://medium.com/?source=post_page-----6496523a7ea7-----------------------------------------#34ce "Potential Biases")
6.  [Conclusion](https://medium.com/?source=post_page-----6496523a7ea7-----------------------------------------#ef57 "Conclusion")

# League of Legends: Predicting Wins In Champion Select With Machine Learning

[Jihan Yin](https://medium.com/@jihan_yin?source=post_page---byline--6496523a7ea7-----------------------------------------)

6 min read

·

Jan 23, 2018

Press enter or click to view image in full size

As a decently ranked League of Legends player, I’ve always wondered about the importance of dodging in ranked games. If you see that your Riven top is on a five game lose streak, or you get a first time Taliyah mid, should you risk sticking around and playing it out, or should you dodge to save yourself the trouble? I started this project to finally answer that question, and get a better sense of the factors that affect a ranked game.

## **Goals**

-   How accurately can I predict my match’s outcome before it begins?
-   What features in champion select are most important in deciding the outcome of a game?

## **Dataset**

For this project, I worked with 1700 sample matches. Each match was treated as two data points: one for the winning team, and one for the losing team. Through Riot and Champion.gg’s public APIs, I generated 14 features for each player on a team, for 70 features total per team. The first 5 features pertain to the general champion stats picked by the player, while the other 9 are specific to the player’s personal stats. The features were:

1.  **Champion Winrate\*—** The average winrate of the champion.
2.  **Champion Playrate\* —** The average playrate of the champion.
3.  **Champion in-Role Playrate\* —** The average playrate of the champion in the role it was picked for.
4.  **Champion Score\*** — Champion.gg’s assigned performance score for the champion.
5.  **Champion Matchup Winrate\*** — The champion’s average winrate in its lane/role matchup.
6.  **Last 2 Games —** The number of wins the player has on the champion in their 2 most recent games.
7.  **Last 15 Games —** Same as above, but for the last 15 ranked games.
8.  **Games Played With Champion —** The number of games the player has on the champion in their 300 most recent games.
9.  **Ranked Games Played With Champion —** Same as above, but ranked only.
10.  **Champion Mastery —** The mastery points that the player has for the champion.
11.  **Player Level —** The player’s summoner level.
12.  **Player Rank —** The player’s rank, calculated numerically on a range from 0(Bronze V 0LP) to 3000(Challenger)
13.  **Games Played With Role —** The number of games the player has for their role in their 300 most recent games.
14.  **Ranked Games Played With Role —** Same as above, but ranked only.

Whenever there was an off-meta champion pick, some of the champion features would be NaN values, as Champion.gg did not have enough data to have accurate stats for the champion. To account for this, I used two NaN replacement schemes :

1.  Replacing each NaN value with the average value of that feature across all the samples.
2.  Deleting all samples that had NaN values. This results in having less data to work with.

## **Model Selection**

For this project, I compared the effectiveness of deep learning, random forests, support vector machines, gradient boost, and logistic regression in predicting win/losses. Splitting my data into 70% training and 30% test, I used grid search to discover the best hyperparameters for each model. These were my results using scheme one of averaging NaN values:

Press enter or click to view image in full size

Table 1 — Results after training different models with averaging NaN values

These were my results using scheme two of removing NaN values:

Press enter or click to view image in full size

Table 2 — Results after training different models with deleting NaN values

While SVM, neural nets, and logistic regression improves massively from training on non-NaN samples, gradient boost and random forests see almost no difference in effectiveness. Even with the increase in accuracy, the other models’ performance does not match that of gradient boost and random forests. It is also interesting to note that each model performed better on identifying wins rather than losses. As I trained on a dataset with 50% wins and 50% losses, the models may have a higher tolerance to predicting wins.

## Get Jihan Yin’s stories in your inbox

Join Medium for free to get updates from this writer.

Remember me for faster sign in

To see if I had an adequate amount of data, I found each model’s accuracy on increasingly sized subsamples of my overall dataset:

Press enter or click to view image in full size

Table 3 — Graph of model accuracy over size of dataset, with the left graph using scheme 1 and the right graph using scheme 2.

All of the models are plateauing in performance around 2000 samples, so my dataset size of 3400 samples is sizable enough to get an accurate representation of the overall sample space. Furthermore, random forests and gradient boosting models outperform the other models for both NaN replacement schemes, and as such I will be using the two aforementioned models in determining feature importance. It is interesting to note the performance improvement of neural net, SVM, and logistics regression models on samples not containing NaN. Random forests and gradient boosting performed around the same for both schemes, however. Thus, for determining feature importance, I will average NaN values, as this provides more data to work with. All NaN values pertained to champion-specific features, so perhaps the three models with improvement are much more sensitive for those features than random forests and gradient boosting.

## **Feature Importance**

To see the importance of certain subsets of features, I trained the random forests and gradient boosting classifiers on only each subset’s features. I ran twenty samples for each subset, with ten for each model. These were the results:

Press enter or click to view image in full size

Table 4 — Scatterplot of model accuracy over subsets of specific features.

The models seem to work best when trained only on specific player information, doing significantly better than if trained only on champion specific information. This implies that overall champion strength in the meta is not as important to a match as a player’s experience playing on said champion. Furthermore, training on the top role only has the most variation in performance, whereas training on the ad carry role only has significantly worst performance. This implies that the ad carry role has much less impact on a game as the other roles, with top lane having the most variation in effectiveness.

## **Potential Biases**

Almost all of the matches were gathered in the last week of preseason. People may have been taking ranked games less seriously as a result, which could contribute to a loss of accuracy. Also, since Riot’s API doesn’t have a list of recent matches played, I had to crawl match data, starting from my own account as a seed. This resulted in an uneven distribution of data by ranks.

Press enter or click to view image in full size

Table 5 — Pie Graph of each ranked tier’s presence in overall dataset.

From table 5, we can see that the majority of the data is from platinum and gold, with almost no data on bronze, master, and challenger. Because of this, the conclusions of this project are limited to the aforementioned ranks.

## **Conclusion**

I was pretty satisfied with my results, as they more or less met my expectations. Even with tuned hyperparameters, my best model had an accuracy of only 60% in predicting wins/losses. This shows that games aren’t decided in champion select, as a good deal of randomness happens during the match. However, there may be cases where my model predicts a very high percentage(>90) of a loss, and dodging those games may be wise.

I also found that the ADC role has the lowest impact on the game (I’m an ADC main, oh well), whereas all other roles have a somewhat equal impact. Champion picks are much less important than the player that picks them, so don’t think your mid laner is trolling when they pick Hecarim mid.

Press enter or click to view image in full size

_The github for this project: https://github.com/arilato/ranked\_prediction_

_Riot’s public API: https://developer.riotgames.com_

_Champion.gg’s public API: http://api.champion.gg_

[

## Written by Jihan Yin

](https://medium.com/@jihan_yin?source=post_page---post_author_info--6496523a7ea7-----------------------------------------)

[21 followers](https://medium.com/@jihan_yin/followers?source=post_page---post_author_info--6496523a7ea7-----------------------------------------)

·[1 following](https://medium.com/@jihan_yin/following?source=post_page---post_author_info--6496523a7ea7-----------------------------------------)

Second-year computer scientist at UC Berkeley, aspiring machine learning engineer.

## Responses (6)

Write a response

[

What are your thoughts?

](https://medium.com/m/signin?operation=register&redirect=https%3A%2F%2Fmedium.com%2F%40jihan_yin%2Fleague-of-legends-predicting-wins-in-champion-select-with-machine-learning-6496523a7ea7&source=---post_responses--6496523a7ea7---------------------respond_sidebar--------------------)

[

Help

](https://help.medium.com/hc/en-us?source=post_page-----6496523a7ea7-----------------------------------------)

[

Status

](https://status.medium.com/?source=post_page-----6496523a7ea7-----------------------------------------)

[

About

](https://medium.com/about?autoplay=1&source=post_page-----6496523a7ea7-----------------------------------------)

[

Careers

](https://medium.com/jobs-at-medium/work-at-medium-959d1a85284e?source=post_page-----6496523a7ea7-----------------------------------------)

[

Press

](mailto:pressinquiries@medium.com)

[

Blog

](https://blog.medium.com/?source=post_page-----6496523a7ea7-----------------------------------------)

[

Store

](https://medium.com/store)

[

Privacy

](https://policy.medium.com/medium-privacy-policy-f03bf92035c9?source=post_page-----6496523a7ea7-----------------------------------------)

[

Rules

](https://policy.medium.com/medium-rules-30e5502c4eb4?source=post_page-----6496523a7ea7-----------------------------------------)

[

Terms

](https://policy.medium.com/medium-terms-of-service-9db0094a1e0f?source=post_page-----6496523a7ea7-----------------------------------------)

[

Text to speech

](https://speechify.com/medium?source=post_page-----6496523a7ea7-----------------------------------------)

## Be the first to hear about new stories from Jihan Yin

#### Join Medium for free to get updates from Jihan Yin sent right to your inbox.

Your email

Remember me for faster sign in

Already have an account? 

By clicking "Create Account", you accept Medium's [Terms of Service](https://policy.medium.com/medium-terms-of-service-9db0094a1e0f?source=register-----6496523a7ea7-----------------41b5ac988be7----subscribe_to_author--------------------) and [Privacy Policy](https://policy.medium.com/medium-privacy-policy-f03bf92035c9?source=register-----6496523a7ea7-----------------41b5ac988be7----subscribe_to_author--------------------).

This site uses reCaptcha and the Google [Privacy Policy](https://policies.google.com/privacy?source=register-----6496523a7ea7-----------------41b5ac988be7----subscribe_to_author--------------------) and [Terms of Service](https://policies.google.com/terms?source=register-----6496523a7ea7-----------------41b5ac988be7----subscribe_to_author--------------------) apply.
