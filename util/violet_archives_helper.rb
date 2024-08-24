require 'violet_archives'

module VioletArchivesHelper
  def create_dota_service(base_url, **service_urls)
    urls = VioletArchives::DotaServiceUrls.new(base_url, **service_urls)
    VioletArchives::DotaService.new(urls)
  end

  def create_dota_dataset(dota_service)
    VioletArchives::DotaData.new(nil, dota_service)
  end
end
