require 'net/http'
require 'net/https'
require 'uri'
require 'rack/utils'

module Appsignal
  class Transmitter
    CONTENT_TYPE = 'application/json; charset=UTF-8'.freeze
    CONTENT_ENCODING = 'gzip'.freeze
    CA_FILE_PATH = File.
      expand_path(File.join(__FILE__, '../../../resources/cacert.pem'))

    attr_reader :endpoint, :action, :api_key

    def initialize(endpoint, action, api_key, logger=nil)
      @endpoint = endpoint
      @action = action
      @api_key = api_key
    end

    def uri
      @uri ||= URI("#{@endpoint}/#{@action}").tap do |uri|
        uri.query = Rack::Utils.build_query({
          :api_key => api_key,
          :hostname => Socket.gethostname,
          :gem_version => Appsignal::VERSION
        })
      end
    end

    def transmit(payload)
      http_client.request(http_post(payload)).code
    end

    protected

    def http_post(payload)
      Net::HTTP::Post.new(uri.request_uri).tap do |request|
        request[:'Content-Type'] = CONTENT_TYPE
        request[:'Content-Encoding'] = CONTENT_ENCODING
        request.body = Zlib::Deflate.
          deflate(Appsignal.json.encode(payload), Zlib::BEST_SPEED)
      end
    end

    def http_client
      Net::HTTP.new(uri.host, uri.port).tap do |http|
        if uri.scheme == 'https'
          http.use_ssl = true
          http.verify_mode = OpenSSL::SSL::VERIFY_PEER
          http.ca_file = CA_FILE_PATH
        end
      end
    end
  end
end
