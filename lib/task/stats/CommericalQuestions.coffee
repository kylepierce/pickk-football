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

  execute: ->
    Promise.bind @

  create: (gameId, numberToCreate) ->
    Promise.bind @
      # Select two random
      # Create question

  resolveAll: (gameId, playDetails) ->
    # Find open questions.
    Promise.bind @
      .then -> @Questions.find {gameId: gameId, commercial: true, active: true}
      .map (question) -> @resolve questionId, playDetails, true

  resolve: (questionId, playDetails, endOfDrive)->
    Promise.bind @
      # Check if any of them match the requirements
      # If they do award winners and close question
