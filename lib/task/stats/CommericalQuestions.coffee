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
CloseInactiveQuestions = require "./CloseInactiveQuestions"

module.exports = class extends Task
  constructor: (dependencies) ->
    super

    Match.check dependencies, Match.ObjectIncluding
      mongodb: Match.Any

    @logger = @dependencies.logger
    @Games = dependencies.mongodb.collection("games")
    @Multipliers = dependencies.mongodb.collection("multipliers")
    @Questions = dependencies.mongodb.collection("questions")
    @QuestionTemplates = dependencies.mongodb.collection("questionTemplates")
    @Teams = dependencies.mongodb.collection("teams")
    @Answers = dependencies.mongodb.collection("answers")
    @GamePlayed = dependencies.mongodb.collection("gamePlayed")
    @Users = dependencies.mongodb.collection("users")
    @Notifications = dependencies.mongodb.collection("notifications")
    @gameParser = new GameParser dependencies
    @endOfGame = new EndOfGame dependencies
    @closeInactiveQuestions = new CloseInactiveQuestions dependencies

  execute: ->
    Promise.bind @

  create: (eventId) ->
    options =
      option1:
        low: 2.15
        high: 2.37
        multiplier: (Math.random() * (2.37-2.15) + 2.15).toFixed(1)
        title: "True"
      option2:
        low: 2.15
        high: 2.37
        multiplier: (Math.random() * (2.37-2.15) + 2.15).toFixed(1)
        title: "False"

    Promise.bind @
      .then ->@Games.findOne {eventId: eventId}
      .then (result) ->
        @Questions.insert
          _id: @Questions.db.ObjectId().toString()
          dateCreated: new Date()
          gameId: result._id
          period: result.period
          length: "drive"
          # driveId: driveId
          requirements:
            typeId: [10, 11]
            penaltyId: 14
          type: "freePickk"
          active: true
          commercial: true
          que: "Will There be a Penalty on this Drive?"
          options: options
          usersAnswered: []

  resolveAll: (eventId, playDetails, endOfDrive) ->
    Promise.bind @
      .then -> @getGame eventId
      .then (game) ->
        @Questions.find {
          gameId: game._id,
          period: game.period,
          commercial: true,
          type: "freePickk",
          active: true
        }
      .map (question) -> @resolve question, playDetails, endOfDrive

  resolve: (question, playDetails, endOfDrive)->
    requirementsChecked = @checkDetailsToRequirements question.requirements, playDetails.playDetails

    if requirementsChecked || endOfDrive is true
      outcome = if requirementsChecked is true then ["option1"] else ["option2"]
      Promise.bind @
        .then -> @closeInactiveQuestions.updateQuestionAndAnswers question._id, outcome

  checkDetailsToRequirements: (requirements, details) ->
    keys = _.allKeys requirements
    obj = {}

    _.map keys, (key) ->
      questionValue = requirements[key]
      playValue = details[key]

      if questionValue is playValue
        obj[key] = true

      else if _.isArray questionValue
        if (questionValue.indexOf playValue) > -1
          obj[key] = true
        else
          obj[key] = false

      else
        obj[key] = false

    return Object.keys(obj).every (key) ->
      obj[key]

      # Check if any of them match the requirements
      # If its a partial match update the question
      # If they do award winners and close question

  getGame: (id) ->
    Promise.bind @
      .then -> @Games.findOne({eventId: id})

  # matchesRequirements: (question, play) ->
  #   # perfect = @perfectMatch question.requirements, play.playDetails
  #   Promise.any @
  #     .then -> @perfectMatch question.requirements, play.playDetails
  #     # .then -> @arrayMatch question.requirements, play.playDetails
  #     # .then -> @partialMatch question.requirements, play.playDetails
  #
  # perfectMatch: (requirements, details) ->
  #   if @checkDetailsToRequirements requirements, details
  #     Promise.bind @
  # partialMatch: (requirements, details) ->
