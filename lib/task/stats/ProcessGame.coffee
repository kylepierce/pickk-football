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
CloseInactiveQuestions = require "./CloseInactiveQuestions"
CommercialQuestions = require "./CommericalQuestions"
DriveQuestions = require "./DriveQuestions"

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
    @closeInactiveQuestions = new CloseInactiveQuestions dependencies
    @createPlayQuestions = new CreatePlayQuestions dependencies
    @endOfGame = new EndOfGame dependencies
    @getPlayDetails = new GetPlayDetails dependencies
    @commercialQuestions = new CommercialQuestions dependencies
    @driveQuestions = new DriveQuestions dependencies

  execute: (old, update) ->
    @checkCommercialStatus old._id, old.commercialTime

    if old.pbp
      oldPlays = old.pbp.length
      newPlays = update.pbp.length
    if @isNewPlay newPlays, oldPlays
      @gameTeams = update.teams
      @updatedPbp = update.pbp
      previousPlay = (_.last update.pbp)
      playDetails = @getPlayDetails.execute previousPlay, @gameTeams

      Promise.bind @
        .then -> @endCommercialBreak old.eventId
        .then -> @closeInactiveQuestions.execute update.id, @gameTeams
        .then -> @commercialQuestions.resolveAll update.id, playDetails, false
        # .then -> @gameInProgress old.eventId
        .then -> @startCommercialBreak old.eventId, playDetails
        .then -> @createPlayQuestions.execute update.eventId, playDetails

  isNewPlay: (newLength, oldLength) ->
    if newLength > oldLength
      return true

  createCommercialQuestions: (eventId, previous) ->

  startCommercialBreak: (eventId, previous) ->
    list = ["Punt", "PAT", "Field Goal", "Turnover", "Turnover on Downs", "Safety"]
    if (list.indexOf(previous.playDetails.type) > -1)

      correctTeam = @correctTeam previous.playDetails.teamId, @gameTeams
      drive = parseInt(previous.playDetails.driveId) + 1

      Promise.bind @
        # .then -> @commericalQuestions.resolveAll eventId, previous, true
        .then -> @commercialQuestions.create eventId
        .then -> @driveQuestions.resolve eventId, @updatedPbp, @gameTeams
        .then -> @driveQuestions.create eventId, correctTeam, drive
        .then -> @Games.update({eventId: eventId}, {$set: {commercial: true, commercialTime: new Date}})

  correctTeam: (lastTeam, teams) ->
    index = _.findIndex(teams, {teamId: lastTeam})
    correctTeam = if index is 0 then teams[1] else teams[0]
    return correctTeam

  checkCommercialStatus: (eventId, oldTime) ->
    newTime =  new Date
    commercialBreak = @dependencies.settings['common']['commercialTime']
    if oldTime
      oldTime = new Date moment(oldTime).add commercialBreak, "seconds"
      if newTime > oldTime
        @endCommercialBreak eventId

  # gameInProgress: (eventId) ->
  #   Promise.bind @
  #     .then -> @getGame eventId
  #     .then (game) ->
  #       if game.commercial is true
  #         console.log "Game has resumed already!!"
  #         @endCommercialBreak eventId

  endCommercialBreak: (eventId) ->
    Promise.bind @
      .then -> @getGame eventId
      .then (game) ->
          Promise.bind @
            .then -> @Games.update({eventId: eventId}, {$set: {commercial: false}, $unset: {commercialTime: 1}})

  getGame: (id) ->
    Promise.bind @
      .then -> @Games.findOne({eventId: id})
