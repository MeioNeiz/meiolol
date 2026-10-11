Budgets 

 Oracle Cloud Infrastructure Documentation

 All Pages

 Skip to main content 

 Budgets

 Use budgets to set soft limits on your Oracle Cloud Infrastructure spending. You can set alerts on your budget to let you know when you might exceed your budget, and you can view all your budgets and spending from one single place in the Console.

 For example, if you're running a single instance and want to monitor spending on it, you can create a budget on the compartment in which the instance is running. If you don't have any subcompartments in your tenancy, create a budget instead against the root compartment. For more information on creating budgets, see Creating a Budget 
 .

 How Budgets Work

 Budgets are set on tags or on compartments (including the root compartment) to track all spending in a tag or for a compartment and its children.

 All budget alerts are evaluated periodically every 24 hours. To see the last time that a budget was evaluated, open the details for a budget. You can view fields that show the current spend, the forecast, and the % Spent in period field that shows you the time period over which the budget was evaluated. When a budget alert is triggered, the email recipients configured in the budget alert receive an email.

 Budget Concepts

 The following concepts are essential to working with budgets:

 BUDGET 
 You can set either a monthly recurring threshold, or a single non-recurring threshold that you define for your Oracle Cloud Infrastructure spending. Non-recurring budgets support date ranges longer than a month, up to a maximum of one year. Budgets are set on tags or compartments, and track all spending in the tag or compartment, and any child compartments. Note 

 The budget tracks spending in the specified target compartment, but you need to have permissions to manage budgets in the root compartment of the tenancy to create and use budgets.

 ALERT 
 You can define email alerts that get sent out for your budget. You can send a customized email message body with these alerts. Alerts are evaluated periodically every 24 hours, and can be triggered when your actual or forecasted spending hits either a percentage of your budget or a specified set amount. 

 Required IAM Policy

 To use Oracle Cloud Infrastructure, an administrator must be a member of a group granted security access in a policy  by a tenancy administrator. This access is required whether you're using the Console or the REST API with an SDK, CLI, or other tool. If you get a message that you don't have permission or are unauthorized, verify with the tenancy administrator what type of access you have and which compartment  your access works in.

 If you're new to policies, see Getting Started with Policies and Policy Builder Policy Templates . 

 To use budgets, you must be in a group that can use usage-budgets in the tenancy (which is the root compartment), or that can use all resources in the tenancy. All budgets are created in the root compartment, regardless of the compartment they're targeting, so IAM policies that grant budget permissions outside of the root aren't meaningful.

 Accountants can inspect budgets including spend:

 Allow group accountants to inspect usage-budgets in tenancy 

 Accountants can read budgets including spend (same as list):

 Allow group accountants to read usage-budgets in tenancy 

 Accountants can create and edit budgets and alerts rules:

 Allow group accountants to use usage-budgets in tenancy 

 Accountants can create, edit, and delete budgets and alerts rules:

 Allow group accountants to manage usage-budgets in tenancy 

 Applying Tags

 Apply tags to resources to help organize them according to your business needs. You can apply tags when you create a resource, and you can update a resource later to add, revise, or remove tags. For general information about applying tags, see Resource Tags .

 Authentication and Authorization

 Each service in Oracle Cloud Infrastructure integrates with IAM for authentication and authorization, for all interfaces (the Console, SDK or CLI, and REST API).

 An administrator in an organization needs to set up groups  , compartments  , and policies  that control which users can access which services, which resources, and the type of access. For example, the policies control who can create new users, create and manage the cloud network, create instances, create buckets, download objects, and so on. For more information, see Managing Identity Domains . For specific details about writing policies for each of the different services, see Policy Reference . 

 If you're a regular user (not an administrator) who needs to use the Oracle Cloud Infrastructure resources that the company owns, contact an administrator to set up a user ID for you. The administrator can confirm which compartment or compartments you can use.

 Creating Automation for Budgets Using the Events Service

You can create automation based on state changes for Oracle Cloud Infrastructure resources by using event types, rules, and actions. For more information, see Overview of Events . 

 Budgets

 How Budgets Work

 Budget Concepts

 Required IAM Policy

 Applying Tags

 Authentication and Authorization

 Creating Automation for Budgets Using the Events Service

 Copyright © 2026, Oracle and/or its affiliates. 

 About Oracle 

 Contact Us 

 Legal Notices 

 Terms of Use & Privacy 

 Document Conventions