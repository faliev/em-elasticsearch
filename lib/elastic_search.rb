require "eventmachine"
require "em-http-request"
require "json"

class ElasticSearch
  module HTTP
    def request method, path="/", options={}, &block
      options[:head] ||= {}
      options[:head].merge! "content-type" => "application/json"
      http = EM::HttpRequest.new(base_url + path).send(method, options)
      req  = EM::DefaultDeferrable.new
      req.callback &block if block

      http.callback {
        if http.response_header.status >= 400
          req.fail http
        else
          response = JSON.parse(http.response)
          req.succeed response
        end
      }
      http.errback { req.fail http }

      req
    end
  end

  class Client
    include HTTP

    attr_accessor :base_url

    def initialize url
      @base_url = url
    end

    def flush &block
      request :post, "/_flush", &block
    end

    def status &block
      request :get, "/_status", &block
    end

    def cluster
      @cluster ||= Cluster.new self
    end

    def index name
      Index.new self, name
    end
  end

  class Cluster
    include HTTP

    attr_reader :client

    def initialize client
      @client = client
    end

    def base_url
      client.base_url + "/_cluster"
    end

    def state &block
      request :get , "/state", &block
    end

    def indices
      state {|response|
        result = {}
        response["metadata"]["indices"].keys.map {|name|
          result[name] = Index.new(client, name)
        }
        yield result
      }
    end

    def delete_all_indices &block
      indices {|response|
        EM::Iterator.new(response.keys).map(lambda {|name, iter|
          client.request(:delete, "/" + name) {iter.return name}
        }, block)
      }
    end
  end

  class Index
    include HTTP

    attr_reader :client, :name

    def initialize client, name
      @client = client
      @name   = name
    end

    def base_url
      client.base_url + "/" + @name
    end

    def create &block
      request :put, "/", &block
    end

    def index type, id, doc, &block
      path = "/#{type}/#{id}"
      request :put, path, :body => doc.to_json, &block
    end

    def delete &block
      request :delete, &block
    end
  end
end
