# Create Smart Narrative Summaries - Power BI | Microsoft Learn

<https://learn.microsoft.com/en-us/power-bi/visuals/power-bi-visualization-smart-narrative>

[Skip to main content](https://learn.microsoft.com/en-us/power-bi/visuals/power-bi-visualization-smart-narrative#main) [Skip to Ask Learn chat experience](https://learn.microsoft.com/en-us/power-bi/visuals/power-bi-visualization-smart-narrative#)

We use optional cookies to improve your experience on our websites, such as through social media connections, and to display personalized advertising based on your online activity. If you reject optional cookies, only cookies necessary to provide you the services will be used. You may change your selection by clicking “Manage Cookies” at the bottom of the page. [Privacy Statement](https://go.microsoft.com/fwlink/?LinkId=521839) [Third-Party Cookies](https://aka.ms/3rdpartycookies)

## Microsoft Ignite

November 17–20, 2026

[Register now](https://ignite.microsoft.com/home?wt.mc_ID=msignite26_gmee_corp_np_oo_MSLearnRegLaunch)

[Learn](https://learn.microsoft.com/en-us/)

-   
-   
-   
-   

[Sign in](https://learn.microsoft.com/en-us/power-bi/visuals/power-bi-visualization-smart-narrative#)

[Power BI](https://learn.microsoft.com/en-us/power-bi/)

-   
-   
-   
-   
-   
-   

[Buy now](https://powerbi.microsoft.com/pricing/?pbi_source=pbidocs-purchasing-power-bi-pro) [Open Power BI](https://app.powerbi.com/?pbi_source=learn-header-power-bi)

Search

-   [Power BI report and dashboard creation documentation](https://learn.microsoft.com/en-us/power-bi/create-reports/)
-   Overview
    -   [Power BI reports overview](https://learn.microsoft.com/en-us/power-bi/create-reports/power-bi-reports-overview)
-   Get started
    -   [Tour the report editor](https://learn.microsoft.com/en-us/power-bi/create-reports/service-the-report-editor-take-a-tour)
    -   [Use Report view in Power BI Desktop](https://learn.microsoft.com/en-us/power-bi/create-reports/desktop-report-view)
    -   [Use Report view in the Power BI service](https://learn.microsoft.com/en-us/power-bi/create-reports/service-interact-with-a-report-in-editing-view)
    -   [Paginated reports documentation](https://learn.microsoft.com/en-us/power-bi/paginated-reports/)
    -   Learn with tutorials
    -   Explore samples
-   Understand settings and preferences
-   Design Power BI reports
-   Style your report
-   Visualize your data
    -   [Visualizations overview](https://learn.microsoft.com/en-us/power-bi/visuals/power-bi-visualizations-overview)
    -   [Customize the Visualization pane](https://learn.microsoft.com/en-us/power-bi/visuals/power-bi-report-visualizations)
    -   Work with visuals
    -   Compare trends with charts
    -   Show part-to-whole relationships
    -   Explore distributions and relationships
    -   Display data in tables and matrices
    -   Use cards, KPIs, and gauges
    -   Map your data
    -   Use AI-powered visuals
        -   [Decomposition tree](https://learn.microsoft.com/en-us/power-bi/visuals/power-bi-visualization-decomposition-tree)
        -   [Key influencers](https://learn.microsoft.com/en-us/power-bi/visuals/power-bi-visualization-influencers)
        -   [Smart narrative](https://learn.microsoft.com/en-us/power-bi/visuals/power-bi-visualization-smart-narrative)
        -   [Anomaly detection](https://learn.microsoft.com/en-us/power-bi/visuals/power-bi-visualization-anomaly-detection)
    -   Use scripts
    -   Filter with slicers
    -   Use other visuals
    -   Customize and format visuals
    -   Use advanced visual features
    -   [Get custom visuals](https://learn.microsoft.com/en-us/power-bi/developer/visuals/power-bi-custom-visuals)
-   Create with Copilot
-   Optimize for mobile app
-   Pin to dashboards
-   Track goals with scorecards
-   Resources

1.  [Learn](https://learn.microsoft.com/en-us/)
2.  [Microsoft Fabric](https://learn.microsoft.com/en-us/fabric/)
3.  [Power BI](https://learn.microsoft.com/en-us/power-bi/)

# Create smart narrative summaries

**Applies to:** ✅ Power BI Desktop and Power BI service

The Narrative visual helps you provide a quick text summary of visuals and reports. The Narrative visual offers two modes:

-   **Copilot mode** — Uses AI to generate summaries based on the report data. Requires a Copilot license. The character limit for prompts in Copilot mode is 10,000 characters.
-   **Custom mode** — Lets you write and format the narrative text manually, using dynamic values tied to fields and measures in your data.

This article describes the Custom mode. To learn about the Copilot mode, see [Create a narrative visual with Copilot for Power BI](https://learn.microsoft.com/en-us/power-bi/create-reports/copilot-create-narrative).

Use custom smart narrative summaries in your reports to address key takeaways, to point out trends, and to edit the language and format for a specific audience. When you [add a live Power BI report page to PowerPoint](https://learn.microsoft.com/en-us/power-bi/collaborate-share/office-integration/service-power-bi-powerpoint-add-in-view-present), instead of pasting a screenshot of your report's key takeaways, you can add narratives that update with every refresh. Your audience can use the summaries to understand the data, get to key points faster, and explain the data to others.

This article describes how to add:

-   [A custom smart narrative for a page](https://learn.microsoft.com/en-us/power-bi/visuals/power-bi-visualization-smart-narrative#custom-smart-narrative-for-a-page)
-   [A custom smart narrative for a visual](https://learn.microsoft.com/en-us/power-bi/visuals/power-bi-visualization-smart-narrative#custom-smart-narrative-for-a-visual)
-   [A smart narrative _icon_ to a visual](https://learn.microsoft.com/en-us/power-bi/visuals/power-bi-visualization-smart-narrative#add-a-smart-narrative-icon-to-a-visual)

## Get started

To follow along in Power BI Desktop, download the [sample online-sales scenario dataset](https://github.com/microsoft/powerbi-desktop-samples/blob/main/Monthly%20Desktop%20Blog%20Samples/2020/2020SU09%20Blog%20Demo%20-%20September.pbix).

To follow along in the Power BI service, download the sample. Go to the workspace where you want to save the sample, and select **Upload**. To create a custom smart narrative for a page or for a visual, you need to open the sample in Edit mode.

## Custom smart narrative for a page

On the **Products** page of the report, you see it already has a narrative visual. You can recreate it.

1.  Delete the existing narrative visual.
    
2.  Select the report canvas. In the **Visualizations** pane, select the **Narrative** icon.
    
3.  If Copilot mode opens, select the **Copilot** dropdown, and then select **Custom** to generate an editable summary of the visuals on the page. If Custom mode is already open, continue with the summary.
    
    You see a narrative that's based on all of the visuals on the page. For example, in the sample file, custom smart narratives can automatically generate a summary of the report's visuals that address revenue, website visits, and sales. Power BI automatically analyzes trends to show that revenue and visits both grew. It even calculates growth, which in this case is 72 percent.
    

## Custom smart narrative for a visual

1.  Right-click the visual and select **Summarize**.
2.  You can choose to pin the summary to the report page.

For example, the **Transactions** page in the sample file has a summary of the scatter chart that shows various transactions. Power BI analyzes the data and shows which city or region has the highest revenue per transaction and the highest number of transactions. The custom smart narrative also shows the expected range of values for these metrics. You see that most cities produce less than $45 per transaction and have fewer than 10 transactions.

## Edit the summary

Use the text box commands to edit the custom smart narrative summary or add text. For example, you can make the text bold or change its color.

To customize the summary or add your own insights, use _dynamic values_. Select **Value**, choose a field or measure under **Data**, and select a **Summarization**. You can add a filter, name the value, and select **Save**. For example, to add information about the number of returned items in the sample file, add a value.

You can also format dynamic values. For example, in the sample file, you can show values as currency, specify decimal places, and choose a separator for thousands.

To format a dynamic value, select the value in the summary to see your editing options on the **Review** tab. Or in the text box, next to the value that you want to edit, select the edit button.

You can also use the **Review** tab to review, delete, or reuse previously defined values. Select the plus sign (+) to insert the value into the summary. You can also show automatically generated values by turning on the option at the bottom of the **Review** tab.

Sometimes a hidden-summary symbol appears in the custom smart narrative. It indicates that current data and filters produce no result for the value. A summary is empty when no insights are available. For example, in the sample file's line chart, a summary of high and low values might be empty when the chart's line is flat. But the summary might appear under other conditions. Hidden-summary symbols are visible only when you try to edit a summary.

## Visual interactions

A summary is dynamic. It automatically updates the generated text and dynamic values when you cross-filter. For example, if you select electronics products in the sample file's donut chart, the rest of the report is cross-filtered, and the summary is also cross-filtered to focus on the electronics products.

In this case, the visits and revenues have different trends, so the summary text is updated to reflect the trends. The count-of-returns value that we added is updated to $4196. Empty summaries can be updated when you cross-filter.

You can also do more advanced filtering. For example, in the sample file, look at the visual of trends for multiple products. If you're interested only in a trend for a certain quarter, then select the relevant data points to update the summary for that trend.

There's a limit to the number of summaries that can be generated, so custom narratives pick the most interesting things to summarize about the visual. Custom mode generates up to four summaries per visual and up to 16 per page. The summaries that it generates for a page depend on the location and size of visuals, and it avoids generating the same kind of summaries for different visuals. Therefore, summarizing just the visual can generate more summaries that aren't present while summarizing the whole page.

## Add a smart narrative icon to a visual

You can add an optional icon to the header of a visual that triggers an on-demand summary of the visual contents. Add it for accessibility purposes, to announce results to any assistive technology. You can enable it in the **Format** pane for individual visuals, or add it to your custom theme file for the visual types you choose.

1.  Select a visual, and in the **Format** pane, select **General**.
    
2.  Expand the **Header icons** section, then expand the **Icons** section, and set **Smart narrative** to **On**.
    

When your report readers hover over that visual, they can see and select the **Smart narrative** icon to expose a text explanation of the visual. Unlike a custom smart narrative visual, they can't pin this on-demand summary to the report.

## Considerations and limitations

-   Pinning to a dashboard
-   Using dynamic values and conditional formatting (for example, data bound title)
-   Publish to Web
-   Power BI Report Server
-   On-premises Analysis Services
-   Live Connection to Azure Analysis Services or SQL Server Analysis Services
-   MultiDimensional Analysis Services data sources
-   Key influencers visual with a categorical metric or unsummarized numerical field as 'Analyze' field from a table:
    -   that contains more than one primary key
    -   without a primary key, and measures or aggregates as 'Explain by' fields
-   Map visual with non-aggregated latitude or longitude
-   Multi-row card with more than three categorical fields
-   Cards with non-numeric measures
-   Tables, matrices, R visuals, Python visuals, or custom visuals
-   Summaries of visuals with columns grouped by other columns and for visuals that are built on a data group field
-   Cross-filtering out of a visual
-   Renaming dynamic values or editing automatically generated dynamic values
-   Summaries of visuals that contain on-the-fly calculations like QnA arithmetic, complex measures such as percentage of grand total and measures from extension schemas.
-   [Calculation groups](https://learn.microsoft.com/en-us/analysis-services/tabular-models/calculation-groups)

**Note:** The author created this article with assistance from AI. [Learn more](https://learn.microsoft.com/principles-for-ai-generated-content)

Reading mode disabled

* * *

-   Last updated on 09/29/2026

## In this article

1.  [Get started](https://learn.microsoft.com/en-us/power-bi/visuals/power-bi-visualization-smart-narrative#get-started)
2.  [Custom smart narrative for a page](https://learn.microsoft.com/en-us/power-bi/visuals/power-bi-visualization-smart-narrative#custom-smart-narrative-for-a-page)
3.  [Custom smart narrative for a visual](https://learn.microsoft.com/en-us/power-bi/visuals/power-bi-visualization-smart-narrative#custom-smart-narrative-for-a-visual)
4.  [Edit the summary](https://learn.microsoft.com/en-us/power-bi/visuals/power-bi-visualization-smart-narrative#edit-the-summary)
5.  [Visual interactions](https://learn.microsoft.com/en-us/power-bi/visuals/power-bi-visualization-smart-narrative#visual-interactions)
6.  [Add a smart narrative icon to a visual](https://learn.microsoft.com/en-us/power-bi/visuals/power-bi-visualization-smart-narrative#add-a-smart-narrative-icon-to-a-visual)
7.  [Considerations and limitations](https://learn.microsoft.com/en-us/power-bi/visuals/power-bi-visualization-smart-narrative#considerations-and-limitations)

Was this page helpful?

[English (United States)](https://learn.microsoft.com/en-us/locale?target=https%3A%2F%2Flearn.microsoft.com%2Fen-us%2Fpower-bi%2Fvisuals%2Fpower-bi-visualization-smart-narrative)

[Your Privacy Choices](https://aka.ms/yourcaliforniaprivacychoices)

-   
-   [AI Disclaimer](https://learn.microsoft.com/en-us/principles-for-ai-generated-content)
-   [Previous Versions](https://learn.microsoft.com/en-us/previous-versions/)
-   [Blog](https://techcommunity.microsoft.com/t5/microsoft-learn-blog/bg-p/MicrosoftLearnBlog)
-   [Contribute](https://learn.microsoft.com/en-us/contribute)
-   [Privacy](https://go.microsoft.com/fwlink/?LinkId=521839)
-   [Consumer Health Privacy](https://go.microsoft.com/fwlink/?linkid=2259814)
-   [Terms of Use](https://learn.microsoft.com/en-us/legal/termsofuse)
-   [Trademarks](https://www.microsoft.com/legal/intellectualproperty/Trademarks/)
-   © Microsoft 2026
