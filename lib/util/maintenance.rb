module Cisqua
  class Maintenance
    def remove_invalid_batch_datas
      bds = BatchData.latest(20)
      invalids = bds.select do |bd|
        bd.updates.nil? &&
          bd.success_fids.empty? &&
          bd.replacement_fids.empty? &&
          bd.duplicate_fids.empty? &&
          bd.unknowns.empty?
      end
      invalids.each { |bd| remove_batch_data(bd) }
    end

    def remove_batch_data(bd)
      redis = Registry.instance.redis

      redis.zrem('bd:timestamps', bd.id)
      redis.del(bd.make_key_for_instance)
    end

    def refetch_anime_info(aid)
      proxy_client = Registry.instance.proxy_client
      response = proxy_client.anime(aid)
      Anime.from_api_response(response[:anime], id: aid).save
    end
  end
end
