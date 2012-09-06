require 'net/http'
require "addressable/uri"

module CityGridApi
  class Error < StandardError
    def initialize(path, result)
      @path = path
      @result = result
    end

    def to_s
      "Error requesting '#{@path}': #{@result.try(:code)} '#{@result.try(:body)}'"
    end

  end

  class Request
    attr_reader :api_data

    def do_request
      Net::HTTP.start(CityGridApi::HOST, CityGridApi::PORT) do |http|
        http.read_timeout = CityGridApi::READ_TIMEOUT
        path = request_path(:publisher => CityGridApi::PUBLISHER_ID)
        begin
          res = http.get(path)
        rescue Timeout::Error
          Rails.logger.warn("Timeout accessing CityGrid API!")
          return
        end
        return if res.code == '404'
        raise Error.new(path, res) unless res.code == '200'

        @api_data = JSON.parse(res.body)
      end
    end
  end

  class Place < Request
    def self.find(listing_id, client_ip)
      place = new(listing_id, client_ip)
      begin
        place.do_request
        return place if place.api_data
      rescue Exception => e
        Rails.logger.error("Error accessing CityGrid API: #{e.inspect}")
        return nil
      end
    end

    def initialize(listing_id, client_ip)
      @listing_id = listing_id
      @client_ip = client_ip
    end

    def request_path(defaults)
      options = defaults.update({
                                    :id => @listing_id,
                                    :id_type => 'cs',
                                    :customer_only => false,
                                    :review_count => 0,
                                    :client_ip => @client_ip,
                                    :format => 'json',
                                })
      CityGridApi::PLACE_PATH + '?' + options.to_query
    end

    def do_request
      super
      locations = @api_data && @api_data['locations']
      if locations && locations.length > 0
        @api_data = locations.first
      end
    end

    def name
      @api_data && @api_data['name']
    end

    def phone
      @api_data && @api_data['contact_info'] && @api_data['contact_info']['display_phone']
    end

    def address
      @api_data && @api_data['address']
    end

    def address_1
      @api_data && @api_data['address']['street']
    end

    def address_2
      @api_data && @api_data['address']['delivery_point']
    end

    def external_url
      @api_data && @api_data['urls'] && @api_data['urls']['website_url']
    end

    def profile_url
      @api_data && @api_data['urls'] && @api_data['urls']['profile_url']
    end
    
    def email_link
      @api_data && @api_data['urls'] && @api_data['urls']['email_link']
    end

    def advertiser_message
      @api_data && @api_data['customer_content']
    end

    def offers
      @api_data && @api_data['offers']
    end

    def reservation_url
      @api_data && @api_data['urls'] && @api_data['urls']['reservation_url']
    end

    def video_url
      @api_data && @api_data['urls'] && @api_data['urls']['video_url']
    end

    def city
      @api_data && @api_data['address']['city']
    end

    def state
      @api_data && @api_data['address']['state']
    end

    def zip
      @api_data && @api_data['address']['postal_code']
    end

    def customer_message
      @api_data && @api_data['customer_content']['customer_message']['value']
    end

    def attribution_text
      @api_data && @api_data['customer_content']['customer_message']['attribution_text']
    end

    def attribution_logo
      @api_data && @api_data['customer_content']['customer_message']['attribution_logo']
    end

    def customer_message_url
      @api_data && @api_data['customer_content']['customer_message_url']
    end

    def categories
      @api_data && @api_data['categories']
    end

    def lat
      @api_data && @api_data['address']['latitude']
    end

    def lng
      @api_data && @api_data['address']['longitude']
    end

  end

  class Search < Request
    def self.find(where, params = {})
      new(where, params).do_request
    end

    def initialize(where, params = {})
      @where = where
      @what = params[:what]
      @type = params[:type]
      @lat = params[:lat]
      @lon = params[:lon]
    end

    def request_path(defaults)
      options = defaults.update({
                                    :where => @where,
                                    :format => 'json',
                                })

      options.update(:what => @what) if @what
      options.update(:type => @type) if @type

      CityGridApi::SEARCH_PATH + '?' + options.to_query
    end
  end
  
  class LatLonSearch < Request
    def self.find(params = {})
      new(params).do_request
    end

    def initialize(params = {})
      @what = params[:what]
      @type = params[:type]
      @tag = params[:tag]
      @lat = params[:lat]
      @lon = params[:lon]
      @rpp = params[:rpp]
      @page = params[:page]
      @sort = params[:sort]
      @radius = params[:radius]
    end

    def request_path(defaults)
      options = defaults.update({
                                    :format => 'json',
                                })

      options.update(:what => @what) if @what
      options.update(:type => @type) if @type
      options.update(:tag => @tag) if @tag
      options.update(:lat => @lat) if @lat
      options.update(:lon => @lon) if @lon
      options.update(:rpp => @rpp) if @rpp
      options.update(:page => @page) if @page
      options.update(:sort => @sort) if @sort
      options.update(:radius => @radius) if @radius
		  uri = Addressable::URI.new
			uri.query_values = options
		  
      CityGridApi::LATLON_PATH + '?' + uri.query
    end
  end

end
