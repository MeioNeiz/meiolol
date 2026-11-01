# [JENKINS-29252] 'Estimated remaining time' should become 'Overdue by' when the ETA is negative - Jenkins Jira

<https://issues.jenkins.io/browse/JENKINS-29252>

[Log in](https://issues.jenkins.io/login.jsp?os_destination=%2Fbrowse%2FJENKINS-29252)[Skip to main content](https://issues.jenkins.io/browse/JENKINS-29252#main)[Skip to sidebar](https://issues.jenkins.io/browse/JENKINS-29252#sidebar)

-   [Dashboards](https://issues.jenkins.io/secure/Dashboard.jspa "View and manage your dashboards")
-   [Projects](https://issues.jenkins.io/secure/BrowseProjects.jspa "View recent projects and browse a list of projects")
-   [Issues](https://issues.jenkins.io/issues/ "Search for issues and view recent issues")

-   [Give feedback to Atlassian](https://issues.jenkins.io/browse/JENKINS-29252#)
-   [Help](https://issues.jenkins.io/secure/ViewKeyboardShortcuts!default.jspa "Help")
-   [Log In](https://issues.jenkins.io/login.jsp?os_destination=%2Fbrowse%2FJENKINS-29252)

[📢 Jenkins core issues have been migrated to GitHub, no new core issues can be created in Jira](https://github.com/jenkinsci/jenkins/issues)

1.  [Jenkins](https://issues.jenkins.io/browse/JENKINS)
2.  [JENKINS-29252](https://issues.jenkins.io/browse/JENKINS-29252)

## 'Estimated remaining time' should become 'Overdue by' when the ETA is negative

-   [Open](https://issues.jenkins.io/browse/JENKINS-29252# "<span class=\"jira-issue-status-tooltip-title\">Open</span><br><span class=\"jira-issue-status-tooltip-desc\">The issue is open and ready for the assignee to start work on it.</span>")

[Export](https://issues.jenkins.io/browse/JENKINS-29252# "Export this issue in another format")

### 

-   **Type:**  New Feature
    
-   **Resolution:** Unresolved
    
-   **Priority:**  Minor
    
-   **Component/s:** [progress-bar-column-plugin](https://issues.jenkins.io/issues/?jql=project+%3D+JENKINS+AND+component+%3D+progress-bar-column-plugin "progress-bar-column-plugin progress-bar-column plugin")
    
-   **Labels:**
    
    None
    

### 

A build that's expected to take thirty-eight minutes running for forty minutes means something very different to one that's expected to take thirty seconds. The progress bar tooltips offer no indication of this.

To address this, I would suggest subbing out 'Estimated remaining time: N/A' with 'Overdue by: \[timedelta\]'

### 

-   [All](https://issues.jenkins.io/browse/JENKINS-29252?page=com.atlassian.jira.plugin.system.issuetabpanels:all-tabpanel)
-   Comments
-   [History](https://issues.jenkins.io/browse/JENKINS-29252?page=com.atlassian.jira.plugin.system.issuetabpanels:changehistory-tabpanel)
-   [Activity](https://issues.jenkins.io/browse/JENKINS-29252?page=com.atlassian.streams.streams-jira-plugin:activity-stream-issue-tab)

There are no comments yet on this issue.

### 

Assignee:

 Unassigned

Reporter:

 colons

Votes:

1 Vote for this issue

Watchers:

2 Start watching this issue

### 

Created:

2015-07-06 15:45

Updated:

2015-07-06 15:45
