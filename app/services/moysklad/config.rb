# frozen_string_literal: true

module Moysklad
  # Configuration for Moysklad API client
  class Config
    BASE_URL = 'https://api.moysklad.ru/api/remap/1.2'

    attr_accessor :username, :password, :base_url, :default_store_meta, :default_org_meta, :default_agent_meta

    def initialize
      @username = ENV.fetch('MOYSKLAD_USER', nil)
      @password = ENV.fetch('MOYSKLAD_PASS', nil)
      @base_url = BASE_URL
      @default_store_meta = build_default_store_meta
      @default_org_meta = build_default_org_meta
      @default_agent_meta = build_default_agent_meta
    end

    private

    def build_default_store_meta
      {
        'href' => 'https://api.moysklad.ru/api/remap/1.2/entity/store/d2a971ca-9164-11f0-0a80-19cb0021b994',
        'metadataHref' => 'https://api.moysklad.ru/api/remap/1.2/entity/store/metadata',
        'type' => 'store',
        'mediaType' => 'application/json',
        'uuidHref' => 'https://online.moysklad.ru/app/#warehouse/edit?id=d2a971ca-9164-11f0-0a80-19cb0021b994'
      }.freeze
    end

    def build_default_org_meta
      {
        'href' => 'https://api.moysklad.ru/api/remap/1.2/entity/organization/2743fc18-7dfd-11ee-0a80-0e2a00051e04',
        'metadataHref' => 'https://api.moysklad.ru/api/remap/1.2/entity/organization/metadata',
        'type' => 'organization',
        'mediaType' => 'application/json',
        'uuidHref' => 'https://online.moysklad.ru/app/#mycompany/edit?id=2743fc18-7dfd-11ee-0a80-0e2a00051e04'
      }.freeze
    end

    def build_default_agent_meta
      {
        'href' => 'https://api.moysklad.ru/api/remap/1.2/entity/counterparty/e407a3f8-a50e-11f0-0a80-0e580038a1ba',
        'metadataHref' => 'https://api.moysklad.ru/api/remap/1.2/entity/counterparty/metadata',
        'type' => 'counterparty',
        'mediaType' => 'application/json',
        'uuidHref' => 'https://online.moysklad.ru/app/#company/edit?id=e407a3f8-a50e-11f0-0a80-0e580038a1ba'
      }.freeze
    end
  end
end
