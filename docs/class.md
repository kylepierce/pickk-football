# Class
======

## Game
### Data
  - eventTypeId (number)
  - dateCreated (date)
  - isoDate (object)
  - eventStatus (object)
  - tvStations (object)
  - teams (array)
  - home (object)
  - away (object)
  - week (number)
  - pbp (array)
  - commercial (boolean)
  - name (string)
  - sport (string)
  - live (boolean)
  - status (string)
  - completed (boolean)
  - lastUpdated (date)
  - invited (array)
  - registered (array)
  - nonActive (array)
  - users (array)
### Functions
  -> importGame
  -> updateGame
  -> getSpecificPlay

## GamePlayed
### Data
### Functions

=====

## Team
### Data
  - teamId (number)
  - location (string)
  - nickname (string)
  - abbreviation (string)
### Functions

=====

## Question
### Data
  - dateCreated (date)
  - options (object)
  - status (string)
  - active (boolean)
  - lastUpdated (date)
  - gameId (string)
  - type (string)
  - commercial (boolean)
  - que (string)
  - usersAnswered (array)
### Functions
  -> nextPlay - Take a few data points figure out what the next play will be (first, second, third, fourth, PAT, kickoff)
  -> createQuestion
  -> updateQuestion
  -> deleteQuestion
  -> closeQuestion
  -> awardWinners

## Play Question
### Data
  - playId (number)
  - period (number)
  - time (string)
  - down (Optional string)
  - distance (Optional string)
  - yardLine (string)
  - endYardLine (string)
  - driveId (number)
  - playType (object)
  - kickType (Optional object)
  - isReview (boolean)
  - playText (string)
  - playersInvolved (array)
  - direction (string)
  - yards (number)
### Functions

## Drive Question
### Data
### Functions

## Prop Question
### Data
### Functions

## Free Pickk Question
### Data
### Functions

====

## Answers
### Data
### Functions
