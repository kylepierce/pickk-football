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

  execute: (old, update) ->
    if old.pbp
      oldPlays =  old.pbp.length
      newPlays = update.pbp.length
    if @isNewPlay newPlays, oldPlays
      teams = update.teams
      previousPlay = (_.last update.pbp)
      previousPlayDetails = @getPreviousPlayDetails previousPlay, teams
      nextPlayTypeAndDown = @getNextPlayTypeAndDown previousPlayDetails
      multiplierArguments = @getMultiplierArguments previousPlayDetails, nextPlayTypeAndDown

      Promise.bind @
        # .then -> @closeInactiveQuestions update.id, previousPlayDetails
        # .then -> @createCommercialQuestions update.eventId, previousPlayDetails
        # .then -> @startCommercialBreak update.eventId, previousPlayDetails
        .then -> @createPlayQuestion update.eventId, previousPlayDetails, multiplierArguments

  isNewPlay: (newLength, oldLength) ->
    if newLength > oldLength
      return true

  getPreviousPlayDetails: (previousPlay, teams) ->
    if previousPlay
      postPlaydetails =
        playId: previousPlay.playId
        down: parseInt(previousPlay.down)
        distance: parseInt(previousPlay.distance)
        yards: parseInt(previousPlay.yards)
        typeId: previousPlay.playType.playTypeId
        type: @getPlayType previousPlay.playType.playTypeId
        isFirstDown: @reachedFirstDown previousPlay.yards, previousPlay.distance
        isDownAndGoal: @isDownAndGoal previousPlay.endPossession.teamId, previousPlay.endYardLine, previousPlay.distance, teams
        teamChange: @hasBallChangedTeams previousPlay.startPossession.teamId, previousPlay.endPossession.teamId
        scoreType: @hasScoreChange previousPlay.awayScoreBefore, previousPlay.awayScoreAfter, previousPlay.homeScoreBefore, previousPlay.homeScoreAfter
        distanceToGoal: @distanceToGoal previousPlay.endPossession.teamId, previousPlay.endYardLine, teams
        location: @quantifyLocation previousPlay.endPossession.teamId, previousPlay.endYardLine, teams
        yardsToGo: @quantifyYards previousPlay.distance
      return postPlaydetails


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

  isDownAndGoal: (teamIdWithBall, location, yards, teams) ->
    distance = @distanceToGoal teamIdWithBall, location, teams
    if distance > 20
      return true

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
        return "Safety"
      if after - before is 3
        return "Field Goal"
      if after - before is 6
        return "Touchdown"
    else
      return false

  distanceToGoal: (teamIdWithBall, location, teams) ->
    team = _.find teams, (team) ->
      return team.teamId is teamIdWithBall
    numbers = location.replace(/\D+/g, '')
    if (location.indexOf team.abbreviation > 0)
      return 100 - parseInt(numbers)
    else
      return numbers

  quantifyLocation: (teamIdWithBall, location, teams) ->
    distance = @distanceToGoal teamIdWithBall, location, teams
    if distance >= 0 && distance <= 10
      return 1
    else if distance > 10 && distance <= 30
      return 2
    else if distance > 30 && distance <= 60
      return 3
    else if distance > 60 && distance <= 80
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
    if (kickOffList.indexOf(play.scoreType) > 0)
      nextPlay =
        playType: "Kickoff"
        down: 6
    else if (pointAfterQuestionlist.indexOf(play.typeId) > 0)
      nextPlay =
        playType: "Kickoff"
        down: 6
    else if play.scoreType is "Touchdown"
      nextPlay =
        playType: "PAT"
        down: 5
    else if play.down is 3 && play.isFirstDown is false && play.distanceToGoal < 30
      nextPlay =
        playType: "Punt"
        down: 4
    else if play.down is 3 && play.isFirstDown is false && play.distanceToGoal > 30
      nextPlay =
        playType: "Field Goal Attempt"
        down: 4
    else if play.down is 2 && play.isFirstDown is false
      nextPlay =
        playType: "Third Down"
        down: 3
    else if play.down is 2 && play.isFirstDown is false && play.isDownAndGoal
      nextPlay =
        playType: "Third Down && Goal"
        down: 3
    else if play.down is 1 && play.isFirstDown is false
      nextPlay =
        playType: "Second Down"
        down: 2
    else if play.isFirstDown || play.teamChange
      nextPlay =
        playType: "First Down"
        down: 1
    else
      nextPlay =
        playType: "Normal"
        down: 2
    return nextPlay

  getMultiplierArguments: (previous, nextPlay) ->
    # "down" : #, "area" : #, "yards" : #, "style" : #
    multiplierArguments =
      down: nextPlay.down #Range 1-6
      area: previous.location #Range 1-6
      yards: previous.yardsToGo #Range 1-6
      style: 2 #Range 1-3 when complete
      # playType: nextPlay.playType # String
    return multiplierArguments

  closeInactiveQuestions: (eventId) ->
    Promise.bind @
      .then -> @Games.find({id: eventId})
      .then (game) -> @Questions.find({gameId: game[0]._id, type: "play", active: true});
      .map (questions) -> @closeQuestion questions

  closeQuestion: (question) ->
    Promise.bind @
      .then -> @getSinglePlayResult question
      .then (result) -> @getCorrectOptionNumber question, result
      .then (optionNumber) -> @updateQuestionAndAnswers question._id, optionNumber
      .map (answer) -> @awardUsers answer, outcome

  getSinglePlayResult: (question) ->
    Promise.bind @
      .then -> @getGame question.gameId
      .then (game) -> @getPlays game[0]
      .then (list) -> @getPlayResult list, question.playId

  getPlays: (game) ->
    Promise.bind @
      .then -> _.flatten game.pbp, 'playId'
      .then (list) -> _.filter list, @ignoreList

  ignoreList: (single) ->
    list = [10, 11, 13, 29, 57, 58]
    if (list.indexOf(single) is -1)
      return true

  getPlayResult: (list, playId) ->
    # The playId comes from the play that happened before the question was created.
    # Unfortunately there is not other way to associate that I am aware of.
    Promise.bind @
      # Find the index of previous play in pbp array
      .then -> _.indexOf(list, playId)
      # Then find the next item in the pbp array. Which should be this question's result.
      .then (index) -> list[index + 1]

  getCorrectOptionNumber: (question, result) ->
    Promise.bind @
      .then (result) -> @getPlayOptionTitle question, result
      .then (optionTitle) -> @getPlayOptionNumber question, optionTitle

  getPlayOptionTitle: (question, result) ->
    # details =
    #   playId:
    #   isFirstDown:
    #   type:
    #   teamChange:
    #   scoreType:
    #   distanceToGoal:
    #   location:
    #   isDownAndGoal:
    #   down:
    #   distance:
    #   yards:
    # playDetails = @getPreviousPlayDetails result
    # playType = @playType playDetails
    # Promise.bind @
    #   .then -> @kickoffQuestion question, result, playDetails
    #   .then -> @pointAfterQuestion question, result, playDetails
    #   .then -> @puntQuestion question, result, playDetails
    #   .then -> @fieldGoalQuestion question, result, playDetails
    #   .then -> @thirdDownQuestion question, result, playDetails
    #   .then -> @normalQuestion question, result, playDetails

  kickoffQuestion: (question, result, playDetails) ->
    list = [5, 6, 25, 41, 43]
    # if (list.indexOf(result.playType.playTypeId) > 0)
      # if teamChange is false
        # "Fumble",
        # "Successful Onside",
      # if scoreType
        # "Touchdown"
      # if no return
        # "Touchback/No Return",
      # if yards
        # "Neg to 25 Yard Return",
        # "26-45 Return",
        # "26+ Return",
        # "46+",
        # "Failed Onside",

  pointAfterQuestion: (question, result, playDetails) ->
    list = [22, 47, 49, 53, 54, 55, 56]
    # if playDetails.scoreType is "PAT"
    # "Kick Good!",
    # "Fake Kick No Score",
    # "Blocked Kick",
    # "Missed Kick",
    # "Two Point Good",
    # "Two Point No Good"

  puntQuestion: (question, result, playDetails) ->
    list = [7, 8, 18, 24, 71]
    # Punt - Return yards
    # When play type is 7
    # Down is 4
    # When kickType exists
    # "Fair Catch/No Return", - KickType: 6, 9, 10, 11, 24,
    # "Neg to 20 Yard Return", "21-40 Yard Return", - result.distance
    # "Blocked Punt", - KickType: 13
    # "Fumble", - playTypeId: 14, KickType: 12
    # "Touchdown" -

  fieldGoalQuestion: (question, result, playDetails) ->
    list = [17, 35, 36, 42, 50]
    # Field goal - Successful?
    # if down is 4
    # "Kick Good!",
    # "Run",
    # "Pass",
    # "Fumble",
    # "Missed Kick",
    # "Blocked Kick"

  thirdDownQuestion: (question, result, playDetails) ->
    # if result.down is 3
    #   # if distance from endzone is less then 10
    #   # else
    #   if playDetails.isFirstDown
    #     return "Convert to First Down"
    #   if !playDetails.isFirstDown
    #     return "Unable to Covert First Down",
    #   if teamChange
    #     # "Interception",
    #     # "Fumble",
    #     if scoreType
    #       # "Pick Six",
    #   if scoreType
        # "Touchdown"

  normalQuestion: (question, result, playDetails) ->
    # if result.down is 1 || result.down is 2
    #   # if playTypeId is "Run",
    #   # if playTypeId is "Pass",
    #   if teamChange
    #     # "Interception",
    #     # "Fumble",
    #     # "Turnover",
    #     if scoreType
    #       # "Pick Six",
    #   if scoreType
        # "Touchdown"

  getPlayOptionNumber: (question, optionTitle) ->
    Promise.bind @
      .then -> _.invert _.mapObject question['options'], (option) -> option['title']
      .then (options) -> console.log "-------- \n", "Play Outcome:", options[optionTitle], "\n", outcome, "\n", options
      # .then (options) -> options[outcome]

  updateQuestionAndAnswers: (questionId, outcome) ->
    Promise.bind @
      .then -> @Questions.update {_id: questionId}, $set: {active: false, outcome: outcome, lastUpdated: new Date()} # Close and add outcome string
      .then -> @Answers.update {questionId: questionId, answered: {$ne: outcome}}, {$set: {outcome: "lose"}}, {multi: true} # Losers
      .then -> @Answers.find {questionId: questionId, answered: outcome} # Find the winners

  awardUsers: (answer, outcomeOption) ->
    reward = Math.floor answer['wager'] * answer['multiplier']
    Promise.bind @
      .then -> @Answers.update {_id: answer._id}, {$set: {outcome: "win"}} #
      .then -> @GamePlayed.update {userId: answer['userId'], gameId: answer.gameId}, {$inc: {coins: reward}}
      .tap -> @logger.verbose "Awarding correct users!"
      .then ->
        @Notifications.insert
          _id: @Notifications.db.ObjectId().toString()
          dateCreated: new Date()
          question: answer.questionId
          userId: answer['userId']
          gameId: answer.gameId
          type: "coins"
          value: reward
          read: false
          message: "Nice Pickk! You got #{reward} Coins!"
          sharable: false
          shareMessage: ""



  createCommercialQuestions: (eventId, previous) ->

  startCommercialBreak: (eventId, previous) ->
    list = ["Punt", "Touchdown", "Field Goal", "Kickoff", "Timeout", "Two Min"]
    if (list.indexOf(previous.playType) > 0)
      Promise.bind @
        .then -> getGame eventId
        .then (game) -> @Games.update({_id: game._id}, {$set: {commercial: true, commercialTime: new Date}})



  createPlayQuestion: (eventId, details, multiplierArguments) ->
    Promise.bind @
      .then -> @Multipliers.find multiplierArguments
      .then (result) -> @parseOptions result[0].options
      .then (options) -> @insertPlayQuestion eventId, details, multiplierArguments, options

  parseOptions: (options) ->
    _.mapObject options, (option, key) ->
      if _.isEmpty option
        delete options[key]
        return false

      max = option.high
      min = option.low
      multi = (Math.random() * (max-min) + min).toFixed(1)
      option.multiplier = parseFloat(multi)

    return options

  insertPlayQuestion: (eventId, details, multiplierArguments, options) ->
    console.log multiplierArguments
    Promise.bind @
      .then ->@Games.find {eventId: eventId}
      .then (result) ->
        @Questions.insert
          _id: @Questions.db.ObjectId().toString()
          dateCreated: new Date()
          gameId: result[0]._id
          period: result[0].period
          playId:  details.playId
          details:  multiplierArguments
          extendedDetails: details
          type: "play"
          active: true
          commercial: false
          que: @generateQuestionTitle details, multiplierArguments
          options: options
          usersAnswered: []

  generateQuestionTitle: (details, multiplierArguments) ->
    console.log details
    downGrammer = @downGrammer multiplierArguments.down
    que =  downGrammer + " & " + details.yardsToGo

    console.log que
    return que

  downGrammer: (down) ->
    switch down
      when 1
        return "1st"
      when 2
        return "2nd"
      when 3
        return "3rd"
      when 4
        return "4th"

  getGame: (gameId) ->
    Promise.bind @
      .then -> @Games.find {_id: gameId}
