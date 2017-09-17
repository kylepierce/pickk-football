_ = require "underscore"
Match = require "mtr-match"
Promise = require "bluebird"
Task = require "../Task"
Game = require "../../model/Game"
EndOfGame = require "./EndOfGame"
Team = require "../../model/Team"
Player = require "../../model/Player"
GameParser = require "./helper/GameParser"
CloseInactiveQuestions = require "./CloseInactiveQuestions"
GetPlayDetails = require "./GetPlayDetails"
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
    @closeInactiveQuestions = new CloseInactiveQuestions dependencies
    @getPlayDetails = new GetPlayDetails dependencies

  execute: ->

  create: (eventId, team, driveId) ->
    # Temp until mongodb objects can be created.
    @mults =
      option1:
        low: 2.15
        high: 2.37
        title: "Punt"
      option2:
        low: 2.5
        high: 2.91
        title: "Field Goal"
      option3:
        low: 4.6
        high: 6.42
        title: "Turnover"
      option4:
        low: 3.4
        high: 5.62
        title: "Touchdown"
      option5:
        low: 5.4
        high: 6.7
        title: "Turnover on Downs"
      option6:
        low: 15.9
        high: 21.61
        title: "Safety"

    Promise.bind @
      .then -> @Games.findOne {eventId: eventId}
      .then (result) ->
        @Questions.insert
          _id: @Questions.db.ObjectId().toString()
          dateCreated: new Date()
          gameId: result._id
          period: result.period
          teamId: team.teamId
          driveId: driveId
          type: "drive"
          active: true
          commercial: true
          que: "How Will " + team.location + " " +  team.nickname + " Drive End?"
          options: @mults
          usersAnswered: []
      # .then (result) -> console.log result

  resolve: (eventId, pbp, teams) ->
    Promise.bind @
      .then -> @Games.findOne {eventId: eventId}
      .then (result) -> @Questions.find {gameId: result._id, active: true, type: "drive"}
      .map (question) ->
        lastPlayInDrive = _.findLastIndex(pbp, {driveId: question.driveId})
        play = @getPlayDetails.execute pbp[lastPlayInDrive], teams

        if play.playDetails.type is "PAT"
          correctAnswer = "Touchdown"
        else if play.playDetails.type is "Def Penalty" || play.playDetails.type is "Off Penalty"
          correctAnswer = "Punt"
        else if play.playDetails.type is "Run" || play.playDetails.type is "Pass"
          correctAnswer = "Turnover on Downs"
        else if play.playDetails.type is "Interception" || play.playDetails.type is "Fumble"
          correctAnswer = "Turnover"
        else
          correctAnswer = play.playDetails.type

        # if play.playDetails.driveId is question.driveId

        options = _.map question.options, (option) -> return option['title']
        optionNum = options.indexOf(correctAnswer) + 1
        @outcome = "Option" + optionNum
        @questionId = question._id

        @logger.verbose "Closing [", question.driveId, "] ", question.que, "with", correctAnswer, @outcome
        Promise.bind @
          .then -> @Questions.update {_id: @questionId}, $set: {active: false, extendedDetails: play, outcome: @outcome, lastUpdated: new Date()}
          .then -> @closeInactiveQuestions.updateAnswers @questionId, @outcome
