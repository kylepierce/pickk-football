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

  execute: (eventId, teams) ->
    Promise.bind @
      .then -> @Games.find({id: eventId})
      .then (game) -> @Questions.find({gameId: game[0]._id, type: "play", active: true});
      .map (questions) -> @closeQuestion questions, teams

  closeQuestion: (question, teams) ->
    Promise.bind @
      .then -> @getSinglePlayResult question
      .then (result) -> @getCorrectOptionNumber question, result, teams
      # .then (optionNumber) -> @updateQuestionAndAnswers question._id, optionNumber
      # .map (answer) -> @awardUsers answer, outcome

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
      .then ->_.indexOf list,  _.find list, (play) -> return play.playId is playId
      # Then find the next item in the pbp array. Which should be this question's result.
      .then (index) -> list[index + 1]

  getCorrectOptionNumber: (question, result, team) ->
    Promise.bind @
      .then -> @getPlayOptionTitle question, result, team
      .then (optionTitle) -> @getPlayOptionNumber question, optionTitle

  getPlayOptionTitle: (question, result, team) ->
    playDetails = @getPreviousPlayDetails result, team
    console.log playDetails
    Promise.bind @
      .then -> @kickoffQuestion question, playDetails
      .then -> @pointAfterQuestion question, playDetails
      .then -> @puntQuestion question, playDetails
      .then -> @fieldGoalQuestion question, playDetails
      .then -> @thirdDownQuestion question, playDetails
      .then -> @normalQuestion question, playDetails

  kickoffQuestion: (question, playDetails) ->
    list = [5, 6, 25, 41, 43]
    if playDetails.playType is "Kickoff"
      console.log "Kickoff"
      console.log question.que
      console.log playDetails
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

  pointAfterQuestion: (question, playDetails) ->
    list = [22, 47, 49, 53, 54, 55, 56]
    if playDetails.playType is "PAT"
      console.log "PAT"
      console.log question.que
      console.log playDetails
    # if playDetails.scoreType is "PAT"
    # "Kick Good!",
    # "Fake Kick No Score",
    # "Blocked Kick",
    # "Missed Kick",
    # "Two Point Good",
    # "Two Point No Good"

  puntQuestion: (question, playDetails) ->
    list = [7, 8, 18, 24, 71]
    if playDetails.playType is "Punt"
      console.log "Punt"
      console.log question.que
      console.log playDetails
    # Punt - Return yards
    # When play type is 7
    # Down is 4
    # When kickType exists
    # "Fair Catch/No Return", - KickType: 6, 9, 10, 11, 24,
    # "Neg to 20 Yard Return", "21-40 Yard Return", - result.distance
    # "Blocked Punt", - KickType: 13
    # "Fumble", - playTypeId: 14, KickType: 12
    # "Touchdown" -

  fieldGoalQuestion: (question, playDetails) ->
    list = [17, 35, 36, 42, 50]
    if playDetails.playType is "Field Goal"
      console.log "Field Goal"
      console.log question.que
      console.log playDetails
    # Field goal - Successful?
    # if down is 4
    # "Kick Good!",
    # "Run",
    # "Pass",
    # "Fumble",
    # "Missed Kick",
    # "Blocked Kick"

  thirdDownQuestion: (question, playDetails) ->
    # if result.down is 3
    if playDetails.down is 3
      console.log "Third Down"
      console.log question.que
      console.log playDetailsn
    #   # if distance from endzone is less then 10
    #   # else
      if playDetails.isFirstDown
        return "Convert to First Down"
      else if !playDetails.isFirstDown
        return "Unable to Covert First Down"
      if playDetails.teamChange
        console.log "Turnover"
        return
        # "Interception",
        # "Fumble",
        # if playDetails.scoreType
          # "Pick Six",
      if playDetails.scoreType
        return "Touchdown"

  normalQuestion: (question, playDetails) ->
    if playDetails.down is 1 || playDetails.down is 2
      console.log "Normal Play"
      console.log question.que
      console.log playDetails
      if playDetails.playTypeId is "Run"
        return "Run"
      else if playDetails.playTypeId is "Pass"
        return "Pass"
      if playDetails.teamChange
        # "Interception",
        # "Fumble",
        return "Turnover"
        # if scoreType
          # "Pick Six",
      if playDetails.scoreType
        return "Touchdown"

  getPlayOptionNumber: (question, optionTitle) ->
    console.log "Play Outcome", optionTitle
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
