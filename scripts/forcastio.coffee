# Description:
#   Look up the weather using google for geocoding and forecast.io for weather data
#
# Dependencies:
#   Underscore
#   Sparklines
#
# Configuration:
#   FORECAST_IO_API_KEY
#
# Commands:
#   weather in {location}
#   temps for {location}

API_KEY = process.env.FORECAST_IO_API_KEY
GOOGLE_ENDPOINT = "http://maps.googleapis.com/maps/api/geocode/json"
FORCAST_ENDPOINT = "https://api.forecast.io/forecast/#{API_KEY}"

DIRECTIONS = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]

_ = require 'underscore'
sparkline = require 'sparkline'

angleToDirection = (angle) ->
  num = Math.round(((angle - 22.5) / 45) % 8)
  DIRECTIONS[num]

# Params:
#   latLong = Object literal with keys lat and lng
formatLatLong = (latLong) ->
  "#{latLong.lat},#{latLong.lng}"

formatTemp = (temp) ->
  temp.toFixed(1) + "°F"

formatDate = (unix) ->
  date = new Date(unix * 1000)
  date.toString()

currently = (current, minutes) ->
  """
  Currently it is #{formatTemp(current.temperature)} (feels like #{formatTemp(current.apparentTemperature)}).
  Wind is #{current.windSpeed}mph out of #{angleToDirection(current.windBearing)} with a #{current.precipProbability}% chance of rain.
  #{minutes.summary}
  """

nextHour = (hourly) ->
  hourly.summary

nextDays = (daily) ->
  daily.summary

sparklineTemp = (hours) ->
  start = _.first(hours)
  end = _.last(hours)

  temps = _.map hours, (hour) ->
    hour.temperature

  min = _.min(temps)
  max = _.max(temps)

  """
  From #{formatDate(start.time)} to #{formatDate(end.time)}
  Min: #{formatTemp(min)}, Max: #{formatTemp(max)}
  #{sparkline(temps)}
  """

fetchForcast = (msg, location, callback) ->
  requestedLocation = encodeURI(location)

  msg.http("#{GOOGLE_ENDPOINT}?address=#{requestedLocation}&sensor=false").get() (err, resp, body) ->
    geoResp = JSON.parse body
    latLong = geoResp.results[0].geometry.location

    msg.http("#{FORCAST_ENDPOINT}/#{formatLatLong(latLong)}").get() (err, resp, body) ->
      forcast = JSON.parse(body)
      callback.call(@, forcast)

module.exports = (robot) ->
  robot.hear /weather( in)? (.*)/i, (msg) ->
    requestedLocation = msg.match[2]

    fetchForcast msg, requestedLocation, (forcast) ->
      msg.send [currently(forcast.currently, forcast.minutely), nextHour(forcast.hourly), nextDays(forcast.daily)].join("\n")

  robot.hear /temps( for)? (.*)/i, (msg) ->
    requestedLocation = msg.match[2]

    fetchForcast msg, requestedLocation, (forcast) ->
      msg.send sparklineTemp(forcast.hourly.data)
