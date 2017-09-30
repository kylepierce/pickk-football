_ = require "underscore"
Match = require "mtr-match"
Promise = require "bluebird"
Task = require "../Task"
moment = require "moment"
promiseRetry = require 'promise-retry'
CloseInactiveQuestions = require "./CloseInactiveQuestions"

module.exports = class extends Task
  constructor: (dependencies) ->
    super

    Match.check dependencies, Match.ObjectIncluding
      mongodb: Match.Any

    @logger = @dependencies.logger
    @Games = dependencies.mongodb.collection("games")
    @Questions = dependencies.mongodb.collection("questions")
    @QuestionTemplate = dependencies.mongodb.collection("questionTemplate")
    @Answers = dependencies.mongodb.collection("answers")
    @GamePlayed = dependencies.mongodb.collection("gamePlayed")
    @Users = dependencies.mongodb.collection("users")
    @Notifications = dependencies.mongodb.collection("notifications")
    @closeInactiveQuestions = new CloseInactiveQuestions dependencies

  execute: ->
    Promise.bind @

  create: (gameId, questionTemplateId) ->
    Promise.bind @
      .then -> @QuestionTemplate.findOne({_id: questionTemplateId})
      .then (result) -> @insertQuestion gameId, result

  insertQuestion: (gameId, qt) ->
    Promise.bind @
      .then -> @Games.findOne {_id: gameId}
      .then (result) ->
        driveId = _.last(result.pbp).driveId
        @Questions.insert
          _id: @Questions.db.ObjectId().toString()
          dateCreated: new Date()
          gameId: result._id
          period: result.period
          length: qt.length
          driveId: driveId + 1
          type: qt.type
          active: true
          commercial: true
          que: qt.que
          options: @parseOptions qt.options
          usersAnswered: []

  parseOptions: (options) ->
    updated = {}
    counter = 1
    _.mapObject options, (option, key) ->
      if !option.hasOwnProperty("multiplier")
        max = parseFloat option.high
        min = parseFloat option.low
        multi = (Math.random() * (max-min) + min).toFixed(1)
        option.multiplier = multi

      req = JSON.stringify(option.requirements)
      console.log "ParseOptions", req, option.requirements
      option.requirements = JSON.parse(option.requirements)

      updated["option" + counter] = option
      counter++

    return updated

  resolveAll: (gameId, playDetails, length, endOf) ->
    Promise.bind @
      .then -> @Games.findOne({_id: gameId})
      .then (game) ->
        @Questions.find {
          gameId: game._id,
          period: game.period,
          commercial: true,
          length: {$in: length}
          type: {$ne: "drive"},
          active: true
        }
      .map (question) -> @resolve question, playDetails, endOf

  resolve: (question, playDetails, endOf)->
    outcomes = @checkDetailsToRequirements question.options, playDetails.playDetails

    if endOf is "drive"
      outcomes = ['option2']

    if outcomes.length > 0
      Promise.bind @
        .then -> @closeInactiveQuestions.updateQuestionAndAnswers question._id, outcomes

  checkDetailsToRequirements: (options, details) ->
    outcome = []
    _.each options, (option, i) ->
      req = option.requirements
      if req is null || req is "null"
        return false
      keys = _.allKeys req
      obj = {}

      _.map keys, (key) ->
        questionValue = req[key]
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

      allGood = Object.keys(obj).every (key) ->
        obj[key]

      if allGood is true
        outcome.push(i)

    return outcome

    # Check if any of them match the requirements
    # If its a partial match update the question
    # If they do award winners and close question

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
