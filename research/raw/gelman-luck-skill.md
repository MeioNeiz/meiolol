# Quantifying luck vs. skill in sports | Statistical Modeling, Causal Inference, and Social Science

<https://statmodeling.stat.columbia.edu/2014/06/27/quantifying-luck-vs-skill-sports/>

[Skip to primary content](https://statmodeling.stat.columbia.edu/2014/06/27/quantifying-luck-vs-skill-sports/#content)

# [Statistical Modeling, Causal Inference, and Social Science](https://statmodeling.stat.columbia.edu/)

Search 

### Main menu

-   [Home](https://statmodeling.stat.columbia.edu/)
-   [Authors](https://statmodeling.stat.columbia.edu/authors/)
-   [Blogs We Read](https://statmodeling.stat.columbia.edu/blogs-i-read/)
-   [Books](https://statmodeling.stat.columbia.edu/books/)
-   [Sponsors](https://statmodeling.stat.columbia.edu/sponsors/)

### Post navigation

[(Py, R, Cmd) Stan 2.3 Released](https://statmodeling.stat.columbia.edu/2014/06/26/py-r-cmd-stan-2-3-released/) [Comment of the week](https://statmodeling.stat.columbia.edu/2014/06/27/comment-week/)

# Quantifying luck vs. skill in sports

Posted on [June 27, 2014 9:43 AM](https://statmodeling.stat.columbia.edu/2014/06/27/quantifying-luck-vs-skill-sports/ "9:43 am") by [Andrew](https://statmodeling.stat.columbia.edu/author/andrew/ "View all posts by Andrew")

Trey Causey writes:

> If you’ll permit a bit of a diversion, I was wondering if you’d mind sharing your thoughts on how sabermetrics approaches the measurement of luck vs. skill. Phil Birnbaum and Tom Tango use [the following method](https://blog.philbirnbaum.com/2011/08/tango-method-of-regression-to-mean-kind.html) (which I’ve quoted below).
> 
> It seems to embody the innovative but often non-intuitive way that sabermetrics approaches problems, but something about it feels off to me.

Causey quotes Phil Birnbaum:  

> To go from a record of performance to an estimate of a team’s talent, you have to regress its winning percentage towards the mean. How do you figure out how much to regress?
> 
> Tango has often given these instructions:
> 
> —–
> 
> 1\. First, figure out the standard deviation of team performance. For MLB, for all teams playing at least 160 games up until 2009, that figure is 0.070 (about 11.34 wins per 162 games).
> 
> Second, figure out the theoretical standard deviation of luck over a season, using the binomial approximation to normal. That’s estimated by the formula
> 
> Square root of (p(1-p)/g))
> 
> For baseball, p = .500 (since the average team must be .500), and g = 162. So the SD of luck works out to about 0.039 (6.36 games per season).
> 
> So SD(performance) = 0.070, and SD(luck) = 0.039. Square those numbers to get var(performance) and var(luck). Then, if luck is independent of talent, we get
> 
> var(performance) = var(talent) + var(luck)
> 
> That means var(talent) equals 0.058 squared, so SD(talent) = 0.058.
> 
> 2\. Now, find the number of games for which the SD(luck) equals SD(talent), or 0.058. It turns out that’s about 74 games, because the square root of (p(1-p))/74 is approximately equal to 0.058.
> 
> 3\. That number, 74, is your “answer”. So, now, any time you want to regress a team’s record to the mean, take 74 games of .500 ball (37-37), and add them to the actual performance. The result is your best estimate of the team’s talent.
> 
> For instance, suppose your team goes 100-62. What’s its expected talent? Adjust the record to 137-99. That gives an estimated talent of .581, or 94-68.
> 
> Or, suppose your team starts 2-6. Adjust it to 39-43. That’s an estimated talent of .476, or 77-85.
> 
> —–
> 
> Those estimates seemed reasonable to me, but I often wondered: does this really work? Is it really true that you can add 74 games to a 162 game season, and it’ll work, but you can also add 74 games to an 8 game season, and that’ll work too? Surely you want to add fewer .500 games when your original sample is smaller, no?
> 
> And why always add the exact number of games that makes the talent SD equal to the luck SD? Is it a rule of thumb? Is it a guess? Again, that can’t be the mathematically best way, can it?
> 
> It can, actually. I spent a couple of hours doing some algebra, and it turns out that Tango’s method is exactly right. I was very surprised. Also, I don’t know how Tango figured it out … maybe he use an easier, more intuitive way to figure out that it works than going through a bunch of algebra.
> 
> But I can’t find one, so let me take you through the algebra, if you care. Tango, is there an obvious explanation for why this works, more obvious that what I’ve done?
> 
> ——-
> 
> As I wrote a few paragraphs ago,
> 
> var(overall) = var(talent) + var(luck). \[Call this “equation 1” for later.\]
> 
> Let v^2 =var(overall), and let t^2 = var(talent). Also, let “g” be the number of games.
> 
> From the binomial approximation to normal, we know var(luck) = (.25/g). So
> 
> v = SD(overall)  
> t = SD(talent)  
> sqr(.25/g) = SD(luck)
> 
> Suppose you run a regression on overall outcome vs. talent. The variance of talent is t^2. The variance of overall outcome is v^2. Therefore, we know that talent will explain t^2/v^2 of the variance of outcome, so the r-squared we get out of the regression will be t^2/v^2. That means the correlation coefficient, “r”, will be equal to the square root of that, or t/v.
> 
> There’s a property of regression in general that implies this: If we want to predict talent from outcome, then, if the outcome X is y standard deviations from the mean, talent will be y(t/v) standard deviations from the mean. That’s one of the things that’s true for any regression of two variables.
> 
> So:
> 
> Expected talent = average + (number of SDs outcome is away from the mean) (t/v) \* (SD of talent)
> 
> Expected talent = average + \[(outcome – mean)/SD of outcome\] \[t/v\] \* (SD of talent)
> 
> Expected talent = average + (X – mean)/v \* (t/v) \* t
> 
> Expected talent = average + t^2/v^2 (X – mean)
> 
> That last equation means that when we look at how far the observation is from average, we “keep” t^2/v^2 of the difference, and regress to the mean by the rest. In other words, we regress to the mean by (1 – t^2/v^2), or “(100 \* (1 – t^2/v^2)) percent”.
> 
> Now, if we regress to the mean by (1 – t^2/v^2), that’s the exactly the same as averaging
> 
> — (1 – t^2/v^2) parts average performance, and  
> — (t^2/v^2) parts observed performance.
> 
> For instance, if you’re regressing one-third of the way to the mean, you can do it two ways. You can (a) move from the average to the observation, and then move the other way by 1/3 of the difference, or (b) you can just take an average of two parts original and one part mean.
> 
> But how does that translate, in practical terms, into how many games of average performance we need to add?
> 
> From above, we know that:
> 
> For every t^2/v^2 games of observed performance, we want (1 – t^2/v^2) games of average performance.
> 
> And now a little algebra:
> 
> For every 1 game of observed performance, we want (1 – t^2/v^2)/(t^2/v^2) games of average performance.
> 
> Simplifying gives,
> 
> For every game of observed performance, we want (v^2-t^2)/t^2 games of average performance.
> 
> Multiply by g:
> 
> For every “g” games of observed performance, we want g(v^2-t^2)/t^2 games of average performance.
> 
> But, from equation 1, we know that (v^2-t^2) is just the squared SD of luck, which is .25/g. So,
> 
> For every “g” games of observed performance, we want g(.25/g)/t^2 games of average performance.
> 
> The “g”s cancel, and we get,
> 
> For every “g” games of observed performance, we want .25/t^2 games of average performance.
> 
> And that doesn’t depend on g! So no matter whether you’re regressing a team over 1 game, or 10 games, or 20 games, or 162 games, you can always add \*the same number of average games\* and get the right answer! I wouldn’t have guessed that.
> 
> ——–
> 
> But how many games? Well, it’s (.25/t^2) games.
> 
> For baseball, we calculated earlier now that t = 0.058. So .25/t^2 equals … 74 games. Exactly as Tango said, the number of games we’re adding is exactly the number of games for which SD(luck) equals SD(talent)!
> 
> Is that a coincidence? No, it’s not. It’s the way it has to be. Why? Here’s a semi-intuitive explanation.
> 
> As we saw above, the number of games we have to add does NOT depend on the number of games we started with in the observed W-L record. So, we can pick any number of games. Suppose we just happened to start with 74 games — maybe a team that was 40-34, or something.
> 
> Now, for that team, the SD of its talent is 0.058. And, the SD of its luck is also 0.058. Therefore, if we were to do a regression of talent vs. observed, we would necessarily come up with an r-squared of 0.5 — since the variances of talent and luck are exactly equal, talent explains half of the total variance.
> 
> That means the correlation coefficient, r, is the square root of 0.5, or 1 divided by the square root of 2. For every SD change in performance, we predict 1/sqr(2) SD change in talent. But the SD of talent is exactly 1/sqr(2) times the SD of performance. Multiply those two 1/sqr(2)’s together and you get 1/2, which means for every win change in performance, we predict 1/2 win change in talent.
> 
> That’s another way of saying that we want to regress exactly halfway back to the mean. That, in turn, is the equivalent of averaging one part observation, and one part mean. Since we have 74 games of observation, we need to add 74 games of mean.
> 
> So, in the case of “starting with 74 games of observation,” the answer is, “we need to add 74 games of .500 to properly regress to the mean.”
> 
> However, we showed above that we want to add the \*same\* number of .500 games regardless of how many observed games we started with. Since this case works out to 74 games, \*all\* situations must work out to 74 games.

I responded that “Tom Tango” is a great name, in the “Vance Maverick” or “Larry Lancaster” category. But Causey burst my bubble by informing me that he thinks it’s a pseudonym.

In answer to the original question, they’re doing hierarchical Bayes with a point estimate for the group-level variance. We do something similar in chapter 2 of BDA (the cancer-rate example), just with a Poisson rather than a binomial model. It’s good to see people re-deriving this sort of thing from scratch, and justifying it based on it making sense rather than just because it’s Bayesian. Of course if the model is correct the posterior mean will have lowest mean squared error, so all sorts of different derivations will get you the right answer.

This entry was posted in [Bayesian Statistics](https://statmodeling.stat.columbia.edu/category/bayesian-statistics/), [Sports](https://statmodeling.stat.columbia.edu/category/sports/) by [Andrew](https://statmodeling.stat.columbia.edu/author/andrew/). Bookmark the [permalink](https://statmodeling.stat.columbia.edu/2014/06/27/quantifying-luck-vs-skill-sports/ "Permalink to Quantifying luck vs. skill in sports").

## 29 thoughts on “Quantifying luck vs. skill in sports”

1.  Popeye on [June 27, 2014 11:50 AM at 11:50 am](https://statmodeling.stat.columbia.edu/2014/06/27/quantifying-luck-vs-skill-sports/#comment-175709) said:
    
    In the insurance industry, actuaries employ “credibility theory” to figure out how much weight to give an individual insured’s experience (versus the experience of the insured’s entire group), which is basically the same problem as discussed here. There is a well-known N/(N+K) formula for assigning weight to the individual’s experience, where K is based on the ratio of within-individual and between-individual variance. While some people are able to connect it to Bayesian statistics, most practitioners just have an intuitive understanding that it makes sense, it works, and it is pretty simple to implement.
    
    [Reply ↓](https://statmodeling.stat.columbia.edu/2014/06/27/quantifying-luck-vs-skill-sports/?replytocom=175709#respond)
    
    -    on [June 27, 2014 11:52 AM at 11:52 am](https://statmodeling.stat.columbia.edu/2014/06/27/quantifying-luck-vs-skill-sports/#comment-175710) said:
        
        Meant to include the link to [Wikipedia](https://en.wikipedia.org/wiki/Buhlmann_model) for credibility theory (in particular, the Buhlmann model).
        
        [Reply ↓](https://statmodeling.stat.columbia.edu/2014/06/27/quantifying-luck-vs-skill-sports/?replytocom=175710#respond)
        
2.  Phil Birnbaum on [June 27, 2014 1:12 PM at 1:12 pm](https://statmodeling.stat.columbia.edu/2014/06/27/quantifying-luck-vs-skill-sports/#comment-175720) said:
    
    Three years later, I still haven’t heard an intuitive explanation for why “add sample size X of average performance” works. I have a gut feel, but not a gut \*explanation\*.
    
    [Reply ↓](https://statmodeling.stat.columbia.edu/2014/06/27/quantifying-luck-vs-skill-sports/?replytocom=175720#respond)
    
    -    on [June 27, 2014 5:52 PM at 5:52 pm](https://statmodeling.stat.columbia.edu/2014/06/27/quantifying-luck-vs-skill-sports/#comment-175752) said:
        
        If you have two independent estimates of “the true talent level” (represented as a winning percentage between 0 and 1), the “best” way to weigh them together is in proportion to how precise they are (or in inverse proportion to how imprecise they are, using the average squared error). A very precise estimator gets lots of weight, a very imprecise estimator gets little weight (but it still gets some weight, think of diversification in an investment portfolio).
        
        Here are two estimates of a team’s true talent level — (a) the team’s past record; and (b) .500, the average true talent level across all teams.
        
        The average squared error for (a), assuming constant “true talent” over time, is inversely proportional to the number of games played (just a statistical fact).
        
        The average squared error for (b) is the variance of the true talent level between teams, which is a constant and does not depend on how many games have been played in the sample.
        
        So the ratio of the weights for (a) and (b) should be N/K, where N is the number of games played and K is some constant.
        
        This is the same as assigning weight N to (a) and weight K to (b).
        
        But that’s the same as using the team’s actual record through N games, and then adding K games of .500 ball.
        
        [Reply ↓](https://statmodeling.stat.columbia.edu/2014/06/27/quantifying-luck-vs-skill-sports/?replytocom=175752#respond)
        
        -    on [June 27, 2014 7:19 PM at 7:19 pm](https://statmodeling.stat.columbia.edu/2014/06/27/quantifying-luck-vs-skill-sports/#comment-175761) said:
            
            Thanks! That might work for me … I’ll give it time to sink in.
            
            [Reply ↓](https://statmodeling.stat.columbia.edu/2014/06/27/quantifying-luck-vs-skill-sports/?replytocom=175761#respond)
            
        -    on [June 28, 2014 6:24 AM at 6:24 am](https://statmodeling.stat.columbia.edu/2014/06/27/quantifying-luck-vs-skill-sports/#comment-175819) said:
            
            @Popeye That’s a great explanation.
            
            I often find myself trying to explain this concept to people for whom average squared error isn’t going to help a lot. But anyone who knows baseball gets the following:
            
            Just because someone starts a season with 4 hits in 10 at bats in two games, you’re not going to predict they have a .400 average for the season (assuming they keep coming up to bat). But if they go 400 for 1000 over two seasons, you know you’re looking at the second coming of Ted Williams. If they go 600 for 1000, you lay the groundwork for a new wing in Cooperstown.
            
            Getting back to N and K — the K tells you how variable the population is and thus how many observations N it will take before you believe you have the second coming of Ted Williams on hand.
            
            [Reply ↓](https://statmodeling.stat.columbia.edu/2014/06/27/quantifying-luck-vs-skill-sports/?replytocom=175819#respond)
            
3.  [Noah Motion](https://www.nhsilbert.net/) on [June 27, 2014 1:12 PM at 1:12 pm](https://statmodeling.stat.columbia.edu/2014/06/27/quantifying-luck-vs-skill-sports/#comment-175721) said:
    
    For Birnbaum, Tango, et al., is “luck” synonymous with “noise”? I never understand what people could possibly mean when they invoke “luck” other than “unexplained variance.”
    
    [Reply ↓](https://statmodeling.stat.columbia.edu/2014/06/27/quantifying-luck-vs-skill-sports/?replytocom=175721#respond)
    
    -    on [June 27, 2014 5:16 PM at 5:16 pm](https://statmodeling.stat.columbia.edu/2014/06/27/quantifying-luck-vs-skill-sports/#comment-175746) said:
        
        You are lucky when a random system (unexplained variance) yields a result which is in your favor.
        
        [Reply ↓](https://statmodeling.stat.columbia.edu/2014/06/27/quantifying-luck-vs-skill-sports/?replytocom=175746#respond)
        
        -    on [June 27, 2014 5:35 PM at 5:35 pm](https://statmodeling.stat.columbia.edu/2014/06/27/quantifying-luck-vs-skill-sports/#comment-175748) said:
            
            What about bad luck? Is that just unexplained variance that yields a result not in your favor?
            
            [Reply ↓](https://statmodeling.stat.columbia.edu/2014/06/27/quantifying-luck-vs-skill-sports/?replytocom=175748#respond)
            
4.  Tangotiger on [June 27, 2014 1:59 PM at 1:59 pm](https://statmodeling.stat.columbia.edu/2014/06/27/quantifying-luck-vs-skill-sports/#comment-175724) said:
    
    Noise: the amount of random variation expected based on the number of trials, when centered around a known or estimated true mean.
    
    Signal: the amount of variation observed after removing the noise (see above).
    
    [Reply ↓](https://statmodeling.stat.columbia.edu/2014/06/27/quantifying-luck-vs-skill-sports/?replytocom=175724#respond)
    
    -    on [June 27, 2014 2:05 PM at 2:05 pm](https://statmodeling.stat.columbia.edu/2014/06/27/quantifying-luck-vs-skill-sports/#comment-175726) said:
        
        So, yes?
        
        [Reply ↓](https://statmodeling.stat.columbia.edu/2014/06/27/quantifying-luck-vs-skill-sports/?replytocom=175726#respond)
        
        -    on [June 27, 2014 5:13 PM at 5:13 pm](https://statmodeling.stat.columbia.edu/2014/06/27/quantifying-luck-vs-skill-sports/#comment-175745) said:
            
            You have it a little bit backwards. I believe Tango is using “noise” to refer to “irreducible error”, for example if you try to predict the outcome of a Poisson process with known mean 5 you can’t help but often be wrong since the Poisson process has variance 5. Tango is then attributing all of the remaining variance to differences in the “true skill level” of teams.
            
            In another setting you might try to predict team’s victories with a model, and then deviations between the model and reality would be “unexplained variance” or “noise”. In this case, however, Tango starts with the a model for the noise and then draws conclusions about the distribution of the “true skill level”. So noise is not just “unexplained variance”.
            
            [Reply ↓](https://statmodeling.stat.columbia.edu/2014/06/27/quantifying-luck-vs-skill-sports/?replytocom=175745#respond)
            
            -    on [June 27, 2014 5:46 PM at 5:46 pm](https://statmodeling.stat.columbia.edu/2014/06/27/quantifying-luck-vs-skill-sports/#comment-175751) said:
                
                I’m not sure I understand the distinction you’re making. What’s the difference between irreducible error and unexplained variance? I get that the former in the ‘luck’ case above is based on the variance of a binomial approximation to a normal distribution (i.e., statistical theory), but it’s still unexplained variance, at least if you take the remaining variance as ‘explained’ by skill or talent or whatever. Granted, you could end up with a larger than expected (or smaller than expected, I suppose) amount of unexplained variance if you work the other direction from a model and take the deviations between the model and observation as unexplained variance.
                
                But that difference doesn’t seem (to me) to justify calling one ‘luck’ and the other ‘unexplained variance.’ In both cases, there are sources of variability not being explained.
                
            -    on [June 27, 2014 6:59 PM at 6:59 pm](https://statmodeling.stat.columbia.edu/2014/06/27/quantifying-luck-vs-skill-sports/#comment-175758) said:
                
                Tango’s model is that outcomes = true talent + purely statistical error and he uses this model to make inferences about the distribution of true talent (which of course is a hypothetical construct which cannot be directly observed). In this context I think “luck” is a perfectly acceptable term. Results are the product of skill and luck in the model.
                
                If you predict that income is a function of height and education, on the other hand, then calling unexplained variance “luck” is just sloppy, because unobserved variables like work ethic, gender, work experience, field, etc. are no one’s idea of what luck is.
                
            -    on [June 28, 2014 9:41 AM at 9:41 am](https://statmodeling.stat.columbia.edu/2014/06/27/quantifying-luck-vs-skill-sports/#comment-175833) said:
                
                What are “purely statistical error” and “irreducible error”? These are defined only with respect to a particular model, even if it’s a very simple model, e.g., not a model with height and education predicting income, but just a model of the distribution of income with a location and scale parameter.
                
                Here’s my basic problem: Based on a tiny bit of technical literature and a bunch of pop-science books, I’m willing to accept that quantum mechanics is inherently probabilistic. As far as I can tell, though, everything else in the universe is deterministic.
                
                So, back to baseball. We observe that a given baseball team wins X games and loses 162-X games. There are (deterministic) reasons for this, even if many, perhaps most, of those reasons are not interesting to us. Ultimately, if/when we apply a statistical model to analyze baseball win counts, we’re lumping the “uninteresting” factors into the error part of the model.
                
                These factors don’t have to be uninteresting in any meaningful sense (of “uninteresting”). They might just be difficult to measure, or we might not have the relevant data, or we might assume they’re irrelevant to what we’re analyzing, or whatever. But, ultimately, it’s only a probabilistic system to the extent that (a) we can’t or don’t measure the relevant variables and (b) we can’t build suitable models of the relationships between the variables we can measure. Or maybe it’s better to say that the system isn’t probabilistic, but we can nonetheless make good use of probabilistic tools to make sense of our partial knowledge of the system.
                
                Of course, the same basic issue applies to non-baseball research. The error in my observations of, say, speech-related data, for example, is defined with respect to a model. In principle, I could measure everything relevant and perfectly predict some acoustic property of a token of produced speech, the response time of a word recognition trial, or the confusion of one speech sound with another, etc… Pragmatically, of course, we can’t measure or model \*everything\* that’s relevant in a given analysis (nor would we want to, necessarily, since we typically want results that generalize beyond a given sample).
                
                But the set of things we don’t or can’t measure or model aren’t ‘luck’, they’re just unmeasured and unmodeled. It’s fine that we don’t measure or model (some of) them, but I just can’t make sense of people saying that something is due to ‘chance’ or ‘luck’. It’s all error, and it’s all relative to one or another set of assumptions.
                
                Diaconis, Holmes, & Montgomery’s paper ([pdf](https://statistics.stanford.edu/sites/default/files/2004-32.pdf)) on coin tossing illustrates this point nicely, I think. Coin tosses are the canonical example of a random process, but it turns out they’re not random. If you apply the same force in the same way each time, you get the same result. A coin toss is only random to the extent that we don’t measure or model all of the relevant variables.
                
                Obviously, baseball win-loss records are far more complicated than coin tosses, but the same basic point applies. So, one thing I don’t get about Tango’s model is why the label ‘luck’ is used, but that’s maybe just a not terribly interesting question of semantics. Perhaps more substantive, and therefore interesting, is what basis there is for partitioning the variability in win-loss records in one part “purely statistical error” and one part everything else (= skill).
                
            -    on [June 28, 2014 12:11 PM at 12:11 pm](https://statmodeling.stat.columbia.edu/2014/06/27/quantifying-luck-vs-skill-sports/#comment-175843) said:
                
                A model is a simplification. In reality,for example, teams do not have a constant skill level over time. Teams are more likely to win when their ace is pitcbing. They’re more likely to win at home. They’re more likely to win when their stars aren’t injured and when their opponents aren’t good. In T
                
            -    on [June 28, 2014 12:17 PM at 12:17 pm](https://statmodeling.stat.columbia.edu/2014/06/27/quantifying-luck-vs-skill-sports/#comment-175844) said:
                
                Sorry. Tango’s model also neglects the fact that last year’s record is predictive of this year’s performance, as are a number of other ignored data points.
                
                What is the justification for all these assumptions? Basically that life is short and making these assumptions leads you to a very tractable formula. The payoff from a more complex model probably isn’t worth the effort.
                
            -    on [July 5, 2014 11:52 AM at 11:52 am](https://statmodeling.stat.columbia.edu/2014/06/27/quantifying-luck-vs-skill-sports/#comment-177347) said:
                
                I don’t “ignore” it. I wasn’t trying to come up with the best estimate.
                
                I was INTENTIONALLY limiting myself to a particular dataset. So, once I have my assumption, I work off that.
                
                This is like saying that OBP “ignores” the difference between a walk and a HR. It simply remains agnostic on the issue for the purpose of what it’s trying to do.
                
                So, in me trying to establish how much talent drives the W/L record of a team, I simply focus on the season at hand and establish how much of it is random variation (which is a benign step). And the difference between what we observe and what we expected to observe from random variation is based on the talent spread between teams. That’s all I’m trying to do there.
                
            -    on [June 28, 2014 12:25 PM at 12:25 pm](https://statmodeling.stat.columbia.edu/2014/06/27/quantifying-luck-vs-skill-sports/#comment-175847) said:
                
                We use “luck” to refer to “unexplainable” variance — variance that there’s no real way to eliminate, like a coin toss. (It’s theoretically possible to predict a coin toss better than 50/50, perhaps, but for practical purposes, it’s not.)
                
                I’ve seldom seen sabermetricians try to measure luck by looking at what’s left after subtracting “explained” variance. That would confuse “luck” with “factors we haven’t controlled for”. Rather, we normally use theoretical models. For team wins, we use binomial, assuming every game is a “coin toss” where the coin is weighted according to the team’s overall talent. That is, we assume games are independent and unexplainable, except for the probability of winning.
                
                We cheat a bit by using binomial for a fair coin, even if the team is better or worse than .500 (which, of course, it always is, to some extent). That doesn’t hurt much, as even a .600 team — of pennant-winning quality — has 96% of the binomial variance of a .500 team.
                
            -    on [June 28, 2014 6:42 PM at 6:42 pm](https://statmodeling.stat.columbia.edu/2014/06/27/quantifying-luck-vs-skill-sports/#comment-175884) said:
                
                Thanks for the response. I think I understand better where you’re coming from, and I certainly understand pragmatic simplifications (e.g., using the binomial with p = .5 even for teams with higher winning percentages). I’m still not particularly confident in the distinction between ‘unexplainable’ and ‘unexplained’ variance.
                
                With respect to coin tossing, you might be interested in [this paper](https://statistics.stanford.edu/sites/default/files/2004-32.pdf), which I linked above in response to one of Popeye’s comments.
                
5.  [Rick Schoenberg](https://www.stat.ucla.edu/~frederic) on [June 27, 2014 7:30 PM at 7:30 pm](https://statmodeling.stat.columbia.edu/2014/06/27/quantifying-luck-vs-skill-sports/#comment-175763) said:
    
    The quantification of luck versus skill is a really interesting topic I think. Surprisingly, a lot of books on game theory do not define the words “luck” or “skill”, maybe because it is very hard to do so. I took a crack at it, or at least an aspect of it, in my book on Probability with Texas Holdem Applications, in Chapter 4.4 in case anyone cares. The context is quite different from the baseball one here. I was trying to address, in the case where player A beats player B, how much of player A’s win is attributable to luck and how much is due to skill. I would love to hear thoughts on this.
    
    [Reply ↓](https://statmodeling.stat.columbia.edu/2014/06/27/quantifying-luck-vs-skill-sports/?replytocom=175763#respond)
    
    -    on [June 28, 2014 5:54 AM at 5:54 am](https://statmodeling.stat.columbia.edu/2014/06/27/quantifying-luck-vs-skill-sports/#comment-175817) said:
        
        Rick:
        
        Ok, what’s your definition??
        
        [Reply ↓](https://statmodeling.stat.columbia.edu/2014/06/27/quantifying-luck-vs-skill-sports/?replytocom=175817#respond)
        
        -    on [July 1, 2014 3:26 AM at 3:26 am](https://statmodeling.stat.columbia.edu/2014/06/27/quantifying-luck-vs-skill-sports/#comment-176277) said:
            
            Basically, in poker I define skill as equity gained during the betting rounds and luck as equity gained during the deal of the cards. I then go through a televised twenty-something hand battle between Howard Lederer and Dario Minieri, two players with about as opposite styles as you can get, and try to quantify how much of Lederer’s win was due to luck and how much was due to skill.
            
            You’re probably thinking “Yeah, in poker, you can easily define luck and skill this way, but in other situations it’s not so simple” and I agree, but even in poker there are potential problems with my proposed definition. Anyway, I’d be interested in your thoughts, or those of your readers.  
            Rick
            
            [Reply ↓](https://statmodeling.stat.columbia.edu/2014/06/27/quantifying-luck-vs-skill-sports/?replytocom=176277#respond)
            
            -    on [July 1, 2014 4:48 AM at 4:48 am](https://statmodeling.stat.columbia.edu/2014/06/27/quantifying-luck-vs-skill-sports/#comment-176310) said:
                
                Hi, Rick. Post the excerpt (or mail it to me and I can post it) and we can take a look!
                
            -    on [July 1, 2014 10:39 PM at 10:39 pm](https://statmodeling.stat.columbia.edu/2014/06/27/quantifying-luck-vs-skill-sports/#comment-176536) said:
                
                4.4. Luck and skill in Texas Hold’em.
                
                The determination of whether Texas Hold’em is primarily a game of luck or skill has recently become the subject of intense legal debate. Complicating things is the fact that the terms luck and skill are extremely difficult to define. Surprisingly, rigorous definitions of these terms appear to have eluded most books and journal articles on game theory. A few articles have defined skill in terms of the variance in results among different players, with the idea that players should perform more similarly if a game is mostly based on luck, but their results might differ more substantially if the game is based on skill. Another definition of skill is the extent to which players can improve, and it has been shown that poker does indeed possess a significant amount of this feature (e.g. Dedonno and Detterman, 2008). Others have defined skill in terms of the variation in a given player’s results, since less variation would indicate that fewer repetitions are necessary in order to determine the statistical significance of one’s long-term edge in the game, and hence the sooner one can establish that one’s average profits or losses are primarily due to skill rather than short term luck.
                
                These definitions above are obviously extremely problematic for  various reasons. One is that they rely on the game in  question being played repeatedly before even a crude assessment of  luck or skill could be made. More importantly, there are many contests  of skill wherein the differences between players are small, or where one’s results vary wildly. For instance, in Olympic trials of 100-meter sprints, the differences between finishers are typically quite  small, often just hundredths of a second. This hardly implies that the  results are based on luck. There are also sporting events where an  individual’s results might vary widely from one day to another, e.g. pitching in baseball, but that hardly means that luck plays a major  role.
                
                Regarding the quantification of the amount of luck or skill in a particular game of poker, a possibility might be to define luck as equity  gained when cards are dealt by the dealer, and skill as equity gained  by one’s actions during the betting rounds. (Recall that equity was defined in Section 4.3 as the product cp.) That is, there are several  reasons you might gain equity during a hand:  
                \* The cards dealt by the dealer (whether the players’ hole cards or  the flop, turn, or river) give you a greater chance of winning the  hand in a showdown,  
                \* The size of the pot is increased while your chance to win the hand  in a showdown is better than that of your opponent(s).  
                \* By betting, you get others to fold and thus win a pot that you might otherwise have lost.  
                Certainly, anyone would characterize the first case as luck, unless  perhaps one believes in ESP or time travel. Thus, a possible way to  estimate the skill in poker can be obtained by looking at the  second and third cases above. That is, we may view one’s skill as  being comprised of the equity that one gains during the betting  rounds, whereas luck is equity gained by the deal of the cards. The  nice thing about this is that it is easily quantifiable, and one may  dissect a particular poker game and analyze how much equity each  player gained due to luck or skill.  
                There are obvious objections to this. First, why equity? One’s equity (which is sometimes called express equity) in a pot is defined as one’s expected  return from the pot given no future betting, and the assumption of no  future betting may seem absurdly simplistic and unrealistic. On the other  hand, unlike implied equity which would account for betting on future betting rounds, express equity is unambiguously defined and easy to compute.  Second, situations can occur where one would expect a terrible player  to gain equity during the betting rounds against even the greatest  player in the world, so to attribute such equity gains to skill  might be objectionable. For instance, in heads up Texas Hold’em, if the two players are dealt AA and KK, one would expect the player with KK to  put a great deal of chips in while way behind, and this situation  seems more like bad luck for the player with KK than any deficit in  skill. One possible response to this objection is that skill is difficult to define, and in fact most poker players, probably due to  their huge and fragile egos, tend to chalk up losses for virtually any  reason as being solely due to bad luck. In some sense, anything can be  attributed to luck if one has a general enough definition of the word.  Even if a player does an amazingly skillful poker play, such as  folding a very strong hand because of an observed tell or betting  pattern, one could argue that it was lucky that the player happened  to observe that tell, or even that the player was lucky to have been  born with the ability to discern the tell. On the other hand, situations like the AA versus KK example truly do seem like bad luck.  It is difficult to think of any remedy to this problem. It may be that  the word skill is too strong a word, and that while it may be of  interest to analyze hands in terms of equity, one should instead use  the term equity gained during the betting rounds rather than skill in what follows.  
                Below is an extended example intended to illustrate the division of luck and skill in a given game of Texas Hold’em. The example involves the end of a tournament on Poker After Dark televised during the first week of October 2009. Dario Minieri and Howard Lederer were the final two players. Since this portion of the tournament involves only these two players, and since all hands (or virtually all) were televised, this example provides us with an opportunity to attempt to parse out how much of Lederer’s win was due to skill and how much was due to luck.  
                Technical side note: Before we begin, we need to clarify a couple of potential ambiguities. There is some ambiguity in the definition of equity before the flop,  since the small and big blind have put in different amounts of chips.  The definition used here is that preflop equity is the expected  profit (equity one would have in the pot after calling minus cost),  assuming the big blind and small blind call as well, or the equity one  would have by folding, whichever happens to be greater. For example,  in heads up Texas Hold’em with blinds of 800 and 1600, the preflop equity  for the big blind is 2bp – 1600, and max{2bp – 1600, -800} for the  small blind, where p is the probability of winning the pot in a  showdown, and b is the amount of the big blind. Define increases in  the size of the pot as relative to the big blind, i.e. increasing the  pot size by calling preflop does not count as skill. The probability p of winning the hand in a showdown was obtained using the odds calculator at cardplayer.com, and  the probability of a tie is divided equally among the two players in determining p.
                
                Example 4.4.1. Below are summaries of all 27 hands shown on Poker After Dark in October 2009 between  Dario Minieri and Howard Lederer in the Heads Up portion of the  tournament, with each hand’s equity gains and losses broken down as  luck or skill. Each hand is analyzed from Minieri’s perspective, i.e. “skill -100” refers to 100 chips of equity  gained by Lederer during a betting round. The question we seek to address is: how much of Lederer’s win was due to skill, and how much of it was due to luck?  
                For example, here is a detailed breakdown of hand 4, where the blinds were 800/1600, Minieri was dealt A♣ J♣, Lederer had A♥ 9♥, Minieri raised to 4300 and Lederer called. The flop was 6♣ 10♠ 10♣, Lederer checked, Minieri bet 6500, and Lederer folded.  
                a) Preflop dealing (luck): Minieri +642.08.  Minieri was dealt a 70.065% probability of winning the pot in a showdown, so Minieri’s  increase in equity is 70.065 x 3200 – 1600 = 642.08 chips.  Lederer was dealt a 29.935% probability to win the pot in a showdown, so his increase in equity is 29.935% \* 3200  - 1600 = -642.08 chips.  
                b) Preflop betting (skill): Minieri +1083.51.  The pot was increased to 8600. 8600-3200=5400.  Minieri paid an additional 2700 but had 70.065% x 5400 = 3783.51  additional equity, so Minieri’s expected profit due to betting was 3783.51 –  2700 = 1083.51 chips.  Correspondingly, Lederer’s expected profit due to betting was -1083.51 chips, since  29.935% x 5400 – 2700 = -1083.51.  
                c) Flop dealing (luck): Minieri +1362.67.  After the flop was dealt, Minieri’s probability of winning the 8600 chip pot in a showdown went from 70.065% to 85.91%. So by luck, Minieri increased his equity by (85.91% –  70.065%) x 8600 = +1362.67 chips.  
                d) Flop betting (skill): Minieri +1211.74.  Because of the betting on the flop, Minieri’s equity went from 85.91%  of the 8600 pot to 100% of the pot, so Minieri increased his equity by  (100% – 85.91%)x8600 = 1211.74 chips.  
                So during the hand, by luck, Minieri increased his equity by 642.08 + 1362.67 = 2004.75 chips.  By skill, Minieri increased his equity by 1083.51 + 1211.74 = 2295.25 chips.  Notice that the total = 2004.75 + 2295.25 = 4300, which is the number  of chips Minieri won from Lederer in the hand.
                
                Note that before the heads-up battle began, the broadcast reported that Minieri had 72,000 chips, and  Lederer 48,000. Minieri must have won some chips in hands they did not televise, because the grand  total has Minieri losing about 74,500 chips.
                
                (Blinds 800 and 1600.)
                
                Hand 1. Lederer A♣ 7♠, Minieri 6♠ 6•. Lederer 43.535%, Minieri 56.465%.  Lederer raises to 4300. Minieri raises to 47800. Lederer folds.  
                Luck +206.88.  Skill +4093.12.
                
                Hand 2. Minieri 4♠ 2•, Lederer K♠ 7♥. Minieri 34.36%, Lederer 65.64%.  Minieri raises to 4300, Lederer raises all in for 43500, Minieri folds.  
                Luck -500.48.  Skill -3799.52.
                
                Hand 3. Lederer 6♥ 3•, Minieri A• 9♣. Lederer 34.965%, Minieri 65.035%.  Lederer folds in the small blind.  
                Luck +481.12.  Skill +318.88.
                
                Hand 4. Minieri A♣ J♣, Lederer A♥ 9♥. Minieri 70.065%, Lederer 29.935%.  Minieri raises to 4300, Lederer calls 2700.  Flop 6♣ 10♠ 10♣. Minieri 85.91%, Lederer 14.09%.  Lederer checks, Minieri bets 6500, Lederer folds.  
                 Luck +2004.75.  Skill +2295.25.
                
                Hand 5. Lederer 5♠ 3♥, Minieri 7• 6♠. Lederer 35.765%, Minieri 64.235%.  Lederer folds in the small blind.  
                Luck +455.52.  Skill +344.48.
                
                Hand 6. Minieri K♥ 10♣, Lederer 5¨ 2¨.  Minieri 61.41%, Lederer 38.59%  Minieri raises to 3200, Lederer raises to 9700, Minieri folds.  
                Luck +365.12.  Skill -3565.12
                
                Hand 7. Minieri 10• 7♠, Lederer Q♣ 2♥.  Minieri 43.57%, Lederer 56.43%.  Minieri raises to 3200, Lederer calls 1600.  Flop 8♠ 2♠ Q♥.  Minieri 7.27%, Lederer 92.73%.  Lederer checks, Minieri bets 3200, Lederer calls.  Turn 4•.  Minieri 0%, Lederer 100%.  Lederer checks, Minieri bets 10,000, Lederer calls.  River A♥.  Lederer checks, Minieri checks.    
                Luck -205.76 – 2323.20 – 930.56 = -3459.52.    
                Skill -205.76 – 2734.72 – 10000 = -12940.48.
                
                Hand 8. Lederer 7♣ 2•, Minieri 9♣ 4•.  Minieri 64.28%, Lederer 35.72%.  Lederer folds.    
                Luck +456.96.  Skill +343.04.
                
                Hand 9. Minieri 4♠ 2♣, Lederer 8♥ 7•.  Minieri 34.345%, Lederer 65.655%.  Minieri raises to 3200, Lederer calls 1600.  Flop 3• 9♥ J♥.  Minieri 22.025%, Lederer 77.975%.  Lederer checks, Minieri bets 4800, Lederer folds.    
                Luck -500.96 – 788.48 = -1289.44.  Skill -500.96 + 4990.40 = +4489.44.
                
                Hand 10. Lederer K♠ 5♠, Minieri K♥ 7♣.  Minieri 59.15%, Lederer 40.85%.  Lederer calls 800, Minieri raises to 6400, Lederer folds.    
                Luck +292.80.  Skill +1307.20.
                
                Hand 11. Minieri A♥ 8♥, Lederer 6♥ 3♠.  Minieri 66.85%, Lederer 33.15%.  Minieri raises to 3200. Lederer folds.  
                Luck +539.20.  Skill +1060.80.
                
                Hand 12. Lederer A• 4•. Minieri 7• 3♥.  Minieri 34.655%, Lederer 65.345%.  Lederer raises to 4300, Minieri raises to 11500, Lederer folds.    
                Luck -491.04.  Skill +4791.04.
                
                Hand 13. Minieri 6♣ 3♣, Lederer K♠ 6♠.  Minieri 29.825%, Lederer 70.175%.  Minieri raises to 4800, Lederer calls 3200.  Flop 5♥ J♣ 5♣.  Minieri 47.425%, Lederer 52.575%.  Lederer checks, Minieri bets 6000, Lederer folds.    
                Luck -645.60 + 1689.60 = +1044.  Skill -1291.20 + 5047.20 = +3756.
                
                Hand 14. Lederer 7• 5♠, Minieri 8• 5•.  Minieri 69.44%, Lederer 30.56%.  Lederer calls 800, Minieri checks.  Flop K♥ 10♠ 8♣.  Minieri 94.395%, Lederer 5.605%.  Minieri checks, Lederer bets 1800, Minieri calls.  Turn 7♠.  Minieri 95.45%, Lederer 4.55%.  Minieri checks, Lederer checks.  River 6♥.  Check, check.    
                Luck +622.08 + 798.56 + 71.74 + 309.40 = 1801.78.  Skill 0 + 1598.22 + 0 + 0 = 1598.22.  
                Blinds 1000/2000.
                
                Hand 15. Minieri 9• 5♠, Lederer A♥ 5•.  Minieri 26.755%, Lederer 73.245%.  Minieri calls 1000, Lederer raises to 7000, Minieri raises to 14000,  Lederer calls 7000.  Flop 10♠ Q• 6♥.  Minieri 15.35%, Lederer 84.65%.  Lederer checks, Minieri bets 14000, Lederer folds.    
                Luck -929.80 – 3193.40 = -4123.20.  Skill -5578.80 + 23702 = 18123.20.
                
                Hand 16. Lederer 5♠ 5♥, Minieri A♣ J•.  Minieri 46.085%, Lederer 53.915%.  Lederer calls 1000, Minieri raises to 26800, Lederer calls all in. The board is 3♠ 9♠ K♠ 10• 9•.  
                Luck -156.60 – 24701.56 = -24858.16.  Skill -1941.84.
                
                Hand 17. Minieri K♣ 10♣, Lederer 7• 5•.  Minieri 62.22%, Lederer 37.78%.  Minieri raises to 5000, Lederer calls 3000.  Flop J♠ J• 4♠.  Minieri 69.90%, Lederer 30.10%.  Check check.  Turn 8♠.  Minieri 77.27%, Lederer 22.73%.  Lederer bets 6000, Minieri folds.    
                Luck +488.80 + 768 + 737 = 1993.80.  Skill +733.20 + 0 – 7727 = -6993.80.
                
                Hand 18. Lederer 5♠ 5♣, Minieri 10♠ 6♥.  Minieri 46.12%, Lederer 53.88%.  Lederer calls 1000, Minieri checks.  Flop 7♣ 8♣ Q♥.  Minieri 38.235%, Lederer 61.765%.  Minieri checks, Lederer bets 2000, Minieri calls.  Turn J♥.  Minieri 22.73%, Lederer 77.27%.  Minieri bets 4000, Lederer folds.    
                Luck -155.20 – 315.40 – 1240.40 = -1711.  Skill 0 – 470.60 + 6181.60 = +5711.
                
                Hand 19. Lederer K♥ 5♠, Minieri K♣ 10•.  Minieri 73.175%, Lederer 26.825%.  Lederer raises to 5000, Minieri calls 3000.  Flop J• 8♥ 10♥.  Minieri 92.575%, Lederer 7.425%.  Check, check.  Turn 5•.  Minieri 95.45%, Lederer 4.55%.  Minieri bets 6000, Lederer folds.  
                Luck +927 + 1940 + 287.50 = 3154.50.  Skill +1390.50 + 0 + 455 = 1845.50.
                
                Hand 20. Minieri 7♣ 2♠, Lederer Q♠ 9♠.  Minieri 30.205%, Lederer 69.795%.  Minieri raises to 6000. Lederer calls 4000.  Flop A• A♠ Q•.  Minieri 1.165%, Lederer 98.835%.  Lederer checks, Minieri bets 6000, Lederer calls.  Turn J♣.  Minieri 0%, Lederer 100%.  Lederer checks, Minieri bets 14000, Lederer raises to 35800, Minieri  folds.  Luck -791.80 – 3484.80 – 279.60 = -4556.20.  Skill -1583.60 – 5860.20 – 14000 = -21443.80.
                
                Hand 21. Minieri 10♥ 3•, Lederer Q♥ J♠.  Minieri 30.00%, Lederer 70.00%.  Minieri calls 1000, Lederer checks.  Flop 8♠ 4♥ J♣.  Minieri 4.34%, Lederer 95.66%.  Lederer checks, Minieri bets 2000, Lederer raises to 7500, Minieri  raises to 18500, Lederer raises all-in, Minieri folds.  Luck -800 – 1026.40 = -1826.40.  Skill 0 – 18673.60 = -18673.60.
                
                Hand 22. Lederer A♠ 2•, Minieri 5♣ 3♥.  Minieri 42.345%, Lederer 57.655%.  Lederer calls 1000. Minieri checks.  Flop K♠ 10♣ 3♠.  Minieri 80.10%, Lederer 19.90%.  Check check.  Turn Q♠.  Minieri 65.91%, Lederer 34.09%.  Check, Lederer bets 2000, Minieri folds.    
                Luck -306.20 + 1510.20 – 567.60 = 636.40.  Skill 0 + 0 – 2636.40 = -2636.40.
                
                (Blinds 1500/3000.)
                
                Hand 23. Minieri 7♥ 7♣, Lederer 8• 3•.  Minieri 68.175%, Lederer 31.825%.  Minieri all-in for 21,700, Lederer folds.    
                Luck +1090.50.  Skill +1909.50.
                
                Hand 24. Minieri Q♥ 5♥, Lederer 8• 5•.  Minieri 68.37%, Lederer 31.63%.  Minieri all-in for 26,200, Lederer folds.  
                 Luck +1102.20.  Skill +1897.80.
                
                Hand 25. Lederer 9♣ 3♣, Minieri 5• 2•.  Minieri 40.63%, Lederer 59.37%.  Lederer folds.    
                Luck -562.20.  Skill +2060.20.
                
                Hand 26. Minieri 10♣ 2♠, Lederer 7♣ 7♥.  Minieri 29.04%, Lederer 70.96%.  Minieri folds.  
                Luck -1257.60.  Skill -242.40.
                
                Hand 27. Lederer Q♣ 9♣, Minieri A♣ 5♠.  Minieri 55.37%, Lederer 44.63%.  Lederer all-in for 29,200. Minieri calls.  Board 7♣ 6♣ 10♠ Q♠ 6•.    
                Luck +322.20 – 32336.08 = -32013.88.  Skill +2813.88.
                
                Grand Totals:  Luck -61023.59.  Skill -13478.41.
                
                Overall, although Lederer’s gains were primarily (about 81.9%) due  to luck, Lederer also gained more equity due to skill than  Minieri. On the first 19 hands, Minieri actually gained 20,836.41 in equity due to skill,  and it appeared that Minieri was outplaying Lederer.  On hands 20 and 21, however, Minieri tried two huge unsuccessful bluffs, both  on hands (especially hand 20) where he should probably have strongly suspected  that Lederer would be likely to call, and on those two hands combined,  Minieri lost 40,117.40 in equity due to skill. Although Minieri played  very well on every other hand, all of Minieri’s good plays on other  hands could not overcome the huge loss of skill equity from just  those two hands.
                
                It is important to note that the player who gains the most equity due to skill does not always win. In the first 19 hands of this example, for instance, Minieri gained 20836.41 in equity attributed to skill, but because of bad luck, Minieri actually lost a total of 2800 chips over these same 19 hands. The bad luck Minieri suffered on hand 16 negated most of his gains due to skillful play. A common misconception is that one’s luck will ultimately balance out, i.e. that one’s total good luck will eventually exactly equal one’s total bad luck, but this is not true. Assuming one plays the same game repeatedly and independently, and assuming the expected value of one’s equity due to luck is 0 which seems reasonable, then one’s average equity per hand gained by luck will ultimately converge to zero. This is the law of large numbers, and is discussed further in Section 7.4. It does not imply that one’s total equity gained by luck will converge to zero, however. Potential misconceptions about the laws of large numbers and arguments about possible overemphasis on equity are discussed in Section 7.4.
                
                To conclude this Section, a nice illustration of the potential pitfalls of analyzing a hand purely based on equity is a recent hand from Season 7 of High Stakes Poker. In this hand, with blinds of $400 and $800 plus $100 antes from each of the 8 players, after Bill Klein straddled for $1600, Phil Galfond raised to $3500 with Q♠ 10♥, Robert Croak called in the big blind with A♣ J♣, Klein called with 10♠ 6♠, and the other players folded. The flop came J♠ 9♥ 2♠, giving Croak top pair, Klein a flush draw, and Galfond an open ended straight draw. Croak bet $5500, Klein raised to $17500, and Galfond and Croak called. At this point, it is tempting to compute Klein’s probability of winning the hand by computing the probability of exactly one more spade coming on the turn and river without making a full house for Croak, or the turn and river including two 6s, or a 10 and a 6. This would yield a probability of \[(8 x 35 – 4 – 4) + C(3,2) + 2×3\] ÷ C(43,2) = 281/903 ~ 31.12%, and Klein could also split the pot with a straight if the turn and river were KQ or Q8 or 78, without a spade, which has a probability of \[3×3 + 3×3 + 3×3\] ÷ C(43,2) = 27/903 ~ 2.99%. These seem to be the combinations Klein needs, and one would not expect Klein to win the pot with a random turn and river combination not on this list, and especially not if the turn and river contain a king and a jack with no spades. But look at what actually happened in the hand. The turn was the K♣, giving Galfond a straight, and Croak checked, Klein bet $28000, Galfond raised to $67000, Croak folded, and Klein called. The river was the J♥, Klein bluffed $150000, and Galfond folded, giving Klein the $348,200 pot!
                
6.  Louis on [July 1, 2014 6:07 AM at 6:07 am](https://statmodeling.stat.columbia.edu/2014/06/27/quantifying-luck-vs-skill-sports/#comment-176331) said:
    
    Ben van der Genugten and Peter Borm wrote quite a bit on Poker and the extent to which skill or luck is important. This work is mainly geared towards Dutch regulation but interesting nonetheless.
    
    See:  
    [https://link.springer.com/article/10.1007/s001860400347#page-1](https://link.springer.com/article/10.1007/s001860400347#page-1)
    
    [https://link.springer.com/chapter/10.1007/978-1-4615-4627-6\_3#page-1](https://link.springer.com/chapter/10.1007/978-1-4615-4627-6_3#page-1)
    
    [https://link.springer.com/article/10.1007/BF02579073#page-1](https://link.springer.com/article/10.1007/BF02579073#page-1)
    
    [Reply ↓](https://statmodeling.stat.columbia.edu/2014/06/27/quantifying-luck-vs-skill-sports/?replytocom=176331#respond)
    
7.  Alan McIntire on [July 6, 2014 2:02 PM at 2:02 pm](https://statmodeling.stat.columbia.edu/2014/06/27/quantifying-luck-vs-skill-sports/#comment-177725) said:
    
    I found your article both exciting and fascinating. I have one question though:
    
    Square root of (p(1-p)/g)) works exactly for coin flipping, but the number of games won/lost by each team are NOT independent events, since one team’s loss is automatically another team’s win. I suspect the variance for a league of 8 or 10 coin flip teams, before divisional breakdowns and interleague play, would be somewhat greater than the average variance of 8 or 10 series of 162 coin flips.  
    Should there be a correction for this effect?
    
    [Reply ↓](https://statmodeling.stat.columbia.edu/2014/06/27/quantifying-luck-vs-skill-sports/?replytocom=177725#respond)
    
8.  Pingback: [Luck vs. skill in poker « Statistical Modeling, Causal Inference, and Social Science Statistical Modeling, Causal Inference, and Social Science](https://statmodeling.stat.columbia.edu/2014/08/14/luck-vs-skill-poker/)
    
9.  Michael on [June 4, 2015 8:35 AM at 8:35 am](https://statmodeling.stat.columbia.edu/2014/06/27/quantifying-luck-vs-skill-sports/#comment-220578) said:
    
    Ok, but the variance of the binomial distribution is np(1-p), not p(1-p)/n, no?
    
    [Reply ↓](https://statmodeling.stat.columbia.edu/2014/06/27/quantifying-luck-vs-skill-sports/?replytocom=220578#respond)
    

### Leave a Reply

Your email address will not be published. Required fields are marked \*

Comment \*

Name 

Email 

Website 

-   [Art](https://statmodeling.stat.columbia.edu/category/art/)
-   [Artificial Intelligence](https://statmodeling.stat.columbia.edu/category/ai/)
-   [Bayesian Statistics](https://statmodeling.stat.columbia.edu/category/bayesian-statistics/)
-   [Causal Inference](https://statmodeling.stat.columbia.edu/category/causal-inference/)
-   [Decision Analysis](https://statmodeling.stat.columbia.edu/category/decision-theory/)
-   [Economics](https://statmodeling.stat.columbia.edu/category/economics/)
-   [Jobs](https://statmodeling.stat.columbia.edu/category/jobs/)
-   [Literature](https://statmodeling.stat.columbia.edu/category/literature/)
-   [Miscellaneous Science](https://statmodeling.stat.columbia.edu/category/miscellaneous-science/)
-   [Miscellaneous Statistics](https://statmodeling.stat.columbia.edu/category/miscellaneous-statistics/)
-   [Multilevel Modeling](https://statmodeling.stat.columbia.edu/category/multilevel-modeling/)
-   [Obituaries](https://statmodeling.stat.columbia.edu/category/obituaries/)
-   [Political Science](https://statmodeling.stat.columbia.edu/category/political-science/)
-   [Public Health](https://statmodeling.stat.columbia.edu/category/public-health/)
-   [Sociology](https://statmodeling.stat.columbia.edu/category/sociology/)
-   [Sports](https://statmodeling.stat.columbia.edu/category/sports/)
-   [Stan](https://statmodeling.stat.columbia.edu/category/stan/)
-   [Statistical Computing](https://statmodeling.stat.columbia.edu/category/statistical-computing/)
-   [Statistical Graphics](https://statmodeling.stat.columbia.edu/category/statistical-graphics/)
-   [Teaching](https://statmodeling.stat.columbia.edu/category/teaching/)
-   [Zombies](https://statmodeling.stat.columbia.edu/category/zombies/)

1.  AAAnonymous on [The problem is noise, not N: why increasing the sample size isn’t all that.](https://statmodeling.stat.columbia.edu/2026/10/10/the-problem-is-noise-not-n-why-increasing-the-sample-size-isnt-all-that/#comment-2419621)October 10, 2026 5:29 PM
    
    I don’t understand statistics very well. When numbers and formulas are present I mostly don’t understand things. But I try…
    
2.  Matt Skaggs on [The problem is noise, not N: why increasing the sample size isn’t all that.](https://statmodeling.stat.columbia.edu/2026/10/10/the-problem-is-noise-not-n-why-increasing-the-sample-size-isnt-all-that/#comment-2419620)October 10, 2026 2:35 PM
    
    I'm a little out of my depth on this one but this seems to be an observational approach to something…
    
3.  Jukka on [The problem is noise, not N: why increasing the sample size isn’t all that.](https://statmodeling.stat.columbia.edu/2026/10/10/the-problem-is-noise-not-n-why-increasing-the-sample-size-isnt-all-that/#comment-2419619)October 10, 2026 1:05 PM
    
    So, one of my papers under review has n = 200,000 out of a noisy moving target population of around…
    
4.  Pau on [Getting better causal inferences by using more information (my talk at Stanford this coming Wed)](https://statmodeling.stat.columbia.edu/2026/10/08/getting-better-causal-inferences-by-using-more-information-my-talk-at-stanford-this-coming-wed/#comment-2419618)October 10, 2026 12:55 PM
    
    Is there an available write up of the paper?
    
5.  AAAnonymous on [The problem is noise, not N: why increasing the sample size isn’t all that.](https://statmodeling.stat.columbia.edu/2026/10/10/the-problem-is-noise-not-n-why-increasing-the-sample-size-isnt-all-that/#comment-2419617)October 10, 2026 12:50 PM
    
    The following paper seems relevant for those interested: "Challenging the N-Heuristic: Effect size, not sample size, predicts the replicability of…
    
6.  paul alper on [The problem is noise, not N: why increasing the sample size isn’t all that.](https://statmodeling.stat.columbia.edu/2026/10/10/the-problem-is-noise-not-n-why-increasing-the-sample-size-isnt-all-that/#comment-2419616)October 10, 2026 12:23 PM
    
    My family is on holiday in Mexico City and I am not so I decided to determine in a definitive…
    
7.  Dale Lehman on [Digital twins version 2.0: The skeptics speak up](https://statmodeling.stat.columbia.edu/2026/10/09/digital-twins-version-2-0-the-skeptics-speak-up/#comment-2419613)October 10, 2026 9:36 AM
    
    One of the papers you link to deserves more discussion, I believe. It notes "public opinion surveys may not capture…
    
8.  Jukka on [What’s the deal with the RMET (“the Reading the Mind in the Eyes test”)?](https://statmodeling.stat.columbia.edu/2026/10/08/whats-the-deal-with-the-rmet-the-reading-the-mind-in-the-eyes-test/#comment-2419612)October 10, 2026 5:44 AM
    
    https://www.skeptic.com/article/what-is-it-like-to-be-a-dolphin-i-dont-know-neither-do-you/
    
9.  Olaf Zimmermann on [What’s the deal with the RMET (“the Reading the Mind in the Eyes test”)?](https://statmodeling.stat.columbia.edu/2026/10/08/whats-the-deal-with-the-rmet-the-reading-the-mind-in-the-eyes-test/#comment-2419610)October 9, 2026 11:38 PM
    
    To err is human, ...
    
10.  [Andrew](https://www.stat.columbia.edu/~gelman/) on [Digital twins version 2.0: The skeptics speak up](https://statmodeling.stat.columbia.edu/2026/10/09/digital-twins-version-2-0-the-skeptics-speak-up/#comment-2419609)October 9, 2026 7:29 PM
     
     Matt: Good point about the darts. I've always thought of "dart throws" as a synonym for randomness, but, yeah, some…
     
11.  Matt Skaggs on [Digital twins version 2.0: The skeptics speak up](https://statmodeling.stat.columbia.edu/2026/10/09/digital-twins-version-2-0-the-skeptics-speak-up/#comment-2419608)October 9, 2026 7:25 PM
     
     An expert can throw a dart pretty accurately. My reference to 20 years goes back to Tom Tango's Marcel system.…
     
12.  Alain on [What’s the deal with the RMET (“the Reading the Mind in the Eyes test”)?](https://statmodeling.stat.columbia.edu/2026/10/08/whats-the-deal-with-the-rmet-the-reading-the-mind-in-the-eyes-test/#comment-2419607)October 9, 2026 5:28 PM
     
     You may. It would be more helpful, though, for you to say exactly what you mean instead of posting a…
     
13.  [Andrew](https://www.stat.columbia.edu/~gelman/) on [Digital twins version 2.0: The skeptics speak up](https://statmodeling.stat.columbia.edu/2026/10/09/digital-twins-version-2-0-the-skeptics-speak-up/#comment-2419606)October 9, 2026 4:54 PM
     
     Bob: The usual survey, whether it be for public opinion or public health or marketing, is about change. Something is…
     
14.  [Andrew](https://www.stat.columbia.edu/~gelman/) on [What’s the deal with the RMET (“the Reading the Mind in the Eyes test”)?](https://statmodeling.stat.columbia.edu/2026/10/08/whats-the-deal-with-the-rmet-the-reading-the-mind-in-the-eyes-test/#comment-2419605)October 9, 2026 4:50 PM
     
     OK, so you retract your statement that the person who informed me that I had Tourette's syndrome should be punched?
     
15.  Olaf Zimmermann on [What’s the deal with the RMET (“the Reading the Mind in the Eyes test”)?](https://statmodeling.stat.columbia.edu/2026/10/08/whats-the-deal-with-the-rmet-the-reading-the-mind-in-the-eyes-test/#comment-2419604)October 9, 2026 3:22 PM
     
     https://www.bbc.co.uk/news/articles/crn8wyl4n42yo
     
16.  Olaf Zimmermann on [What’s the deal with the RMET (“the Reading the Mind in the Eyes test”)?](https://statmodeling.stat.columbia.edu/2026/10/08/whats-the-deal-with-the-rmet-the-reading-the-mind-in-the-eyes-test/#comment-2419603)October 9, 2026 3:21 PM
     
     If you think that Freud was silly - well, he wasn't, but he found a way to make money, because…
     
17.  Olaf Zimmermann on [What’s the deal with the RMET (“the Reading the Mind in the Eyes test”)?](https://statmodeling.stat.columbia.edu/2026/10/08/whats-the-deal-with-the-rmet-the-reading-the-mind-in-the-eyes-test/#comment-2419602)October 9, 2026 3:06 PM
     
     May I suggest that you read the entire book before commenting on the merits of the short quote I used?…
     
18.  [Bob Carpenter](https://bob-carpenter.github.io/) on [Digital twins version 2.0: The skeptics speak up](https://statmodeling.stat.columbia.edu/2026/10/09/digital-twins-version-2-0-the-skeptics-speak-up/#comment-2419600)October 9, 2026 2:25 PM
     
     Even though I can see Andrew through my office window, I'll ask this here for everyone's benefit. Andrew---I know you…
     
19.  [Andrew](https://www.stat.columbia.edu/~gelman/) on [Digital twins version 2.0: The skeptics speak up](https://statmodeling.stat.columbia.edu/2026/10/09/digital-twins-version-2-0-the-skeptics-speak-up/#comment-2419599)October 9, 2026 12:54 PM
     
     Matt: I disagree with you regarding individual baseball predictions. Yes, they're noisy, but they're a lot better than dart throws.…
     
20.  Matt Skaggs on [Digital twins version 2.0: The skeptics speak up](https://statmodeling.stat.columbia.edu/2026/10/09/digital-twins-version-2-0-the-skeptics-speak-up/#comment-2419598)October 9, 2026 12:50 PM
     
     " LLMs may do a decent job of predicting population averages for well-represented populations, but they have a long way…
     
21.  Robin Blythe on [Digital twins version 2.0: The skeptics speak up](https://statmodeling.stat.columbia.edu/2026/10/09/digital-twins-version-2-0-the-skeptics-speak-up/#comment-2419597)October 9, 2026 12:24 PM
     
     I worry that this push for "silicon samples" misses a fundamental point of why we do research, and survey/opinion research…
     
22.  [Andrew](https://www.stat.columbia.edu/~gelman/) on [It’s fine to use computer-generated survey responses—if you don’t care about the data anyway!](https://statmodeling.stat.columbia.edu/2026/09/24/junk-polls-and-junk-survey-research-they-go-together-so-well/#comment-2419596)October 9, 2026 11:49 AM
     
     Jessica: Agreed. Your point #2 is similar to my reasoning above, that if the purpose of the survey is to…
     
23.  [Jessica Hullman](https://users.eecs.northwestern.edu/~jhullman/) on [It’s fine to use computer-generated survey responses—if you don’t care about the data anyway!](https://statmodeling.stat.columbia.edu/2026/09/24/junk-polls-and-junk-survey-research-they-go-together-so-well/#comment-2419595)October 9, 2026 11:45 AM
     
     I previously wrote a bit about mixed subjects designs here: https://statmodeling.stat.columbia.edu/2025/06/12/better-and-worse-ways-to-mix-human-and-llm-responses-in-behavioral-research-but-you-still-have-to-figure-what-youre-measuring/ There are some more related papers here at my…
     
24.  [Andrew](https://www.stat.columbia.edu/~gelman/) on [Digital twins version 2.0: The skeptics speak up](https://statmodeling.stat.columbia.edu/2026/10/09/digital-twins-version-2-0-the-skeptics-speak-up/#comment-2419594)October 9, 2026 11:26 AM
     
     I wrote something about this topic last month in the post, It’s fine to use computer-generated survey responses—if you don’t…
     
25.  Alain on [What’s the deal with the RMET (“the Reading the Mind in the Eyes test”)?](https://statmodeling.stat.columbia.edu/2026/10/08/whats-the-deal-with-the-rmet-the-reading-the-mind-in-the-eyes-test/#comment-2419593)October 9, 2026 9:48 AM
     
     I don't think James' point was that classification and individuality can't coexist--it was that classification shouldn't supersede individuality, or, minimally,…
     
26.  somebody on [What’s the deal with the RMET (“the Reading the Mind in the Eyes test”)?](https://statmodeling.stat.columbia.edu/2026/10/08/whats-the-deal-with-the-rmet-the-reading-the-mind-in-the-eyes-test/#comment-2419592)October 9, 2026 9:41 AM
     
     Sure, I'm open to the idea that overdiagnosis is a problem these days. But how could you be so confident…
     
27.  [Benjamin Cowley](http://www.helsinki.fi/hipercog) on [What’s the deal with the RMET (“the Reading the Mind in the Eyes test”)?](https://statmodeling.stat.columbia.edu/2026/10/08/whats-the-deal-with-the-rmet-the-reading-the-mind-in-the-eyes-test/#comment-2419591)October 9, 2026 6:35 AM
     
     The RMET is quite dubious "almost science", if not outright pseudoscience. I've never used it or looked into its literature.…
     
28.  [Andrew](https://www.stat.columbia.edu/~gelman/) on [What’s the deal with the RMET (“the Reading the Mind in the Eyes test”)?](https://statmodeling.stat.columbia.edu/2026/10/08/whats-the-deal-with-the-rmet-the-reading-the-mind-in-the-eyes-test/#comment-2419590)October 8, 2026 10:44 PM
     
     Olaf: I am indeed myself alone. I also have important characteristics I share with others. I'm a parent, I'm a…
     
29.  Olaf Zimmermann on [What’s the deal with the RMET (“the Reading the Mind in the Eyes test”)?](https://statmodeling.stat.columbia.edu/2026/10/08/whats-the-deal-with-the-rmet-the-reading-the-mind-in-the-eyes-test/#comment-2419589)October 8, 2026 10:05 PM
     
     As William James (1902, p.9) beautifully put it: The first thing the intellect does with an object is to class…
     
30.  [Andrew](https://www.stat.columbia.edu/~gelman/) on [Getting better causal inferences by using more information (my talk at Stanford this coming Wed)](https://statmodeling.stat.columbia.edu/2026/10/08/getting-better-causal-inferences-by-using-more-information-my-talk-at-stanford-this-coming-wed/#comment-2419587)October 8, 2026 8:54 PM
     
     I have some colleagues at the Hoover Institution. But I doubt that Niall Ferguson will find the time to come…
     
31.  William on [Getting better causal inferences by using more information (my talk at Stanford this coming Wed)](https://statmodeling.stat.columbia.edu/2026/10/08/getting-better-causal-inferences-by-using-more-information-my-talk-at-stanford-this-coming-wed/#comment-2419586)October 8, 2026 8:44 PM
     
     You gonna go hang out at the Hoover Institution?
     
32.  Student on [What’s the deal with the RMET (“the Reading the Mind in the Eyes test”)?](https://statmodeling.stat.columbia.edu/2026/10/08/whats-the-deal-with-the-rmet-the-reading-the-mind-in-the-eyes-test/#comment-2419584)October 8, 2026 4:49 PM
     
     it's also weird to hide behind anonymitiy to doubt credentials when you can just argue the main points in the…
     
33.  Student on [What’s the deal with the RMET (“the Reading the Mind in the Eyes test”)?](https://statmodeling.stat.columbia.edu/2026/10/08/whats-the-deal-with-the-rmet-the-reading-the-mind-in-the-eyes-test/#comment-2419583)October 8, 2026 4:46 PM
     
     nathan fielder had a good bit about this on the rehearsal i believe. which is where I first heard of…
     
34.  Olaf Zimmermann on [What’s the deal with the RMET (“the Reading the Mind in the Eyes test”)?](https://statmodeling.stat.columbia.edu/2026/10/08/whats-the-deal-with-the-rmet-the-reading-the-mind-in-the-eyes-test/#comment-2419582)October 8, 2026 4:38 PM
     
     @Anonymous Fact Checker Nope, no relation - in future, keep your webintelligence to yourself (that's just a gentle piece of…
     
35.  Kris Hardies on [What’s the deal with the RMET (“the Reading the Mind in the Eyes test”)?](https://statmodeling.stat.columbia.edu/2026/10/08/whats-the-deal-with-the-rmet-the-reading-the-mind-in-the-eyes-test/#comment-2419581)October 8, 2026 4:31 PM
     
     While this test has been widely used, it seems like we shouldn't take it seriously (and it seems unfortunate that…
     
36.  Olaf Zimmermann on [What’s the deal with the RMET (“the Reading the Mind in the Eyes test”)?](https://statmodeling.stat.columbia.edu/2026/10/08/whats-the-deal-with-the-rmet-the-reading-the-mind-in-the-eyes-test/#comment-2419580)October 8, 2026 4:31 PM
     
     I can't thank you enough for your comment.
     
37.  paul alper on [What’s the deal with the RMET (“the Reading the Mind in the Eyes test”)?](https://statmodeling.stat.columbia.edu/2026/10/08/whats-the-deal-with-the-rmet-the-reading-the-mind-in-the-eyes-test/#comment-2419579)October 8, 2026 4:18 PM
     
     I suppose I speak for many on this (sophisticated) blog when I say discerning something by looking into people's eyes…
     
38.  [Andrew](https://www.stat.columbia.edu/~gelman/) on [What’s the deal with the RMET (“the Reading the Mind in the Eyes test”)?](https://statmodeling.stat.columbia.edu/2026/10/08/whats-the-deal-with-the-rmet-the-reading-the-mind-in-the-eyes-test/#comment-2419578)October 8, 2026 4:17 PM
     
     Olaf: The person who told me I had Tourette's syndrome is no longer alive, so you won't be able to…
     
39.  Anonymous Fact Checker on [What’s the deal with the RMET (“the Reading the Mind in the Eyes test”)?](https://statmodeling.stat.columbia.edu/2026/10/08/whats-the-deal-with-the-rmet-the-reading-the-mind-in-the-eyes-test/#comment-2419577)October 8, 2026 3:55 PM
     
     Olaf can perhaps point us to the extensive hands-on clinical research on neuropsychology he has performed in his many years…
     
40.  Alain on [What’s the deal with the RMET (“the Reading the Mind in the Eyes test”)?](https://statmodeling.stat.columbia.edu/2026/10/08/whats-the-deal-with-the-rmet-the-reading-the-mind-in-the-eyes-test/#comment-2419576)October 8, 2026 3:50 PM
     
     Overdiagnosis, if true, does not mean the typology has no supporting statistical evidence, and being annoyed by the appearance of…
     
41.  Olaf Zimmermann on [What’s the deal with the RMET (“the Reading the Mind in the Eyes test”)?](https://statmodeling.stat.columbia.edu/2026/10/08/whats-the-deal-with-the-rmet-the-reading-the-mind-in-the-eyes-test/#comment-2419575)October 8, 2026 3:44 PM
     
     Add-on: Whoever convinced @Andrew that he had Tourette's deserves a slam in the kisser!
     
42.  Jeff on [What’s the deal with the RMET (“the Reading the Mind in the Eyes test”)?](https://statmodeling.stat.columbia.edu/2026/10/08/whats-the-deal-with-the-rmet-the-reading-the-mind-in-the-eyes-test/#comment-2419574)October 8, 2026 3:32 PM
     
     I just tried it and did, um, less well. I don't have any kind of diagnosis but now I'm wondering!
     
43.  Olaf Zimmermann on [What’s the deal with the RMET (“the Reading the Mind in the Eyes test”)?](https://statmodeling.stat.columbia.edu/2026/10/08/whats-the-deal-with-the-rmet-the-reading-the-mind-in-the-eyes-test/#comment-2419573)October 8, 2026 3:31 PM
     
     It is the tendency towards over-diagnosis which soon began to get on my nerves. There are children who are clearly…
     
44.  AAAnonymous on [What’s the deal with the RMET (“the Reading the Mind in the Eyes test”)?](https://statmodeling.stat.columbia.edu/2026/10/08/whats-the-deal-with-the-rmet-the-reading-the-mind-in-the-eyes-test/#comment-2419572)October 8, 2026 3:30 PM
     
     I think there was a moment when I looked into your eyes Where it seemed I was observing something beyond…
     
45.  [Bob Carpenter](https://bob-carpenter.github.io/) on [What’s the deal with the RMET (“the Reading the Mind in the Eyes test”)?](https://statmodeling.stat.columbia.edu/2026/10/08/whats-the-deal-with-the-rmet-the-reading-the-mind-in-the-eyes-test/#comment-2419571)October 8, 2026 2:47 PM
     
     What do you think is idiotic about the neurotypical vs. neuroatypical distinction? There's overwhelming evidence that conditions like autistic spectrum…
     
46.  Olaf Zimmermann on [What’s the deal with the RMET (“the Reading the Mind in the Eyes test”)?](https://statmodeling.stat.columbia.edu/2026/10/08/whats-the-deal-with-the-rmet-the-reading-the-mind-in-the-eyes-test/#comment-2419570)October 8, 2026 2:29 PM
     
     Minor correction: it was supposed to say "when this idiocy about ... began to take hold" &c.
     
47.  [Bob Carpenter](https://bob-carpenter.github.io/) on [Our continuing struggles with the Monster model](https://statmodeling.stat.columbia.edu/2026/10/07/our-unending-struggles-with-the-monster-model/#comment-2419569)October 8, 2026 2:19 PM
     
     There are at least three problems with the original Monster model as formulated in Gelman, Bois, and Jiang's paper. (1)…
     
48.  Olaf Zimmermann on [What’s the deal with the RMET (“the Reading the Mind in the Eyes test”)?](https://statmodeling.stat.columbia.edu/2026/10/08/whats-the-deal-with-the-rmet-the-reading-the-mind-in-the-eyes-test/#comment-2419568)October 8, 2026 2:07 PM
     
     There's the eyes, and then there's the eyebrows (which seem to be in the same position in most of the…
     
49.  Bill Bottenberg on [What’s the deal with the RMET (“the Reading the Mind in the Eyes test”)?](https://statmodeling.stat.columbia.edu/2026/10/08/whats-the-deal-with-the-rmet-the-reading-the-mind-in-the-eyes-test/#comment-2419567)October 8, 2026 1:41 PM
     
     I tried it out thinking I hadn't done it. and got 21 2:36 getting a message that there wasn't enough…
     
50.  Person on [What’s the deal with the RMET (“the Reading the Mind in the Eyes test”)?](https://statmodeling.stat.columbia.edu/2026/10/08/whats-the-deal-with-the-rmet-the-reading-the-mind-in-the-eyes-test/#comment-2419566)October 8, 2026 1:28 PM
     
     This test is actually widely used, and a quick lit search could find lots of articles for anyone interested. Now,…
