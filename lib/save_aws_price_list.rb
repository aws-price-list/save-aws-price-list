require 'mongo'
require 'json'


class SaveAWSPriceList

  def initialize(db_url)
    @client = Mongo::Client.new(db_url)
  end

  def save(offer_index_filename)
    offer_index_json = JSON.parse(File.read(offer_index_filename))

    offerCode = offer_index_json["offerCode"]
    version = offer_index_json["version"]
    skus = offer_index_json["products"]
    save_skus(skus, offerCode, version)

    terms = offer_index_json["terms"]
    save_terms(terms, offerCode, version)
    save_offer_term_codes_by_sku(terms, offerCode, version)
  end

  def save_offer_term_codes_by_sku(terms, offer_code, version)
    offer_term_codes_by_sku = []
    terms.each_key do |term|
      terms[term].each_key do |sku|
        offer_term_codes_by_sku << terms[term][sku]
      end
    end

    offer_term_codes_by_sku.each do |oti|
      otc_data = oti.values.first
      sku = otc_data["sku"]
      otc = otc_data["offerTermCode"]

      offer_term_code_doc = {
          "_id" => "#{version}:#{offer_code}:#{sku}:#{otc}",
          "version" => version,
          "offerCode" => offer_code,
          "sku" => sku,
          "offerTermCode" => otc,
          "effectiveDate" => otc_data["effectiveDate"]
      }

      save_rate_codes(otc_data["priceDimensions"], offer_code, sku, otc, version)

      @client[:offer_term_codes_by_sku].insert_one(offer_term_code_doc)
    end
  end

  def save_rate_codes(price_dimensions, offer_code, sku, otc, version)
    price_dimensions.each_key do |rate_code|
      rate_code_doc = {
          "_id" => "#{version}:#{offer_code}:#{rate_code}",
          "offerCode" => offer_code,
          "version" => version,
          "sku" => sku,
          "offerTermCode" => otc
      }
      rate_code_doc.merge!(price_dimensions[rate_code])
      @client[:rate_codes].insert_one(rate_code_doc)
    end
  end

  def save_terms(terms, offerCode, version)
    terms.each_key do |term|
      term_doc = {
          "_id" => "#{version}:#{offerCode}:#{term}",
          "offerCode" => offerCode,
          "version" => version,
          "term": term
      }
      @client[:terms].insert_one(term_doc)
    end
  end

  def save_skus(skus, offerCode, version)
    skus.each_key do |sku|
      sku_doc = {
          "_id": "#{version}:#{sku}",
          "offerCode" => offerCode,
          "version" => version,
          "sku" => sku,
          "productFamily" => skus[sku]["productFamily"],
          "attributes" => skus[sku]["attributes"]
      }
      @client[:skus].insert_one(sku_doc)
    end
  end

end