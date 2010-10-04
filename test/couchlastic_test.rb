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
  c.couch "http://localhost:5984/couchlastic"
  c.elastic "http://localhost:9200"

  c.index "persons" do |doc|
    {
      :type     => "person",
      :document => doc
    }
  end
end

class TestIndexer < ElasticTestCase
  setup do
    couch.recreate!
    couch.save_doc harry
    couch.save_doc joan
    couch.save_doc klaus
    couch.delete_doc klaus
    Indexer.start
  end

  test "index docs" do
    elastic.cluster.delete_all_indices {
      EM.add_timer(0.5) {
        elastic.index("notes").get {|response|
        req.callback do |response|
          response["_id"].should == "joan"
          response["_source"].should == {
            "name"    => "Joan January",
            "country" => "USA"
          }
          done
        end
      }
    }
  end

  it "removes docs" do
    EM.add_timer(0.5) {
      req = elastic.get(:index => "notes", :type => "person", :id => "klaus")
      req.callback { should.flunk "doc should be deleted" }
      req.errback { done }
    }
  end
end
