require_relative "../../../../test_helper"

describe Restforce::DB::Associations::BelongsTo do

  configure!
  mappings!

  let(:association) { Restforce::DB::Associations::BelongsTo.new(:user, through: "Friend__c") }

  it "sets the lookup field" do
    expect(association.lookup).to_equal "Friend__c"
  end

  describe "#fields" do

    it "returns the configured lookups for the association" do
      expect(association.fields).to_equal [association.lookup]
    end
  end

  describe "with an inverse mapping", :vcr do
    let(:inverse_mapping) do
      Restforce::DB::Mapping.new(User, "Contact").tap do |map|
        map.fields = { email: "Email" }
        map.associations << Restforce::DB::Associations::HasOne.new(
          :custom_object,
          through: "Friend__c",
        )
      end
    end
    let(:user_salesforce_id) do
      Salesforce.create!(
        inverse_mapping.salesforce_model,
        "Email" => "somebody@example.com",
        "LastName" => "Somebody",
      )
    end
    let(:object_salesforce_id) do
      Salesforce.create!(mapping.salesforce_model, "Friend__c" => user_salesforce_id)
    end

    before do
      Restforce::DB::Registry << mapping
      Restforce::DB::Registry << inverse_mapping
      mapping.associations << association
    end

    describe "#lookups" do
      let(:user) { inverse_mapping.database_model.create!(salesforce_id: user_salesforce_id) }
      let(:object) { mapping.database_model.create!(salesforce_id: object_salesforce_id, user: user) }

      it "returns a hash of the associated records' lookup IDs" do
        expect(association.lookups(object)).to_equal("Friend__c" => user_salesforce_id)
      end

      describe "when there is currently no associated record" do
        let(:object_salesforce_id) { Salesforce.create!(mapping.salesforce_model) }
        let(:object) { mapping.database_model.create!(salesforce_id: object_salesforce_id) }

        it "returns no value in the hash" do
          expect(association.lookups(object)).to_be :empty?
        end

        describe "and the underlying association is one-to-many" do
          let(:association) { Restforce::DB::Associations::BelongsTo.new(:admirers, through: "Friend__c") }
          let(:inverse_mapping) do
            Restforce::DB::Mapping.new(User, "Contact").tap do |map|
              map.fields = { email: "Email" }
              map.associations << Restforce::DB::Associations::HasOne.new(
                :favorite,
                through: "Friend__c",
              )
            end
          end

          it "still returns no value in the hash" do
            expect(association.lookups(object)).to_be :empty?
          end
        end
      end
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
          inverse_mapping.database_model.create!(salesforce_id: user_salesforce_id)
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

      it "returns an associated record, populated with the Salesforce attributes" do
        record = associated.first

        expect(record.custom_object).to_equal database_record
        expect(record.email).to_equal "somebody@example.com"
        expect(record.salesforce_id).to_equal user_salesforce_id
      end

      describe "when the association is non-building" do
        let(:association) { Restforce::DB::Associations::BelongsTo.new(:user, through: "Friend__c", build: false) }

        it "proceeds without constructing any records" do
          expect(associated).to_be :empty?
        end
      end

      describe "when no salesforce record is found for the association" do
        let(:user_salesforce_id) { nil }

        it "proceeds without constructing any records" do
          expect(associated).to_be :empty?
        end
      end

      describe "with an unrelated association mapping" do
        let(:extraneous_mapping) { Restforce::DB::Mapping.new(User, "Account") }

        before do
          Restforce::DB::Registry << extraneous_mapping
        end

        it "proceeds without raising an error" do
          expect(associated).to_not_be :empty?
        end
      end

      describe "when the associated record has already been persisted" do
        let(:user) { User.create!(salesforce_id: user_salesforce_id) }

        before { user }

        it "assigns the existing record" do
          expect(associated).to_be :empty?
          expect(database_record.user).to_equal user
        end
      end

      describe "when the associated record has been cached" do
        let(:user) { User.new(salesforce_id: user_salesforce_id) }
        let(:cache) { Restforce::DB::AssociationCache.new }
        let(:associated) { association.build(database_record, salesforce_record, cache) }

        before { cache << user }

        it "uses the cached record" do
          expect(associated).to_be :empty?
          expect(database_record.user).to_equal user
        end
      end
    end
  end

end
