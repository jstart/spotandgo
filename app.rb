require 'sinatra'
require 'sinatra/json'
require 'factual'
require 'httparty'
require 'json'

FACTUAL_OAUTH_KEY = 'JfIFEBzOotfWpiPmzXuyyvxeOcrl7vgfUHfaPG4F'
FACTUAL_OAUTH_SECRET = 'Ps81zejoOIcKXADRfytX5M6bvOLINyrPTeLBRpmc'
JEPPESEN_API_KEY = '5af6d8a5-f1e9-4893-a0a4-30095fced29b'
CATEGORY= {
  eat: {
    category: 'Food & Beverage > Restaurants',
    distance: 805
  },
  shop: {
    category: 'Shopping',
    distance: 609
  },
  watch: {
    category: 'Arts, Entertainment & Nightlife > Movie Theatres',
    distance: 8047
  },
  play: {
    category: 'Arts, Entertainment & Nightlife',
    distance: 8047
  }
}

@@factual = Factual.new(FACTUAL_OAUTH_KEY, FACTUAL_OAUTH_SECRET)

post '/category' do
  params = JSON.parse(request.body.read)
  response = findLocal(CATEGORY[params['category'].to_sym][:category], params['location'], CATEGORY[params['category'].to_sym][:distance], 4)
  json(response, :encoder => :to_json)
end

post '/location' do
  # factual_id
end

def findLocal(category, location, distance, limit)
  rows = @@factual.table('places').geo('$circle' => {'$center' => location, '$meters' => distance}).filters({'category' => category}).limit(limit).rows
  response = rows.inject([]) do |sum, row|
    sum << getDetails(row)
  end

  response 
end

def getDetails(row)
  return {
    name: row['name'],
    address: "#{row['address']} #{row['locality']}, #{row['region']}, #{row['postcode']}",
    phone: row['tel'],
    website: row['website'],
    latitude: row['latitude'],
    longitude: row['longitude'],
    factual_id: row['factual_id']
  }
end

def getRoute(start, destination)
  res = HTTParty.get("http://journeyplanner.jeppesen.com/JourneyPlannerService/V2/REST/DataSets/LosAngeles/JourneyPlan?from=#{start}&to=#{destination}&date=2012-04-28T12:00&timeMode=&MappingDataRequired=true&timeoutInSeconds=&maxWalkDistanceInMetres=&walkSpeed=&maxJourneys=&returnFareData=&maxChanges=&transportModes=&serviceProviders=&checkRealTime=&transactionId=&ApiKey=5af6d8a5-f1e9-4893-a0a4-30095fced29b&format=json")
  polyLines = JSON.parse(res.body).inject([]) do |sum, waypoint|
    sum << waypoint['value'].split(',')
  end

  res = HTTParty.get("http://maps.googleapis.com/maps/api/directions/json?origin=#{start}&destination=#{destination}&mode=walking&waypoints=#{polylines.slice(1, -2).join}&sensor=false")
  directions = JSON.parse(res.body).inject([]) do |sum, waypoint|
  end

  polyLines
end
