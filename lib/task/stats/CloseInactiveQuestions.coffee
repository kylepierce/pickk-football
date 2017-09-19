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
GetPlayDetails = require "./GetPlayDetails"

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
    @getPlayDetails = new GetPlayDetails dependencies
    @createPlayQuestions = new CreatePlayQuestions dependencies

  execute: (eventId, teams) ->
    Promise.bind @
      .then -> @Games.find({id: eventId})
      .then (game) -> @Questions.find({gameId: game[0]._id, type: "play", active: true});
      .map (question) -> @closeQuestion question, teams

  closeQuestion: (question, teams) ->
    Promise.bind @
      .then -> @getSinglePlay question.gameId, question.playId, 1
      .then (singlePlay) -> @getCorrectOptionNumber question, singlePlay, teams
      .then (optionNumber) -> @updateQuestionAndAnswers question._id, optionNumber
      .catch (error) ->
        @logger.verbose error

  getSinglePlay: (gameId, playId, indexPosition) ->
    Promise.bind @
      .then -> @getGame gameId
      .then (game) -> _.flatten game.pbp, 'playId'
      .then (list) -> @getPlayResult list, playId, indexPosition

  getPlayResult: (list, playId, indexPosition) ->
    # The playId comes from the play that happened before the question was created. Unfortunately there is not other way to associate that I am aware of.
    Promise.bind @
      .then ->_.indexOf list,  _.find list, (play) -> return play.playId is playId # Find the index of previous play in pbp array
      .then (index) -> list[index + indexPosition] # Then find the next or previous item in the pbp array. Which should be question's result.

  getCorrectOptionNumber: (question, singlePlay, teams) ->
    @playDetails = @getPlayDetails.execute singlePlay, teams

    Promise.bind @
      .then -> _.map question.options, (option) -> return option['title']
      .then (titles) -> @getAnswerOptionTitle titles, singlePlay, teams
      .map (optionTitle) -> @getAnswerOptionNumber question, optionTitle

  getAnswerOptionTitle: (titles, singlePlay, teams) ->
    play = @getPlayDetails.execute singlePlay, teams

    if !play
      console.log singlePlay

    Promise.bind @
      .then -> answers = [
        title: "Run",
        requirements:
          typeId: [3, 4]
      ,
      #   title: "Run", #Fumble
      #   requirements:
      #     typeId: [14]
      #     teamChange: false
      # ,
      #   title: "Pass", #Fumble
      #   requirements:
      #     typeId: [14]
      #     teamChange: false
      # ,
        title: "Pass",
        requirements:
          typeId: [1, 2, 9, 19, 23]
      ,
        title: "Pass", #Pass Interference
        requirements:
          typeId: 11
          penaltyId: 41
      ,
        title: "Interception",
        requirements:
          typeId: [9, 19],
          teamChange: true
      ,
        title: "Fumble",
        requirements:
          typeId: [14, 15, 16],
          teamChange: true
      ,
        title: "Pick Six",
        requirements:
          typeId: 19,
          teamChange: true
      ,
        title: "Unable to Covert First Down",
        requirements:
          isFirstDown: false
      ,
        title: "Convert to First Down",
        requirements:
          isFirstDown: true
      ,
        title: "Touchdown",
        requirements:
          scoreType: "Touchdown"
      ,
        title: "Kick Good!"
        requirements:
          scoreType: "Field Goal"
      ,
        title: "Missed Kick",
        requirements:
          type: "Field Goal"
          scoreType: false
      ,
        title: "Kick Good!"
        requirements:
          scoreType: "PAT"
      ,
        title: "Fake Kick No Score"
        requirements:
          typeId: [53, 54, 55]
      ,
        title: "Blocked Kick",
        requirements:
          type: "PAT"
          typeId: 47
          scoreType: false
      ,
        title: "Missed Kick",
        requirements:
          type: "PAT"
          typeId: 22
          scoreType: false
      ,
        title: "Two Point No Good",
        requirements:
          typeId: [53, 54, 55]
          type: "PAT"
          scoreType: false
      ,
        title: "Two Point Good",
        requirements:
          scoreType: "Two Points"
      ,
        title: "Safety",
        requirements:
          scoreType: "Two Points",
          teamChange: true
      ,
        title: "Failed Onside",
        requirements:
          type: "Kickoff",
          teamChange: true
      ,
        title: "Successful Onside",
        requirements:
          type: "Kickoff",
          teamChange: false
      ,
        title: "Blocked Punt",
        requirements:
          type: "Punt",
          typeId: 18
      ,
        title: "Fair Catch/No Return",
        requirements:
          type: "Punt"
          kickId: [6, 9, 10, 11, 15]
      ,
        title: "Touchback/No Return",
        requirements:
          type: "Kickoff"
          kickId: [6, 9, 10, 11, 15]
      ,
        title: "Neg to 25 Yard Return",
        requirements:
          teamChange: true
          yards: true
          yardsMin: null
          yardsMax: -1
      ,
        title: "Neg to 20 Yard Return",
        requirements:
          teamChange: true
          yards: true
          yardsMin: null
          yardsMax: -1
      ,
        title: "Neg to 25 Yard Return",
        requirements:
          teamChange: true
          yards: true
          yardsMin: 1
          yardsMax: 25
      ,
        title: "Neg to 20 Yard Return",
        requirements:
          teamChange: true
          yards: true
          yardsMin: 1
          yardsMax: 20
      ,
        title: "21-40 Yard Return",
        requirements:
          teamChange: true
          yards: true
          yardsMin: 21
          yardsMax: 40
      ,
        title: "26+ Return",
        requirements:
          teamChange: true
          yards: true
          yardsMin: 26
          yardsMax: null
      ,
        title: "26-45 Return",
        requirements:
          teamChange: true
          yards: true
          yardsMin: 26
          yardsMax: 45
      ,
        title: "46+,"
        requirements:
          teamChange: true
          yards: true
          yardsMin: 46
          yardsMax: null
      ]
      .then (answers) ->
        outcomes = []

        _.each titles, (title) -> # Look at each optionTitle
          _.each answers, (answer) ->
            if answer['title'] is title
              keys = _.allKeys answer.requirements

              if answer.requirements.yards
                if answer.requirements.yardsMin is null then min = -100 else min = answer.requirements.yardsMin
                if answer.requirements.yardsMax is null then max = 100 else max = answer.requirements.yardsMax

                if play.playDetails.yards >= min  && play.playDetails.yards <= max
                  outcomes.push(answer.title)

              if _.isMatch play.playDetails, answer.requirements
                outcomes.push(answer.title)

              _.map keys, (key) ->
                answerValue = answer.requirements[key]
                playValue = play.playDetails[key]

                if _.isArray answerValue
                  if (answerValue.indexOf playValue) > -1
                    outcomes.push(answer.title)

        return outcomes

  getAnswerOptionNumber: (question, optionTitle) ->
    @logger.verbose "Answer:", question.que, ">>>", optionTitle
    Promise.bind @
      .then -> _.invert _.mapObject question['options'], (option) -> option['title']
      .then (options) -> options[optionTitle]

  updateQuestionAndAnswers: (questionId, outcome) ->
    if @playDetails.playDetails.deleteQuestion
      Promise.bind @
        .then -> @deleteQuestion questionId
    else
      Promise.bind @
        .then -> @Questions.update {_id: questionId}, $set: {active: false, outcome: outcome, extendedDetails: @playDetails, lastUpdated: new Date()}
        .then -> return outcome
        .each (outcome) -> @updateAnswers questionId, outcome

  updateAnswers: (questionId, outcome) ->
    Promise.bind @
      .then -> @Answers.update {questionId: questionId, answered: {$ne: outcome}}, {$set: {outcome: "lose"}}, {multi: true}
      .then -> @Answers.find {questionId: questionId, answered: outcome}
      .map (answer) -> @awardUsers answer, outcome

  awardUsers: (answer, outcomeOption) ->
    reward = Math.floor answer['wager'] * answer['multiplier']
    Promise.bind @
      .then -> @Answers.update {_id: answer._id}, {$set: {outcome: "win"}} #
      .then -> @GamePlayed.update {period: answer.period, userId: answer['userId'], gameId: answer.gameId}, {$inc: {coins: reward}}
      .then -> @GamePlayed.find {period: answer.period, userId: answer['userId'], gameId: answer.gameId}
      .tap (result) -> @logger.verbose "Awarding correct users!"
      .then ->
        @Notifications.insert
          _id: @Notifications.db.ObjectId().toString()
          dateCreated: new Date()
          questionId: answer.questionId
          userId: answer['userId']
          gameId: answer.gameId
          period: answer.period
          type: "coins"
          value: reward
          read: false
          message: "Nice Pickk! You got #{reward} Coins!"
          sharable: false
          shareMessage: ""

  deleteQuestion: (questionId) ->
    @logger.verbose "PLAY DELETED! [" + questionId + "]"
    Promise.bind @
      .then -> @Questions.update {_id: questionId}, {$set: {active: false, outcome: "Removed",  extendedDetails: @playDetails, lastUpdated: new Date()}}
      .then -> @Answers.find {questionId: questionId}
      .map (answer) -> @returnCoins answer

  returnCoins: (answer) ->
    amount = parseInt(answer.wager)
    Promise.bind @
      .then -> @GamePlayed.update {userId: answer.userId, gameId: answer.gameId,  period: answer.period}, {$inc: {coins: amount}}
      .then -> @Answers.update {_id: answer._id}, {$set: {outcome: "Removed"}}
      .then ->
        @Notifications.insert
          _id: @Notifications.db.ObjectId().toString()
          dateCreated: new Date()
          questionId: answer.questionId
          userId: answer['userId']
          gameId: answer.gameId
          source: "removed"
          type: "coins"
          value: amount
          read: false
          message: "Play was removed. Here are your " + amount + " coins"
          sharable: false
          shareMessage: ""

  getGame: (gameId) ->
    Promise.bind @
      .then -> @Games.findOne({_id: gameId})
