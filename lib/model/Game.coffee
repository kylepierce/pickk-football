Match = require "mtr-match"
_ = require "underscore"
moment = require "moment"

module.exports = class
  constructor: (data) ->
    Match.check data, Object

    _.extend @, data

    away = @['teams'][1]
    home = @['teams'][0]
    scoring =
      home:
        id: home.teamId
        name: home.nickname
        abbr: home.abbreviation
        runs: home.score
      away:
        id: away.teamId
        name: away.nickname
        abbr: away.abbreviation
        runs: away.score

    @id = @['eventId']
    # @commercial = false
    @home = home
    @home_team = home.teamId
    @away = away
    @away_team = away.teamId
    @scoring = scoring
    @scheduled = moment(@['startDate'][1]['full']).toDate()
    @iso =  new Date(@['startDate'][1]['full']).toISOString()
    @name = "#{home.nickname} vs #{away.nickname}"
    @sport = "NFL"
    @period = @['eventStatus']['period']
    @tv = if @['tvStations'][0] then @['tvStations'][0].callLetters else "No TV"
    @live = @['eventStatus']['name'] is "In-Progress"
    @status = @['eventStatus']['name']
    @football = true
    @completed = @status in ['Complete', 'Closed']
    @location = if @['pbp'].length > 0 then (_.last @pbp).endYardLine

  getSelector: ->
    "eventId": @['eventId']
