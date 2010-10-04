require "./test/helper.rb"

Harry = {
  "_id"     => "harry",
  "type"    => "person",
  "name"    => "Harry Dynamite",
  "country" => "Denmark"
}

Joan = {
  "_id"     => "joan",
  "type"    => "person",
  "name"    => "Joan January",
  "country" => "USA"
}

Klaus = {
  "_id"     => "klaus",
  "type"    => "person",
  "name"    => "Klaus Denn",
  "country" => "Germany"
}

Indexer = Couchlastic::Indexer.new do |c|
  c.couch "http://127.0.0.1:5984/couchlastic"
  c.elastic "http://127.0.0.1:9200"

  c.index "notes" do |source, target|
    target.id = source["_id"]
    target.type = "person"
    target.source = source
    target
  end
end

class TestIndexer < ElasticTestCase
  setup do
    couch.recreate!
    couch.save_doc Harry
    couch.save_doc Joan
    couch.save_doc Klaus
    couch.delete_doc Klaus
  end

  def prepare &block
    elastic.cluster.delete_all_indices {
      Indexer.start
      EM.add_timer(2.5, block)
    }
  end

  test "index docs" do
    prepare {
      request = elastic.index("notes").type("person").get("joan")
      request.callback {|response|
        assert_equal "joan", response["_id"]
        assert_equal "Joan January", response["_source"]["name"]
        assert_equal "USA", response["_source"]["country"]
        done
      }
      request.errback { flunk "didn't index doc" }
    }
  end

  test "remove docs" do
    prepare {
      request = elastic.index("notes").type("person").get("klaus")
      request.callback { flunk "doc should be deleted" }
      request.errback { done }
    }
  end
end
