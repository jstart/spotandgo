require 'sinatra'
require 'sinatra/json'
require 'factual'
require 'httparty'
require 'json'
require 'pp'

FACTUAL_OAUTH_KEY = 'JfIFEBzOotfWpiPmzXuyyvxeOcrl7vgfUHfaPG4F'
FACTUAL_OAUTH_SECRET = 'Ps81zejoOIcKXADRfytX5M6bvOLINyrPTeLBRpmc'
JEPPESEN_API_KEY = '5af6d8a5-f1e9-4893-a0a4-30095fced29b'
CATEGORY= {
  eat: {
    category: 'Food & Beverage > Restaurants',
    distance: 500
  },
  shop: {
    category: 'Shopping',
    distance: 500
  },
  watch: {
    category: 'Arts, Entertainment & Nightlife > Movie Theatres',
    distance: 500 
  },
  play: {
    category: 'Arts, Entertainment & Nightlife',
    distance: 500
  }
}

@@factual = Factual.new(FACTUAL_OAUTH_KEY, FACTUAL_OAUTH_SECRET)

post '/category' do
  params = JSON.parse(request.body.read)
  response = findLocal(CATEGORY[params['category'].to_sym][:category], params['location'], CATEGORY[params['category'].to_sym][:distance], 4)
  json(response, :encoder => :to_json)
end

post '/location' do
  params = JSON.parse(request.body.read)
  start = "#{params['current_latitude']},#{params['current_longitude']}"
  destination = "#{params['destination_latitude']},#{params['destination_longitude']}"
  response = getRoute(start, destination)
  json(response, :encoder => :to_json)
end

def findLocal(category, location, distance, limit)
  rows = @@factual.table('places').geo('$circle' => {'$center' => location, '$meters' => distance}).filters({'category' => category}).limit(limit).rows
  response = rows.inject([]) do |sum, row|
    sum << getDetails(row)
  end

  response 
end

def getDetails(row)
  {
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
  if Integer(JSON.parse(res.body)['Status']['Severity']) == 0
      polyLines = JSON.parse(res.body)['Journeys'].first['Legs'].first['Polyline']

    res = HTTParty.get("http://maps.googleapis.com/maps/api/directions/json?origin=#{start}&destination=#{destination}&mode=walking&waypoints=#{polyLines.gsub(/;/, '%7C').gsub(/\s/, '')}&sensor=false")
    directions = JSON.parse(res.body)['routes'].first['legs'].inject([]) do |sum, leg|
      sum << leg['steps'].inject([]) do |sum, step|
        sum << step['html_instructions']
      end
    end
  

    if directions.nil?
      directions = []
    end
    directions.flatten!.uniq!.map! do |direction|
      direction.gsub!( %r{</?[^>]+?>}, '' )
    end

    {polylines: polyLines, directions: directions}
  else
    {status: JSON.parse(res.body)['Status']}
  end
end
