require 'violet_archives'
require 'violet_archives/input/jargon_parser'

module VioletArchivesHelper
  def create_dota_service(base_url, **service_urls)
    urls = VioletArchives::DotaServiceUrls.new(base_url, **service_urls)
    VioletArchives::DotaService.new(urls)
  end

  def create_dota_dataset(dota_service)
    VioletArchives::DotaData.new(nil, dota_service)
  end

  def create_jargon_parser(hero_abbrevs, item_abbrevs)
    VioletArchives::JargonParser.with_defaults(hero_abbrevs: hero_abbrevs,
                                               item_abbrevs: item_abbrevs)
  end
end
