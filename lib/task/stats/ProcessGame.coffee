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
    @QuestionTemplate = dependencies.mongodb.collection("questionTemplate")
    @Questions = dependencies.mongodb.collection("questions")
    @Teams = dependencies.mongodb.collection("teams")
    @closeInactiveQuestions = new CloseInactiveQuestions dependencies
    @createPlayQuestions = new CreatePlayQuestions dependencies
    @endOfGame = new EndOfGame dependencies
    @getPlayDetails = new GetPlayDetails dependencies
    @commercialQuestions = new CommercialQuestions dependencies
    @driveQuestions = new DriveQuestions dependencies

  execute: (old, update) ->
    @checkCommercialStatus update.eventId

    if old.pbp
      oldPlays = old.pbp.length
      newPlays = update.pbp.length
    if @isNewPlay newPlays, oldPlays
      @gameTeams = update.teams
      @updatedPbp = update.pbp
      previousPlay = (_.last update.pbp)
      playDetails = @getPlayDetails.execute previousPlay, @gameTeams
      all = ["drive", "period", "half", "game"]

      Promise.bind @
        .then -> @endCommercialBreak old.eventId
        .then -> @closeInactiveQuestions.execute update.id, @gameTeams
        .then -> @commercialQuestions.resolveAll update.id, playDetails, all
        # .then -> @gameInProgress old.eventId
        .then -> @startCommercialBreak update.eventId, playDetails
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
        .then -> @commercialQuestions.resolveAll eventId, previous, ["drive"], "drive"
        .then -> @getCommercialBreakQuestion "NFL", "drive", 2
        .map (templateId) -> @commercialQuestions.create eventId, templateId
        .then -> @driveQuestions.resolve eventId, @updatedPbp, @gameTeams
        .then -> @driveQuestions.create eventId, correctTeam, drive
        .then -> @Games.update({eventId: eventId}, {$set: {commercial: true, commercialTime: new Date}})

  getCommercialBreakQuestion: (sport, length, number) ->
    query = {sport: sport, length: length}
    Promise.bind @
      .then -> @QuestionTemplate.count(query)
      .then (count) -> return Math.floor(Math.random() * count)
      .then (randomNum) -> @QuestionTemplate.find(query).limit(number).skip(randomNum);
      .map (template) -> return template._id

  correctTeam: (lastTeam, teams) ->
    index = _.findIndex(teams, {teamId: lastTeam})

    if index is 0
      correctTeam = teams[1]
    else if index is 1
      correctTeam = teams[0]

    return correctTeam

  checkCommercialStatus: (eventId) ->
    newTime =  moment(new Date).toISOString()
    commercialBreak = @dependencies.settings['common']['commercialTime']
    Promise.bind @
      .then -> @getGame eventId
      .then (game) ->
        if game.commercialTime
          oldTime = moment(game.commercialTime).add(commercialBreak, 'seconds').toISOString()
          if newTime > oldTime
            Promise.bind @
              .then -> @endCommercialBreak eventId


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
          # .then -> @Questions.update({gameId: game._id, period: game.period, active: true, commercial: false}, {$set: {dateCreated: new Date()}})
          # .then (result) -> console.log "Reactivated:", result.que

  getGame: (id) ->
    Promise.bind @
      .then -> @Games.findOne({eventId: id})
