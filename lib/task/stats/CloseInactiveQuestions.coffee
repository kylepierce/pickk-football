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
      .then (playResult) -> @getCorrectOptionNumber question, playResult, teams
      .then (optionNumber) -> @updateQuestionAndAnswers question._id, optionNumber

  getSinglePlay: (gameId, playId, indexPosition) ->
    Promise.bind @
      .then -> @getGame gameId
      .then (game) -> _.flatten game[0].pbp, 'playId'
      .then (list) -> @getPlayResult list, playId, indexPosition

  getPlayResult: (list, playId, indexPosition) ->
    # The playId comes from the play that happened before the question was created. Unfortunately there is not other way to associate that I am aware of.
    Promise.bind @
      .then ->_.indexOf list,  _.find list, (play) -> return play.playId is playId # Find the index of previous play in pbp array
      .then (index) -> list[index + indexPosition] # Then find the next or previous item in the pbp array. Which should be question's result.

  getCorrectOptionNumber: (question, result, teams) ->
    playDetails = @getPlayDetails.execute result, teams

    Promise.bind @
      .then -> _.map question.options, (option) -> return option['title']
      .then (titles) -> @getPlayOptionTitle titles, playDetails
      .map (outcome) -> @getPlayOptionNumber question, outcome

  getPlayOptionTitle: (titles, play) ->
    Promise.bind @
      .then -> answers = [
        title: "Run",
        requirements:
          typeId: [3, 4]
      ,
        title: "Pass",
        requirements:
          typeId: [1, 2, 9, 19, 23]
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
        title: "Kick Good!,"
        requirements:
          typeId: [17, 22, 42]
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
        title: "Missed Kick",
        requirements:
          playType: "Field Goal"
      ,
        title: "Failed Onside",
        requirements:
          playType: "Kickoff",
          teamChange: true
      ,
        title: "Successful Onside",
        requirements:
          playType: "Kickoff",
          teamChange: false
      ,
        title: "Blocked Punt",
        requirements:
          playType: "Punt",
          typeId: 18
      ,
      #   title: "Fake Kick No Score"
      #,   requirements:
      # ,
        title: "Two Point No Good",
        requirements:
          typeId: [53, 54, 55]
      ,
        title: "Fair Catch/No Return",
        requirements:
            # typeId: [21, 28]
            yards: true
            yardsMin: 0
            yardsMax: 0
      ,
        title: "Touchback/No Return",
        requirements:
          # typeId: [21, 28]
          yards: true
          yardsMin: 0
          yardsMax: 0
      ,
        title: "Neg to 25 Yard Return",
        requirements:
          yards: true
          yardsMin: null
          yardsMax: -1
      ,
        title: "Neg to 20 Yard Return",
        requirements:
            yards: true
            yardsMin: null
            yardsMax: -1
      ,
        title: "Neg to 25 Yard Return",
        requirements:
          yards: true
          yardsMin: 1
          yardsMax: 25
      ,
        title: "Neg to 20 Yard Return",
        requirements:
            yards: true
            yardsMin: 1
            yardsMax: 20
      ,
        title: "21-40 Yard Return",
        requirements:
          yards: true
          yardsMin: 21
          yardsMax: 40
      ,
        title: "26+ Return",
        requirements:
          yards: true
          yardsMin: 26
          yardsMax: null
      ,
        title: "26-45 Return",
        requirements:
          yards: true
          yardsMin: 26
          yardsMax: 45
      ,
        title: "46+,"
        requirements:
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

  getPlayOptionNumber: (question, optionTitle) ->
    console.log "Answering Question:", "[", question.gameId, "]", question.que, ">>>>", optionTitle
    Promise.bind @
      .then -> _.invert _.mapObject question['options'], (option) -> option['title']
      .then (options) -> options[optionTitle]

  updateQuestionAndAnswers: (questionId, outcome) ->
    Promise.bind @
      .then -> @Questions.update {_id: questionId}, $set: {active: false, outcome: outcome, lastUpdated: new Date()}
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
      .then -> @GamePlayed.update {userId: answer['userId'], gameId: answer.gameId}, {$inc: {coins: reward}}
      .tap -> @logger.verbose "Awarding correct users!"
      .then ->
        @Notifications.insert
          _id: @Notifications.db.ObjectId().toString()
          dateCreated: new Date()
          questionId: answer.questionId
          userId: answer['userId']
          gameId: answer.gameId
          type: "coins"
          value: reward
          read: false
          message: "Nice Pickk! You got #{reward} Coins!"
          sharable: false
          shareMessage: ""

  getGame: (gameId) ->
    Promise.bind @
      .then -> @Games.find {_id: gameId}
