_ = require "underscore"
Match = require "mtr-match"
Promise = require "bluebird"
moment = require "moment"
Task = require "../../Task"

module.exports = class extends Task
  constructor: (dependencies) ->
    super

    Match.check dependencies, Match.ObjectIncluding
      mongodb: Match.Any

    @logger = @dependencies.logger
    @Games = dependencies.mongodb.collection("games")

  getPlay: (game) ->
    @game = game
    return game


  getEvents: (selector) ->  _.flatten _.pluck selector, 'pbpDetails'

  getLast: (plays) ->
    if plays and plays.length > 0
      plays[plays.length - 1]

  loopHalfs: (innings) ->
    array = _.map innings, (half) ->
      inning: half.inning
      inningDivision: half.inningDivision
      linescore: half.linescore
      pbpDetails: _.toArray _.map half.pbpDetails, (event) ->
        pbpDetailId: event.pbpDetailId
        sequence: event.sequence
        pitches: if event.pitches then event.pitches
        batter: if event.batter then event.batter
        pitchSequence: if event.pitchSequence then event.pitchSequence
        pitchDetails: if event.pitchDetails then event.pitchDetails
        playText: if event.playText then event.playText
    return  _.toArray array

  findSpecificEvent: (parms, eventNumber) ->
    Promise.bind @
      .then -> @Games.find {_id: parms.gameId}
      .then (game) -> @loopHalfs game[0]['pbp']
      .then (halfs) -> @getEvents halfs
      .then (events) -> events[eventNumber]
      .then (result) -> return result

  findAtBat: (question) ->
    Promise.bind @
      .then -> @Games.find {_id: question.gameId}
      .then (game) -> @loopHalfs game[0]['pbp']
      .then (halfs) -> @getEvents halfs
      .then (events) -> return events.reverse()
      .then (events) -> # Get all the events.
        for event in events
          if event.batter && question.playerId is event.batter.playerId
            console.log event.pitchDetails, event.playText
            return event
