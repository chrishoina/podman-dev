## Intro
1. Create “sqlcl help quick reference” html dashboard file
2. This html file will display the title “SQLcl Help Quick Reference”
3. The html <body> should include columns for the following:
	- SQLcl topic
		- SQLcl topic subcommand (which is indented so the user will know this is a subcommand)
	- SQLcl options 
	- SQL definition or usage 
	- SQLcl syntax examples (if applicable for this topic or topic subcommand)
4. Connect as the SQL_FREESQL_01

## Complete these steps independently##

> Note: You do not need to request my approval for the steps encapsulated by the {Begin} {End} tags.

{Begin}

5. Execute the HELP command, a list of available topics will be displayed. Do not seek my approval for this step. Perform t
6. Iterate through the topics and topic subcommands and complete these actions:
	- issue the help [topic] command and add the topic name to the topic column of the html dashboard
	- If topic subcommands exist, add these to the indented column of the html dashboard
	- For the related topic or topic subcommand, add the options to the related section in the html dashboard
	- For the definition or usage of a topic of topic subcommand add this information to the related section in the html dashboard
	- For the syntax examples of a topic of topic subcommand add this information to the related section in the html dashboard
7. Each topic and subtopic should allow me to select any options I want, and present me with a <copy></copy> block so that I may copy the code and place in a terminal screen.
8. Silently, and with my implicit approval (i.e., do not ask me for approval), using the sqlcl "help" [followed by topic name] command, iterate through all of the topics and retrieve the topic name, options, usage notes, and related syntax examples for all available sqlcl topics, and their subtopics. 
9. As you are iterating, append these to the html dashboard.

{End}

## Complete this step with my approval 

10. Once complete notify me of completion