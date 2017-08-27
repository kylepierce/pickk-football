_ = require "underscore"
Match = require "mtr-match"
Promise = require "bluebird"
Task = require "../Task"
Game = require "../../model/Game"
EndOfGame = require "./EndOfGame"
Team = require "../../model/Team"
Player = require "../../model/Player"
GameParser = require "./helper/GameParser"
moment = require "moment"
promiseRetry = require 'promise-retry'
chance = new (require 'chance')
CreatePlayQuestions = require "./CreatePlayQuestions"

module.exports = class extends Task
  constructor: (dependencies) ->
    super

    Match.check dependencies, Match.ObjectIncluding
      mongodb: Match.Any

    @logger = @dependencies.logger
    @Games = dependencies.mongodb.collection("games")
    @Multipliers = dependencies.mongodb.collection("multipliers")
    @Questions = dependencies.mongodb.collection("questions")
    @Teams = dependencies.mongodb.collection("teams")
    @Answers = dependencies.mongodb.collection("answers")
    @GamePlayed = dependencies.mongodb.collection("gamePlayed")
    @Users = dependencies.mongodb.collection("users")
    @Notifications = dependencies.mongodb.collection("notifications")
    @gameParser = new GameParser dependencies
    @endOfGame = new EndOfGame dependencies

  execute: (play, teams) ->
    if play
      playDetails =
        yardsToTouchdown: @yardsToTouchdown play.endPossession.teamId, play.endYardLine, teams
        previous: @previousObj play
        playDetails: @playDetailsObj play

      playDetails.distance = @distanceObj play, playDetails.yardsToTouchdown
      playDetails.nextPlay = @getNextPlayTypeAndDown playDetails
      playDetails.multiplierArguments = @getMultiplierArguments playDetails
      return playDetails

  previousObj: (play) ->
    return previous =
      playId: play.playId
      down: parseInt(play.down)
      distance: parseInt(play.distance)
      yards: parseInt(play.yards)

  playDetailsObj: (play) ->
    playDetails =
      playId: play.playId
      typeId: play.playType.playTypeId
      type: @getPlayType play.playType.playTypeId
      teamChange: @hasBallChangedTeams play.startPossession.teamId, play.endPossession.teamId
      scoreType: @hasScoreChange play.awayScoreBefore, play.awayScoreAfter, play.homeScoreBefore, play.homeScoreAfter
      isFirstDown: @reachedFirstDown play.yards, play.distance
      yards: parseInt(play.yards)

    if play.kickType then playDetails.kick is play.kickType
    return playDetails

  distanceObj: (play, yardsToTouchdown) ->
    return distance =
      yardsToFirstDown: @yardsToFirstDown play.distance, play.yards
      isDownAndGoal: @isDownAndGoal yardsToTouchdown
      location: @quantifyLocation yardsToTouchdown
      yardsArea: @quantifyYards play.distance

  yardsToFirstDown: (distance, yardsGained) ->
    yardsToFirstDown = parseInt(distance) - parseInt(yardsGained)
    if yardsToFirstDown < 0 || !yardsToFirstDown
      return 10
    else
      return yardsToFirstDown

  yardsToTouchdown: (teamIdWithBall, location, teams) ->
    team = _.find teams, (team) ->
      return team.teamId is teamIdWithBall
    numbers = location.replace(/\D+/g, '')
    # If Dal is on their side (Furthest from scoring)
    if location.indexOf(team.abbreviation) is 0
      # Dal7 would be 93, Dal42 would be 58
      return 100 - parseInt(numbers)
    else
      # Ind7 would be 7, Ind42 would be 42
      return numbers

  getPlayType: (playTypeId) ->
      playType = [
        title: "Pass",
        outcomes: [1, 2, 9, 19, 23]
      ,
        title: "Run",
        outcomes: [3, 4]
      ,
        title: "Fumble",
        outcomes: [14, 15, 16]
      ,
        title: "Interception",
        outcomes: [9, 19]
      ,
        title: "Turnover",
        outcomes: [9, 19, 16]
      ,
        title: "Turnover",
        outcomes: [9, 19, 16]
      ,
        title: "Timeout",
        outcomes: [13, 29, 57, 58]
      ,
        title: "Punt",
        outcomes: [7, 8]
      ,
        title: "Kickoff",
        outcomes: [5, 6]
      ,
        title: "Penalty",
        outcomes: [10, 11] # 10 is against offense -- 11 is against defense
      ,
        title: "Field Goal",
        outcomes: [17, 42]
      ,
        title: "Two Point No Good",
        outcomes: [53, 54, 55]
      ,
        title: "Turnover on Downs",
        outcomes: [18, 35, 36]
      ]

      for item in playType
        if (item['outcomes'].indexOf playTypeId) > -1
          type = item['title']
          return type

  reachedFirstDown: (yards, distance) ->
    if yards > distance
      return true
    else
      return false

  isDownAndGoal: (yardsToTouchdown) ->
    if yardsToTouchdown < 20
      return true
    else
      return false

  hasBallChangedTeams: (startTeam, endTeam) ->
    if startTeam isnt endTeam
      return true
    else
      return false

  hasScoreChange: (awayScoreBefore, awayScoreAfter, homeScoreBefore, homeScoreAfter) ->
    awayScoreChange = @teamScore awayScoreAfter, awayScoreBefore
    homeScoreChange = @teamScore homeScoreAfter, homeScoreBefore
    if awayScoreChange
      score = awayScoreChange
    else if homeScoreChange
      score = homeScoreChange
    else
      score = false
    return score

  teamScore: (after, before) ->
    if after > before
      if after - before is 1
        return "PAT"
      if after - before is 2
        return "Two Points"
      if after - before is 3
        return "Field Goal"
      if after - before is 6
        return "Touchdown"
    else
      return false

  quantifyLocation: (distance) ->
    distance = 100 - distance
    if distance >= 0 && distance <= 10
      return 1
    else if distance > 10 && distance <= 30
      return 2
    else if distance > 30 && distance <= 60
      return 3
    else if distance > 0 && distance <= 80
      return 4
    else if distance > 80 && distance <= 90
      return 5
    else if distance > 90
      return 6

  quantifyYards: (number) ->
    # Inches
    if number <= 1
      return 1
    else if number > 1 && number <= 2
      return 2
    else if number > 2 && number <= 5
      return 3
    else if number > 5 && number <= 9
      return 4
    else if number > 9 && number <= 15
      return 5
    else if number > 15
      return 6

  getNextPlayTypeAndDown: (play) ->
    kickOffList = ["PAT", "Safety", "Field Goal"]
    pointAfterQuestionlist = [22, 47, 49, 53, 54, 55, 56]
    if kickOffList.indexOf(play.playDetails.scoreType) > -1
      nextPlay =
        playType: "Kickoff"
        down: 6
    else if (pointAfterQuestionlist.indexOf(play.playDetails.typeId) > -1)
      nextPlay =
        playType: "Kickoff"
        down: 6
    else if play.playDetails.scoreType is "Touchdown"
      nextPlay =
        playType: "PAT"
        down: 5
    else if play.playDetails.isFirstDown || play.playDetails.teamChange || play.previous.down is NaN
      nextPlay =
        playType: "First Down"
        down: 1
        distance: 10
    else if play.previous.down is 3
      if play.yardsToTouchdown > 30
        nextPlay =
          playType: "Punt"
          down: 4
      else if  play.yardsToTouchdown < 30
        nextPlay =
          playType: "Field Goal Attempt"
          down: 4
    else if play.previous.down is 2
      if play.distance.isDownAndGoal
        nextPlay =
          playType: "Third Down && Goal"
          down: 3
      else
        nextPlay =
          playType: "Third Down"
          down: 3
    else if play.previous.down is 1
      nextPlay =
        playType: "Second Down"
        down: 2
    else
      nextPlay =
        playType: "Normal"
        down: 2
    return nextPlay

  getMultiplierArguments: (playDetails) ->
    # "down" : #, "area" : #, "yards" : #, "style" : #
    # console.log playDetails
    multiplierArguments =
      down: if playDetails.nextPlay then playDetails.nextPlay.down else playDetails.previous.down #Range 1-6
      area: playDetails.distance.location #Range 1-6
      yards: playDetails.distance.yardsArea #Range 1-6
      style: 2 #Range 1-3 when complete
      # playType: nextPlay.playType # String
    return multiplierArguments
