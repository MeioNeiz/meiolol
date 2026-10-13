# Andrej Karpathy on X: "Three days ago I left autoresearch tuning nanochat for ~2 days on depth=12 model. It found ~20 changes that improved the validation loss. I tested these changes yesterday and all of them were additive and transferred to larger (depth=24) models. Stacking up all of these chang… / X

<https://x.com/karpathy/status/2031135152349524125>

## Post

# Andrej Karpathy on X: "Three days ago I left autoresearch tuning nanochat for ~2 days on depth=12 model. It found ~20 changes that improved the validation loss. I tested these changes yesterday and all of them were additive and transferred to larger (depth=24) models. Stacking up all of these changes, today I measured that the leaderboard's "Time to GPT-2" drops from 2.02 hours to 1.80 hours (~11% improvement), this will be the new leaderboard entry. So yes, these are real improvements and they make an actual difference. I am mildly surprised that my very first naive attempt already worked this well on top of what I thought was already a fairly manually well-tuned project. This is a first for me because I am very used to doing the iterative optimization of neural network training manually. You come up with ideas, you implement them, you check if they work (better validation loss), you come up with new ideas based on that, you read some papers for inspiration, etc etc. This is the bread and butter of what I do daily for 2 decades. Seeing the agent do this entire workflow end-to-end and all by itself as it worked through approx. 700 changes autonomously is wild. It really looked at the sequence of results of experiments and used that to plan the next ones. It's not novel, ground-breaking "research" (yet), but all the adjustments are "real", I didn't find them manually previously, and they stack up and actually improved nanochat. Among the bigger things e.g.: - It noticed an oversight that my parameterless QKnorm didn't have a scaler multiplier attached, so my attention was too diffuse. The agent found multipliers to sharpen it, pointing to future work. - It found that the Value Embeddings really like regularization and I wasn't applying any (oops). - It found that my banded attention was too conservative (i forgot to tune it). - It found that AdamW betas were all messed up. - It tuned the weight decay schedule. - It tuned the network initialization. This is on top of all the tuning I've already done over a good amount of time. The exact commit is here, from this "round 1" of autoresearch. I am going to kick off "round 2", and in parallel I am looking at how multiple agents can collaborate to unlock parallelism. https://t.co/WAz8aIztKT All LLM frontier labs will do this. It's the final boss battle. It's a lot more complex at scale of course - you don't just have a single train. py file to tune. But doing it is "just engineering" and it's going to work. You spin up a swarm of agents, you have them collaborate to tune smaller models, you promote the most promising ideas to increasingly larger scales, and humans (optionally) contribute on the edges. And more generally, \*any\* metric you care about that is reasonably efficient to evaluate (or that has more efficient proxy metrics such as training a smaller network) can be autoresearched by an agent swarm. It's worth thinking about whether your problem falls into this bucket too."

-   [
    
    Andrej Karpathy
    
    ](https://x.com/karpathy)
    
    [@karpathy](https://x.com/karpathy)
    
    Three days ago I left autoresearch tuning nanochat for ~2 days on depth=12 model. It found ~20 changes that improved the validation loss. I tested these changes yesterday and all of them were additive and transferred to larger (depth=24) models. Stacking up all of these changes, today I measured that the leaderboard's "Time to GPT-2" drops from 2.02 hours to 1.80 hours (~11% improvement), this will be the new leaderboard entry. So yes, these are real improvements and they make an actual difference. I am mildly surprised that my very first naive attempt already worked this well on top of what I thought was already a fairly manually well-tuned project. This is a first for me because I am very used to doing the iterative optimization of neural network training manually. You come up with ideas, you implement them, you check if they work (better validation loss), you come up with new ideas based on that, you read some papers for inspiration, etc etc. This is the bread and butter of what I do daily for 2 decades. Seeing the agent do this entire workflow end-to-end and all by itself as it worked through approx. 700 changes autonomously is wild. It really looked at the sequence of results of experiments and used that to plan the next ones. It's not novel, ground-breaking "research" (yet), but all the adjustments are "real", I didn't find them manually previously, and they stack up and actually improved nanochat. Among the bigger things e.g.: - It noticed an oversight that my parameterless QKnorm didn't have a scaler multiplier attached, so my attention was too diffuse. The agent found multipliers to sharpen it, pointing to future work. - It found that the Value Embeddings really like regularization and I wasn't applying any (oops). - It found that my banded attention was too conservative (i forgot to tune it). - It found that AdamW betas were all messed up. - It tuned the weight decay schedule. - It tuned the network initialization. This is on top of all the tuning I've already done over a good amount of time. The exact commit is here, from this "round 1" of autoresearch. I am going to kick off "round 2", and in parallel I am looking at how multiple agents can collaborate to unlock parallelism. [github.com/karpathy/nanoc…](https://github.com/karpathy/nanochat/commit/6ed7d1d82cee16c2e26f45d559ad3338447a6c1b) All LLM frontier labs will do this. It's the final boss battle. It's a lot more complex at scale of course - you don't just have a single train. py file to tune. But doing it is "just engineering" and it's going to work. You spin up a swarm of agents, you have them collaborate to tune smaller models, you promote the most promising ideas to increasingly larger scales, and humans (optionally) contribute on the edges. And more generally, \*any\* metric you care about that is reasonably efficient to evaluate (or that has more efficient proxy metrics such as training a smaller network) can be autoresearched by an agent swarm. It's worth thinking about whether your problem falls into this bucket too.
    
    [22:28 · 9 Mar 2026](https://x.com/karpathy/status/2031135152349524125)·[
    
    3.7m
    
    Views
    
    ](https://x.com/karpathy/status/2031135152349524125)
    
    [948](https://x.com/compose/post?in_reply_to=2031135152349524125)
    
-   [
    
    Andrej Karpathy
    
    ](https://x.com/karpathy)
    
    [@karpathy](https://x.com/karpathy)
    
    [9 Mar](https://x.com/karpathy/status/2031137476438548874)
    
    oh yeah i should have linked autoresearch probably [github.com/karpathy/autor…](https://github.com/karpathy/autoresearch) (you don't "use it" directly, it's just a recipe/idea - give it to your agent and apply to what you care about.) and the tweet about it that went mini-viral over the weekend with more context 
    
    [
    
    Andrej Karpathy
    
    ](https://x.com/karpathy)
    
    [@karpathy](https://x.com/karpathy)
    
    [7 Mar](https://x.com/karpathy/status/2030371219518931079)
    
    I packaged up the "autoresearch" project into a new self-contained minimal repo if people would like to play over the weekend. It's basically nanochat LLM training core stripped down to a single-GPU, one file version of ~630 lines of code, then: - the human iterates on the 
    
    [92](https://x.com/compose/post?in_reply_to=2031137476438548874)
    
-   [
    
    Elon Musk
    
    ](https://x.com/elonmusk)
    
    [@elonmusk](https://x.com/elonmusk)
    
    [9 Mar](https://x.com/elonmusk/status/2031157079604605076)
    
    We are in the Singularity
    
    [870](https://x.com/compose/post?in_reply_to=2031157079604605076)
    

## See all the replies

[Continue to X](https://x.com/i/jf/onboarding/web?mode=login&redirect_after_login=%2Fkarpathy%2Fstatus%2F2031135152349524125)

## Log in or sign up for X

See what’s happening and join the conversation

[Continue with phone](https://x.com/i/jf/onboarding/web?mode=signup&redirect_after_login=%2Fkarpathy%2Fstatus%2F2031135152349524125)

Continue with Google

Continue with Google

or

[Log in with username or email](https://x.com/i/jf/onboarding/web?mode=login&redirect_after_login=%2Fkarpathy%2Fstatus%2F2031135152349524125)

## Relevant people

[Andrej Karpathy@karpathy](https://x.com/karpathy)[Follow](https://x.com/i/jf/onboarding/web?mode=login&redirect_after_login=%2Fkarpathy)

[Terms](https://x.com/tos)·[Privacy](https://x.com/privacy)·[Cookies](https://support.x.com/articles/20170514)·[Accessibility](https://help.x.com/resources/accessibility)·[Ads Info](https://business.x.com/en/help/troubleshooting/how-twitter-ads-work.html?ref=web-twc-ao-gbl-adsinfo&utm_source=twc&utm_medium=web&utm_campaign=ao&utm_content=adsinfo)·© 2026 X Corp.

Did someone say … cookies?

X and its partners use cookies to provide you with a better, safer and faster service and to support our business. Some cookies are necessary to use our services, improve our services, and make sure they work properly.
