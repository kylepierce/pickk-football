Match = require "mtr-match"
request = require "request-promise"
dateFormat = require 'dateformat'
_ = require "underscore"
Promise = require "bluebird"
promiseRetry = require 'promise-retry'
moment = require "moment"
crypto = require "crypto"

HOST = "http://api.stats.com/"
NFL = "v1/stats/football/nfl/"

formatPattern = Match.Where (format) -> format in ["json", "xml"]

module.exports = class
  constructor: (options) ->
    Match.check options, Match.ObjectIncluding
      apiKey: String
      secret: String

    @host = HOST
    @nfl = NFL
    @key = options.apiKey
    @secret = options.secret

  _nflRequest: (path, options = {}) ->
    @_request @nfl + path, options

  _request: (path, options = {}) ->
    Match.check path, String

    @timeFromEpoch = moment.utc().unix();
    @sig = crypto.createHash('sha256').update(@key + @secret + @timeFromEpoch).digest('hex');
    uri = @host + path + "/?api_key=" + @key + "&sig=" + @sig

    _.defaults options,
      uri: uri
      json: true

    options.qs ?= {}
    _.defaults options.qs,
      api_key: @key

    promiseRetry (retry, number) =>
      Promise.bind @
      .then -> request options
      .catch (error) ->
        # TODO @logger
        console.log error.message #, _.extend({stack: error.stack}, error.details)
        retry(error)

  getScheduledGames: (days, format = "json") ->
    Match.check days, Number
    Match.check format, formatPattern

    date = new Date()
    # cast to EDT timezone
    EDT_OFFSET = 60 * 12
    date = moment(date).subtract(EDT_OFFSET + moment(date).utcOffset(), 'minutes').toDate()

    formattedDate = dateFormat(date, "yyyy-mm-dd")
    lastDate = moment().add(days, "days").toDate()
    formattedLastDate = dateFormat(lastDate, "yyyy-mm-dd")

    path = "events/?startDate=#{formattedDate}&endDate=#{formattedLastDate}&accept=#{format}"
    @_nflRequest path

  getPlayByPlay: (gameId, format = "json") ->
    Match.check gameId, Number
    Match.check format, formatPattern

    path = "events/#{gameId}?pbp=true&accept=#{format}"
    @_nflRequest path

  # getTeamProfile: (teamId, format = "json") ->
  #   Match.check teamId, Number
  #   Match.check format, formatPattern
  #
  #   path = "teams/#{teamId}"
  #   @_nflRequest path
  #
  # getTeamPlayers: (teamId, format = "json") ->
  #   Match.check teamId, Number
  #   Match.check format, formatPattern
  #
  #   path = "participants/teams/#{teamId}"
  #   @_nflRequest path
