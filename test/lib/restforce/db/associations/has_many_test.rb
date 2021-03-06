require_relative "../../../../test_helper"

describe Restforce::DB::Associations::HasMany do

  configure!
  mappings!

  let(:association) { Restforce::DB::Associations::HasMany.new(:details, through: "CustomObject__c") }

  it "sets the lookup field" do
    expect(association.lookup).to_equal "CustomObject__c"
  end

  describe "#fields" do

    it "returns nothing (since the lookup field is external)" do
      expect(association.fields).to_equal []
    end
  end

  describe "with an inverse mapping", :vcr do
    let(:inverse_mapping) do
      Restforce::DB::Mapping.new(Detail, "CustomObjectDetail__c").tap do |map|
        map.fields = { name: "Name" }
        map.associations << Restforce::DB::Associations::BelongsTo.new(
          :custom_object,
          through: "CustomObject__c",
        )
      end
    end
    let(:object_salesforce_id) { Salesforce.create!(mapping.salesforce_model) }
    let(:detail_salesforce_ids) do
      [
        Salesforce.create!(
          inverse_mapping.salesforce_model,
          "Name" => "First Detail",
          "CustomObject__c" => object_salesforce_id,
        ),
        Salesforce.create!(
          inverse_mapping.salesforce_model,
          "Name" => "Second Detail",
          "CustomObject__c" => object_salesforce_id,
        ),
        Salesforce.create!(
          inverse_mapping.salesforce_model,
          "Name" => "Third Detail",
          "CustomObject__c" => object_salesforce_id,
        ),
      ]
    end

    before do
      Restforce::DB::Registry << mapping
      Restforce::DB::Registry << inverse_mapping
      mapping.associations << association
    end

    describe "#synced_for?" do
      let(:salesforce_instance) { mapping.salesforce_record_type.find(object_salesforce_id) }

      describe "when no matching associated record has been synchronized" do

        it "returns false" do
          expect(association).to_not_be :synced_for?, salesforce_instance
        end
      end

      describe "when a matching associated record has been synchronized" do
        before do
          detail_salesforce_ids.each do |id|
            inverse_mapping.database_model.create!(salesforce_id: id)
          end
        end

        it "returns true" do
          expect(association).to_be :synced_for?, salesforce_instance
        end
      end
    end

    describe "#build" do
      let(:database_record) { CustomObject.new }
      let(:salesforce_record) { mapping.salesforce_record_type.find(object_salesforce_id).record }
      let(:associated) { association.build(database_record, salesforce_record) }

      it "builds a number of associated records from the data in Salesforce" do
        detail_salesforce_ids.each do |id|
          record = associated.detect { |a| a.salesforce_id == id }

          expect(record).to_not_be_nil
          expect(record.custom_object).to_equal database_record
        end
      end

      describe "when the association is non-building" do
        let(:association) { Restforce::DB::Associations::HasMany.new(:details, through: "CustomObject__c", build: false) }

        it "proceeds without constructing any records" do
          expect(associated).to_be :empty?
        end
      end

      describe "when no salesforce record is found for the association" do
        let(:detail_salesforce_ids) { nil }

        it "proceeds without constructing any records" do
          detail_salesforce_ids
          expect(associated).to_be :empty?
        end
      end

      describe "when the associated records have alrady been persisted" do
        let(:details) { detail_salesforce_ids.map { |id| Detail.create!(salesforce_id: id) } }

        before { details }

        it "constructs the association from the existing records" do
          expect(associated).to_be :empty?
          expect(database_record.details).to_match_array details
        end
      end

      describe "when the associated records have been cached" do
        let(:details) { detail_salesforce_ids.map { |id| Detail.new(salesforce_id: id) } }
        let(:cache) { Restforce::DB::AssociationCache.new }
        let(:associated) { association.build(database_record, salesforce_record, cache) }

        before do
          details.each do |detail|
            cache << detail
          end
        end

        it "uses the cached records" do
          expect(associated).to_be :empty?
          expect(database_record.details).to_match_array details
        end
      end
    end
  end
end
