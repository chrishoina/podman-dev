# An Explain Plan workflow 

## Create the HTML file

1. Create an html file, in the current working directory. Name this file, "explain_plan.html" 
2. Verify with me that the html file exists, before proceeding forward.

## Connect to the database 

1. Connect to the database as the SQL_FREESQL_01 user

## Execute a SQL query 

1. Execute the following SQL Query:

    ```sh
        SELECT /* LLM in use is claude-3.5-sonnet */
        N.NAME, -- Nation name from OLYM_NATIONS table
        COUNT(M.ID) as MEDAL_COUNT, -- Count of medals won by each nation
        COUNT(DISTINCT A.ID) as ATHLETE_COUNT -- Count of distinct athletes from each nation
        FROM OLYM.OLYM_MEDALS M -- Start with OLYM_MEDALS table
        -- Join OLYM_MEDALS with OLYM_ATHLETE_GAMES on ATHLETE_GAME_ID
        JOIN OLYM.OLYM_ATHLETE_GAMES AG ON M.ATHLETE_GAME_ID = AG.ID
        -- Join OLYM_ATHLETE_GAMES with OLYM_ATHLETES on ATHLETE_ID
        JOIN OLYM.OLYM_ATHLETES A ON AG.ATHLETE_ID = A.ID
        -- Join OLYM_ATHLETES with OLYM_NATIONS on NATION_ID to get nation name
        JOIN OLYM.OLYM_NATIONS N ON A.NATION_ID = N.ID
        -- Group results by nation name
        GROUP BY N.NAME
        -- Order results by medal count in descending order
        ORDER BY MEDAL_COUNT DESC
        -- Limit results to top 10
    ```

2. Add these results to the "explain_plan.html" file.

## Perform an Explain plan 

1. Perform an Explain Plan on the previously executed SQL query.
2. The results from the explain plan will be used for the "explain_plan.html" file. 

## HTML report characteristics

1. The table results for Id, Operation, Name, Rows, Bytes, Cost (%CPU), and Time should be modeled as individual modules. Where each module, according to its ID, will visualize the remaining values for said module. 
  The graphic should have the following characteristics:
    - It should display the steps in chronological order
    - It should emphasize Bytes, and Cost (%CPU)
    - It should have a legend, explaining what the values represent
    - The predicate in information section should be presented in its own section in the "explain_plan.html" file.

