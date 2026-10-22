# What we found when we tested tools on the world’s least-accessible webpage – Accessibility in government

<https://accessibility.blog.gov.uk/2017/02/24/what-we-found-when-we-tested-tools-on-the-worlds-least-accessible-webpage/>

# Your choice regarding cookies on this site

We use cookies to optimise site functionality and give you the best possible experience.

[Skip to main content](https://accessibility.blog.gov.uk/2017/02/24/what-we-found-when-we-tested-tools-on-the-worlds-least-accessible-webpage/#content)

[Blog](https://www.blog.gov.uk/): [Accessibility in government](https://accessibility.blog.gov.uk/)

Organisations:

[Civil Service](https://www.gov.uk/government/organisations/civil-service)

Search blog

 

# What we found when we tested tools on the world’s least-accessible webpage

Posted by: [Mehmet Duran](https://accessibility.blog.gov.uk/author/mehmet-duran/ "Posts by Mehmet Duran"), Posted on: 24 February 2017 - Categories: [Access needs](https://accessibility.blog.gov.uk/category/access-needs/), [Accessibility](https://accessibility.blog.gov.uk/category/accessibility/), [Code](https://accessibility.blog.gov.uk/category/code/), [Content](https://accessibility.blog.gov.uk/category/content/), [Design](https://accessibility.blog.gov.uk/category/design/), [Testing](https://accessibility.blog.gov.uk/category/testing/)

We recently conducted an audit of automated accessibility testing tools. We built a website full of accessibility failures to test them on. [We've published our findings here](https://alphagov.github.io/accessibility-tool-audit/).

In this blog post we talk about what we did and what we discovered.

## The pros and cons of automated tools

Automated accessibility testing tools can be used to identify accessibility issues on websites. As the name suggests, they are automated tools that can be run on websites and can identify a number of issues.

There are several available, such as [Wave](http://wave.webaim.org/extension/) and [Tenon](https://tenon.io/). Many of them are free and can be accessed online.

Automated tools can be a useful and cheap way of helping you make a service more accessible. They are quick to run and provide immediate feedback. They can be run across lots of pages. Some can be integrated into the build process, so they can identify issues almost as soon as they are created.

But while it can certainly be helpful to run an automated testing tool on a service, it’s important that teams don’t rely on them too heavily. No tool will be able to pick up every accessibility barrier on a website. So just because a tool hasn’t picked up any accessibility issues on a website, doesn’t mean those issues don’t exist.

And even if they do detect a barrier, sometimes the results they give will be inconclusive or require further investigation. Or even just wrong.

A good analogy is to think of a testing tool as like using a spellchecker. It can certainly help you pick up issues, but it should never be used in isolation. To be most useful, automated tools should be combined with manual inspection and user research.

To help people understand the usefulness – and the limitations – of automated tools, and to help people pick a suitable tool, we carried out an audit of some of the most common tools available.

## Choosing the tools to test with

We chose 10 automated testing tools for our audit. We wanted to test the tools that are most commonly used by developers and quality assurance testers. And we wanted to test a large enough number of tools that we would get a variety of results.

We picked all the free tools we were aware of. We also sought suggestions through the cross-government [Accessibility Google Group](https://groups.google.com/a/digital.cabinet-office.gov.uk/forum/?hl=en-GB#!forum/accessibility-community). Here are the tools we tested:

-   [Tenon](https://tenon.io/)
-   [Wave](http://wave.webaim.org/extension/)
-   [HTML Codesniffer](http://squizlabs.github.io/HTML_CodeSniffer/)
-   [aXe](https://www.deque.com/products/axe/)
-   [AChecker](http://achecker.ca/checker/index.php)
-   [Sort Site](https://www.powermapper.com/products/sortsite/)
-   [Google Accessibility Developer Tools](https://chrome.google.com/webstore/detail/accessibility-developer-t/fpkknkljclfencbdbgkenhalefipecmb?hl=en)
-   [The European Internet Inclusion Initiative’s page checker](http://checkers.eiii.eu/)
-   [Asqatasun](http://asqatasun.org/)
-   [Nu HTML Checker](https://validator.w3.org/nu/) (this is an HTML validator – we were interested in seeing what accessibility issues it might pick up)

All of these tools are free to use, apart from Sort Site, which has a free trial. Tenon and Wave also have paid versions if you don’t want to run them in your browser.

## Testing on the world’s least accessible web page

Once we had decided which tools to work with, we needed a web page to test them on.

We needed a page that was riddled with accessibility problems. One that broke all the accessibility rules. One that featured all kinds of accessibility barriers.

So we built one.

A screenshot of 'the world's least accessible website', which we built to test automated tools on

I worked with [Alistair](https://twitter.com/dugboticus?lang=en) and [Richard](https://twitter.com/accessibleweb), my colleagues on the GDS Accessibility team, to create [a web-page full of accessibility failures](https://alphagov.github.io/accessibility-tool-audit/test-cases.html). We refer to it as the world’s least accessible web page.

We filled it with accessibility barriers. At the moment it contains a total of 143 failures grouped into 19 categories.

The failures include things like images without alt attributes, or with the wrong alt attributes, and blank link text. We also put in a number of things that we thought testing tools probably wouldn’t be able to detect, but are also accessibility issues. Things like flashing content that didn’t carry a warning, or plain language not being used in content.

We knew there was no way we could put in every potential accessibility barrier, but we wanted to have enough on the page so that we could adequately test how useful the tools were.

We then ran the tools against the page, to find out how many of the failures they would pick up and how many they would miss.

[You can see our findings in detail here](https://alphagov.github.io/accessibility-tool-audit/index.html). Here are the main things we discovered:

## Lots of the barriers weren’t found by any of the tools

We found that a large proportion of the barriers we created weren’t picked up by any of the 10 tools we tested – 29% in fact.

Of the 143 barriers we created, a total of 42 were missed by all of the tools we tested. The ones that were missed included barriers such as italics used on long sections of text, tables with empty cells and links identified by colour alone.

Even when barriers were found, the error reporting process wasn’t always clear-cut. Sometimes the tools would show a warning or call for manual inspection, without explicitly saying there was an error.

## There is a huge range in the effectiveness of the tools

We also found that some of the tools picked up more errors than others.

If we only count error messages and warnings, then Tenon picked up the most barriers – it found 37% of them. If we also count manual inspection prompts, then Asqatasun was the most effective – it found 41% of the barriers.

At the other end of the range, Google Developer Tools, which is quite a popular tool, only picked up 17% of the barriers.

We found that using tools in combination could help you pick up more barriers, but doing this can be harder and less cost-effective for teams.

## The effectiveness of the tools is just one of the things teams need to consider

We found a big range in terms of the effectiveness of the tools. But, as well as effectiveness, we also know that there are other considerations teams will take into account when deciding whether or not to use a tool, and which tool to use.

We know that the tools have to be easy to set up and run. And the results they give have to be clear and easy to act on. As well as being used by developers they may be used by non-technical people in teams.

There are other technical considerations to take into account too. For example, some tools might not work on password-protected pages. And some might not test on mobile pages.

As part of our work, [we gathered contextual information about the tools](https://alphagov.github.io/accessibility-tool-audit/) to help teams make a decision on which ones suited them best.

## How best to use automated tools

Our opinion of automated testing tools is the same after the audit as it was before. We think they are very useful and should definitely be used by teams to pick up issues. But also that they cannot be relied on, by themselves, to check the accessibility of a website. They are most effective when combined with manual testing.

Our research backs this up. While the tools picked up the majority of the accessibility barriers we created – 71% – there was a large minority that would only have been picked up by manual checking.

For the most effective accessibility testing, we advise teams to combine automated tool testing with manual checking, an accessibility audit and user testing.

We hope that our result pages will help teams pick a tool that best meets their needs. And will also encourage tool creators to better document what the tools can and can't do.

_[Follow Mehmet on Twitter](https://twitter.com/cfq?lang=en) and don't forget to [sign up for email alerts](https://accessibility.blog.gov.uk/subscribe/)._

[How to create content that works well with screen readers](https://accessibility.blog.gov.uk/2017/02/08/advice-for-creating-content-that-works-well-with-screen-readers/)

[How users change colours on websites](https://accessibility.blog.gov.uk/2017/03/27/how-users-change-colours-on-websites/)

## Sharing and comments

### Share this page

-   [X (formerly Twitter)](https://twitter.com/intent/tweet?original_referer&url=https%3A%2F%2Faccessibility.blog.gov.uk%2F2017%2F02%2F24%2Fwhat-we-found-when-we-tested-tools-on-the-worlds-least-accessible-webpage%2F&text=What+we+found+when+we+tested+tools+on+the+world%E2%80%99s+least-accessible+webpage)
-   [Facebook](https://www.facebook.com/sharer/sharer.php?u=https%3A%2F%2Faccessibility.blog.gov.uk%2F2017%2F02%2F24%2Fwhat-we-found-when-we-tested-tools-on-the-worlds-least-accessible-webpage%2F)
-   [LinkedIn](https://www.linkedin.com/shareArticle?url=https%3A%2F%2Faccessibility.blog.gov.uk%2F2017%2F02%2F24%2Fwhat-we-found-when-we-tested-tools-on-the-worlds-least-accessible-webpage%2F)
-   [Email](mailto:?subject=I%20wanted%20to%20share%20this%20post%20with%20you%20from%20Accessibility%20in%20government&body=What%20we%20found%20when%20we%20tested%20tools%20on%20the%20world%E2%80%99s%20least-accessible%20webpage%20https%3A%2F%2Faccessibility.blog.gov.uk%2F2017%2F02%2F24%2Fwhat-we-found-when-we-tested-tools-on-the-worlds-least-accessible-webpage%2F)

### 17 comments

1.  Comment by lucy greco posted on 24 February 2017
    
    is your test page one we can use to help in picking a tool or tools can you share the link
    
    [Link to this comment](https://accessibility.blog.gov.uk/2017/02/24/what-we-found-when-we-tested-tools-on-the-worlds-least-accessible-webpage/#comment-2838)
    
2.  Comment by Caesar Wong posted on 27 February 2017
    
    The 71% figure is surprisingly large, given conventional thinking that the majority of WCAG 2.0 success critieria can't be tested automatically because it requires human evaluation and judgement.
    
    I too, would be curious to see the "world's least-accessible webpage" and see what it includes - maybe if it could be open-sourced so that it can be improved upon, to make a benchmark test of sorts by which we can compare all automated accessibility tools? That would be ace.
    
    [Link to this comment](https://accessibility.blog.gov.uk/2017/02/24/what-we-found-when-we-tested-tools-on-the-worlds-least-accessible-webpage/#comment-2845)
    
    -   Replies to Caesar Wong>
        
        Comment by Caesar Wong posted on 27 February 2017
        
        Ah my bad. It already is open sourced here:  
        [https://alphagov.github.io/accessibility-tool-audit/test-cases.html](https://alphagov.github.io/accessibility-tool-audit/test-cases.html)
        
        [Link to this comment](https://accessibility.blog.gov.uk/2017/02/24/what-we-found-when-we-tested-tools-on-the-worlds-least-accessible-webpage/#comment-2846)
        
    
3.  Comment by Jules posted on 27 February 2017
    
    Could you also add a column with false negatives? Some tools also show errors where they shouldn't.
    
    [Link to this comment](https://accessibility.blog.gov.uk/2017/02/24/what-we-found-when-we-tested-tools-on-the-worlds-least-accessible-webpage/#comment-2848)
    
4.  Comment by Sambhavi and Pina D'intino posted on 27 February 2017
    
    Great work! Your examples are a useful resource for learning accessible coding. Are you planning on doing a similar study with paid automatic  
    test tools such as Deque's, SSB Bart, Paciello, MS Inspector, etc.?
    
    [Link to this comment](https://accessibility.blog.gov.uk/2017/02/24/what-we-found-when-we-tested-tools-on-the-worlds-least-accessible-webpage/#comment-2851)
    
    -   Replies to Sambhavi and Pina D'intino>
        
        Comment by [Anika Henke](https://accessibility.blog.gov.uk/author/anikahenke/) posted on 23 April 2018
        
        We've been asked this a few times. That's why we've updated our repository to specify:  
        "We currently only accept tools which are either free or free to try and which are not based on any tool we have already covered. When it's a paid for tool, it should have a pricing option which is affordable by a small team. It must have a web presence with all important information."
        
        [Link to this comment](https://accessibility.blog.gov.uk/2017/02/24/what-we-found-when-we-tested-tools-on-the-worlds-least-accessible-webpage/#comment-3253)
        
    
5.  Comment by Jon Gunderson posted on 27 February 2017
    
    Other open source (free) web accessibility evaluation tools are:
    
    AInspector Sidebar 1.0  
    [https://addons.mozilla.org/en-US/firefox/addon/ainspector-sidebar/](https://addons.mozilla.org/en-US/firefox/addon/ainspector-sidebar/)
    
    Functional Accessibility Evaluator 2.0  
    [http://fae.disability.illinois.edu](http://fae.disability.illinois.edu/)
    
    I would be interested in how they compare to the other tools on your test pages.
    
    [Link to this comment](https://accessibility.blog.gov.uk/2017/02/24/what-we-found-when-we-tested-tools-on-the-worlds-least-accessible-webpage/#comment-2852)
    
    -   Replies to Jon Gunderson>
        
        Comment by [Anika Henke](https://accessibility.blog.gov.uk/author/anikahenke/) posted on 23 April 2018
        
        We've tested everything in FAE/AInspector and updated the results on 19 December last year. It finds 28% of all barriers, which means it is in an okay medium position.
        
        [Link to this comment](https://accessibility.blog.gov.uk/2017/02/24/what-we-found-when-we-tested-tools-on-the-worlds-least-accessible-webpage/#comment-3250)
        
    
6.  Comment by Wilco Fiers posted on 28 February 2017
    
    I love how this article has brought attention to the strength of accessibility test tools (ATTs). There are however a few points that I think are worth adding to this discussion.
    
    \- There are some major limitations to an approach like this, where a completely unrealistic page is taken and tested for accessibility violations. This isn't the sort of page ATTs are designed to test, so results will skewed because of it. The only real test that I know of for ATTs is to test it on with the technologies you wish to validate. There is a big difference when you are testing a PHP templated HTML 4 site, as compared to an Angular 2 with HTML 5 site. These are the sorts of differences that can significantly change how well an ATT works in any particular situation.
    
    \- This article briefly touches on the idea of false positives, where tools indicate violations that end up not being true violations. Some tools do this a lot more then others. This depends greatly on who is using them. Tools build for automated testing should steer far away from false positives, which will naturally reduce their overall failure count. But tools developed for accessibility experts who can easily spot false positives and reject them, can allow for more false positives. There is a trade off to be made here. The fewer false positives a tool allows, the more false negatives it will get (i.e. violations it will overlook).
    
    \- For any user interested in this sort of thing. The W3C currently has a taskforce dedicated to harmonising and building standards around how accessibility testing is to be done. The Accessibility Conformance Testing Taskforce (which I am co-facilitator of), is looking to make accessibility testing more transparent and develop a common set of rules that can be implemented by any ATT or QA team. You can learn more about this work here: [https://www.w3.org/WAI/GL/task-forces/conformance-testing/](https://www.w3.org/WAI/GL/task-forces/conformance-testing/)
    
    [Link to this comment](https://accessibility.blog.gov.uk/2017/02/24/what-we-found-when-we-tested-tools-on-the-worlds-least-accessible-webpage/#comment-2854)
    
    -   Replies to Wilco Fiers>
        
        Comment by [Anika Henke](https://accessibility.blog.gov.uk/author/anikahenke/) posted on 23 April 2018
        
        When you say "There are some major limitations to an approach like this, where a completely unrealistic page is taken and tested for accessibility violations", on the one hand you are right. Whole complex pages make more realistic test cases.  
        But on the other hand having a page with one specific issue is easier and more reliable to test for. When examples are as isolated as possible, you can get more granular results which you can then compare against each other. That is not easily possible with more complex pages.
        
        The main issue I see with our current approach is that most pages are lacking context. That can lead to some tools behaving differently to what you would expect.  
        I wonder if the ideal example page to be tested should be a page with proper content and structure that is 100% accessible apart from the specific snippet we want to test for.
        
        [Link to this comment](https://accessibility.blog.gov.uk/2017/02/24/what-we-found-when-we-tested-tools-on-the-worlds-least-accessible-webpage/#comment-3254)
        
    
7.  Comment by Bryn Anderson posted on 07 March 2017
    
    At Siteimprove we have developed a free Chrome Extension that we would love to get your feedback on [https://chrome.google.com/webstore/detail/siteimprove-accessibility/efcfolpjihicnikpmhnmphjhhpiclljc](https://chrome.google.com/webstore/detail/siteimprove-accessibility/efcfolpjihicnikpmhnmphjhhpiclljc)
    
    False positives are a massive challenge for ATTs and companies like Siteimprove that provide them. In this regard until full automation can be achieved technically, a key responsibility for vendors is to provide a level of understanding and the resources in order to spot and bridge the gap between automated and manual testing.
    
    Some things are clear cut and can be automated - so why not automate them.
    
    For the rest, their are tips, tricks and elbow grease 🙂
    
    [Link to this comment](https://accessibility.blog.gov.uk/2017/02/24/what-we-found-when-we-tested-tools-on-the-worlds-least-accessible-webpage/#comment-2864)
    
    -   Replies to Bryn Anderson>
        
        Comment by [Anika Henke](https://accessibility.blog.gov.uk/author/anikahenke/) posted on 23 April 2018
        
        We've tested everything in the Siteimprove Chrome extension and updated the results on 13 December last year. It finds 29% of all barriers, which means it is currently sharing the same 5th spot as aXe (which was tested before aXe 3.0 came out).
        
        [Link to this comment](https://accessibility.blog.gov.uk/2017/02/24/what-we-found-when-we-tested-tools-on-the-worlds-least-accessible-webpage/#comment-3251)
        
    
8.  Comment by Cezary Tomczyk posted on 28 June 2017
    
    I have been working on [https://www.aslint.org/](https://www.aslint.org/) and based on that I can only write that writing automated tests is difficult and sometimes even not possible. The world seen from the code perspective is not the same as from our eyes.
    
    Also, as I can see the same rule is tested in a very different ways by every tool. Sometimes the test is very general, sometimes the test is digging a bit more into details. That's why the results are a bit different from every tool.
    
    There is an interesting group [https://auto-wcag.github.io/auto-wcag/pages/rules.html](https://auto-wcag.github.io/auto-wcag/pages/rules.html) that collects WCAG points and trying to describe tests step by step from the code testing perspective. I think this is something that it's worth to work on to find the most optimised way to test a particular scenario.
    
    [Link to this comment](https://accessibility.blog.gov.uk/2017/02/24/what-we-found-when-we-tested-tools-on-the-worlds-least-accessible-webpage/#comment-2974)
    
    -   Replies to Cezary Tomczyk>
        
        Comment by [Anika Henke](https://accessibility.blog.gov.uk/author/anikahenke/) posted on 23 April 2018
        
        Because the tools are so very different, it can sometimes be really difficult to interpret the results in a comparable way. Having some kind of framework around WCAG fails (that tools then adhere to) would help a lot with that. The one you and Wilco linked to looks promising.
        
        By the way, ASLint was the 13th and last tool we've added so far. The results were added on 13 February. It finds 28% of all barriers, which means it is in the same medium position as FAE.
        
        [Link to this comment](https://accessibility.blog.gov.uk/2017/02/24/what-we-found-when-we-tested-tools-on-the-worlds-least-accessible-webpage/#comment-3255)
        
    
9.  Comment by Joy posted on 14 November 2017
    
    Just wondering if you tested any applications that run a reports on websites to determine PDF errors and make suggestions on remediating them?
    
    [Link to this comment](https://accessibility.blog.gov.uk/2017/02/24/what-we-found-when-we-tested-tools-on-the-worlds-least-accessible-webpage/#comment-3121)
    
10.  Comment by Steve Green posted on 08 December 2017
     
     I like the principle of having access to a page that can be used to compare the performance of different tools, but a lot of tests are missing from it at the moment. In particular, most of the serious non-compliances we encounter relate to JavaScript replacements for native form controls, and the page does not contain any examples of these.
     
     Complex components such as date pickers, tabbed interfaces, carousels etc. are another major source of non-compliances but there are no examples of those either.
     
     These are all issues that tools handle poorly, which is why the results are so much better than our experience would suggest. I fear that those figures may give some people an unjustified level of confidence in the tools they are using.
     
     [Link to this comment](https://accessibility.blog.gov.uk/2017/02/24/what-we-found-when-we-tested-tools-on-the-worlds-least-accessible-webpage/#comment-3145)
     
11.  Comment by Chris Houston posted on 29 June 2018
     
     I have used the following tool for HTML & automated accessibility testing, I would be interested to see how it ranks in your test. It's been around for a long time, there is a free version and the paid for license is very reasonable.
     
     [https://www.totalvalidator.com](https://www.totalvalidator.com/)
     
     ( I have no link to the above company, I just use their product. )
     
     [Link to this comment](https://accessibility.blog.gov.uk/2017/02/24/what-we-found-when-we-tested-tools-on-the-worlds-least-accessible-webpage/#comment-3626)
     

## Related content and links

### Accessibility in government

This is for everyone: documenting how we're rebuilding inclusive digital services across the UK Government.  
[Find out more](https://accessibility.blog.gov.uk/about/)

**How accessible is your website?**

Public sector organisations have a legal duty to make websites accessible. Find out how your organisation is impacted at [GOV.UK/accessibility-regulations](https://accessibility.campaign.gov.uk/?utm_source=Blogs&utm_medium=GDS&utm_campaign=access_regs) 

GOV.UK service and product owners need to upload an [accessibility page](https://www.gov.uk/service-manual/helping-people-to-use-your-service/publishing-information-about-your-services-accessibility?utm_source=Insidegov&utm_medium=banner&utm_campaign=access_regs) and publishers need to upload an [accessible documents policy](https://www.gov.uk/government/publications/sample-accessible-document-policy?utm_source=Insidegov&utm_medium=banner&utm_campaign=access_regs).

### Subscribe to Open Notes

[Sign up to get updates direct to your inbox](http://eepurl.com/h9n83j) and stay informed about improvements to digital products and services in government.

### Categories

Categories

### Blogs and resources from GDS

-   [Government Digital Service blog](http://digital.cabinetoffice.gov.uk/)
-   [Government Service Design Manual](https://www.gov.uk/service-manual)
-   [GDS Content Style Guide](https://www.gov.uk/designprinciples/styleguide)
-   [Digital by Default Service Standard](https://www.gov.uk/service-manual/digital-by-default)
-   [GDS Design Principles](https://www.gov.uk/designprinciples)
-   [GDS Design Notes blog](https://designnotes.blog.gov.uk/)

### Sign up and manage updates

-   [Email](https://accessibility.blog.gov.uk/subscribe/)
-   [Atom](https://accessibility.blog.gov.uk/feed/)

### Comments and moderation

[Read our guidelines](https://accessibility.blog.gov.uk/blog-comment-and-moderation-guidelines/)

## Useful links

-   [All GOV.UK blogs](https://www.blog.gov.uk/)
-   [All GOV.UK blog posts](https://www.blog.gov.uk/all-posts/)
-   [GOV.UK](https://www.gov.uk/)
-   [All departments](https://www.gov.uk/government/organisations)
-   [Accessibility statement](https://www.blog.gov.uk/accessibility-statement/)
-   [Cookies](https://www.blog.gov.uk/cookies/)

All content is available under the [Open Government Licence v3.0](https://www.nationalarchives.gov.uk/doc/open-government-licence/version/3/), except where otherwise stated

[© Crown copyright](https://www.nationalarchives.gov.uk/information-management/re-using-public-sector-information/uk-government-licensing-framework/crown-copyright/)
