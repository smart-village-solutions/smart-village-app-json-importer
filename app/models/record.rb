# frozen_string_literal: true

class Record < ApplicationRecord
  attr_accessor :source_url, :feed

  audited only: :updated_at

  def initialize(source_url: nil, feed: nil)
    @source_url = source_url
    @feed = feed
    super
  end

  def load_json_data
    result = ApiRequestService.new(source_url).get_request(false)

    return unless result.code == "200"
    return unless result.body.present?

    self.xml_data = result.body
  end

  def convert_to_json(hash_data)
    hash_data.to_json
  end

  def convert_json_to_hash
    news_data = []
    raw_json_data = JSON.parse(xml_data)
    raw_json_data.each do |json_item|
      news_data << parse_single_news_from_json(json_item)
    end

    self.json_data = { news: news_data }
  end

  private

    # json_item =
    #   {
    #   "image"=> [
    #     {
    #       source_url: "https://www.eisenhuettenstadt.de/media/custom/2852_2678_1_m.PNG?1591882344"
    #     }
    #   ],
    #   "title" => "Startschuss für das 7. Eisenhüttenstädter »Ferien-Diplom«",
    #   "content"=> "Eisenhüttenstadt. Nach einem ungewöhnlichen Schulhalbjahr können sich Eisenhüttenstädter Kinder im Alter von 8 bis 12 Jahren nun wieder auf etwas Normalität und Ablenkung freuen: ... Mehr",
    #   "date"=> "2020-11-06 00:00:00",
    #   "url"=>"https://www.eisenhuettenstadt.de/Stadt-Verwaltung/Aktuelles/Pressemitteilungen"
    #   }
    #
    def parse_single_news_from_json(json_item)
      {
        external_id: load_from_feed_definition(:external_id, json_item),
        author: load_from_feed_definition(:author, json_item),
        full_version: false,
        news_type: feed[:import][:news_type],
        publication_date: load_from_feed_definition(:date, json_item),
        published_at: load_from_feed_definition(:date, json_item),
        source_url: {
          url: load_from_feed_definition(:url, json_item),
          description: "source url of original article"
        },
        contentBlocks: [
          {
            title: load_from_feed_definition(:title, json_item),
            intro: load_from_feed_definition(:intro, json_item),
            body: load_from_feed_definition(:body, json_item),
            media_contents: media_contents(json_item)
          }
        ]
      }
    end

    def load_from_feed_definition(json_key, json_item)
      defined_json_key = feed[:import].dig(*json_key)
      return "" if defined_json_key.blank?

      json_item.dig(defined_json_key)
    end

    def media_contents(json_item)
      return [] if feed[:import][:images].blank?
      return [] if feed[:import][:images] == false
      return [] if feed[:import][:images][:image_tag].blank?

      media = []
      json_item.fetch(feed[:import][:images][:image_tag], []).each do |image_item|
        image_data = {
          content_type: "image",
          copyright: load_from_feed_definition([:images, :copyright], image_item),
          caption_text: load_from_feed_definition([:images, :caption_text], image_item),
          width: load_from_feed_definition([:images, :width], image_item).to_i,
          height: load_from_feed_definition([:images, :height], image_item).to_i,
          source_url: {
            url: load_from_feed_definition([:images, :source_url], image_item)
          }
        }
        media << image_data
      end

      media.compact.flatten
    end
end

# == Schema Information
#
# Table name: records
#
#  id          :bigint           not null, primary key
#  external_id :string
#  json_data   :jsonb
#  xml_data    :text
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
