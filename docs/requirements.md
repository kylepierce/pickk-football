#Requirements

### Last Updated:
30 August 2017

## Functional Requirements

### Insert Game
Primary Actor: Application
Secondary Actor: MongoDb, STATS
Status: Done

Scenario:
1. System requests today's games
2. STATS returns all the games for a day
3. Games found inserted into the games collection

###  Find active games
Primary Actor: Application
Secondary Actor: MongoDb, STATS
Status: Done

Scenario:
1. System requests all active games
2. If a game is active pull the latest data

Extension: No live game
1. Find next game time
2. Add delay to next active game request

### Process Live Game
Primary Actor: STATS
Secondary Actor: MongoDb
Status: Done

Scenario:
1. Format STATS data it to make it easier to process
2. If there is new data find what changed

### Create Drive Question
Primary Actor: STATS
Secondary Actor: MongoDb
Status: Not Started
Priority: Next

Scenario:
1. Get relevant data
2. Get game split
3. Create question title "How will this drive for 'Team name' end"?
4. Use relevant data to generate multipliers
3. Take data, multipliers, and title to create a question

### Create a Play Question
Primary Actor: STATS
Secondary Actor: MongoDb
Status: Done

Scenario:
1. Get relevant data
2. Get game split
3. Down and distance as the question title
4. Use relevant data to generate multipliers
5. Take data, multipliers, and title to create a question

Extension: End of a drive/quarter/half
1. Wait until after commercial break

Extension: Close to the end of the game
1. Divide time remaining with downs

### Commercial break
Primary Actor: STATS
Secondary Actor: MongoDb
Status: Not Started
Priority: Next

Scenario:
1. An precursor event happened (punt, touchdown scored, field goal scored, kickoff)
2. Set game to commercial
3. Set commercialTime to current time

Extension: Game play continues
1. New play occurs during commercial
2. Toggle commercial
3. Create next play question

### Create commercial question
Primary Actor: STATS
Secondary Actor: MongoDb
Status: Not Started
Priority: Next

Scenario:
1. Game is in a commercial break
2. Who will have the ball when game returns?
3. Create question from the list of commercial questions

Extension: End of quarter/half
1. Skip drive and free pickk questions

### Answer Question
Primary Actor: STATS
Secondary Actor: MongoDb, Player
Status: Done

Scenario:
1. Get the play result
2. Close question
3. Find which option correlates with answer
4. Update answers who were incorrect
5. Award correct users

Extension: No matching option
1. Send a flag to admin

### Award Correct Users
Primary Actor: STATS
Secondary Actor: MongoDb, Player
Status: Pending

Scenario:
1. Get single answer for player
2. Change status of answer
3. Increase coins

### Close Quarter
Primary Actor: STATS
Secondary Actor: MongoDb, Player, Notifications
Status: Not Started

1. Game quarter ends
2. Move to the next period
3. Notify user to see their ranking

### Award Quarter Winners
Primary Actor: STATS
Secondary Actor: MongoDb, Player, Notifications
Status: Not Started

Scenarios
2. Find open questions
3. Close / Delete questions
4. Award leaderboard

Extension: If a drive question is still active
1. Skip step 3 and 4
2. Move to the next period
3. Once drive question has been answered
4. Close the quarter and award leaders

### Create Quarter Questions
Primary: STATS
Secondary Actor: MongoDb
Status: Not Started

Scenario:
1. Create questions
2. Toggle commercial

### Create Pre Game questions
Primary Actor: STATS
Secondary Actor: MongoDb, Notifications
Status: Not Started

Scenario:
1. 2 Hours before scheduled time
2. Create 1st quarter initial questions
3. Notify registered users
4. Update game that questions were made dont need to create them

Extension: Game questions were not created 2 hours ahead.
1. If the game is not active
2. Run the function again

====

## Non-Functional Requirements

### Help
- Alert: If a question is completed but no answer is found

### Support
- Create support tickets for users to report error.
-> What data is needed to make the change?
-> What process will be done to update the question.
-> Log that error for cleanup.

### Performance
