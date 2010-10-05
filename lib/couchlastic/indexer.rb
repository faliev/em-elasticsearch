require "couchchanges"
require "em-elasticsearch"

module Couchlastic
  class Indexer
    def initialize
      @indices = {}
      @mappings = {}
      yield self if block_given?
    end

    attr_accessor :couch

    attr_reader :elastic

    def elastic= url
      @elastic = EventMachine::ElasticSearch::Client.new(url)
    end

    def map name, mapping
      @mappings[name] = mapping
    end

    def index name, &block
      @indices[name] = block
    end

    def start
      EM::Iterator.new(@mappings).each(lambda {|hash, iter|
        name, type = hash[0].split("/")
        mapping    = hash[1]
        index      = elastic.index(name)

        index.create {
          index.type(type).map(mapping) {iter.next}
        }
      }, lambda {
        changes = CouchChanges.new
        changes.update {|change|
          Couchlastic.logger.info "Indexing sequence #{change["seq"]}"
          @indices.each {|name, block|
            doc = block.call change
            if doc
              type = elastic.index(name).type(doc[:type])
              type.index(doc[:id], doc[:doc])
            end
          }
        }
        changes.listen :url => @couch, :include_docs => true
      })
    end
  end
end
