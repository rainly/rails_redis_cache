require 'active_support'
require 'base64'
require 'redis'
require 'time'

module ActiveSupport
  module Cache
    class RailsRedisCache < Store
      
      TIME_PREF = "rails_redis_cache_time"
      VALUE_PREF = "rails_redis_cache_value"
      
      attr_reader :redis
      
      def initialize(options={})
        super()
        @redis = Redis.connect(options)
      end
      
      # ============================= basic store impl ==============================
      
      def read_entry(key, options)
        raw_value = @redis.get "#{VALUE_PREF}_#{key}"
        return nil unless raw_value
        
        time = Time.parse @redis.get("#{TIME_PREF}_#{key}")
        puts "#{raw_value} #{raw_value.class}"
        ActiveSupport::Cache::Entry.create Marshal.load(Base64.decode64(raw_value)), time
      end

      def write_entry(key, entry, options)
        @redis.mset "#{VALUE_PREF}_#{key}", Base64.encode64(Marshal.dump(entry.value.to_s)), "#{TIME_PREF}_#{key}", Time.now
        return unless expiry = options[:expires_in]
        @redis.expire "#{VALUE_PREF}_#{key}", expiry
        @redis.expire "#{TIME_PREF}_#{key}", expiry
      end

      def delete_entry(key, options)
        @redis.del "#{VALUE_PREF}_#{key}", "#{TIME_PREF}_#{key}"
      end
      
      # ============================= optional store impl ==============================
      
      def delete_matched(matcher, options = nil)
        @redis.keys("#{VALUE_PREF}_*").map{|key| key[(VALUE_PREF.size + 1)..-1] }.grep(matcher).each do |key| 
          delete_entry(key, options)
        end.size
      end

      def increment(name, amount = 1, options = nil)
        write(name, amount + read(name, options).to_i, options)
      end

      def decrement(name, amount = 1, options = nil)
        write(name, -1 * amount + read(name, options).to_i, options)
      end

      def cleanup(options = nil)
        p value_keys = @redis.keys("#{VALUE_PREF}_*")
        p time_keys = @redis.keys("#{TIME_PREF}_*")
        @redis.del *(value_keys + time_keys)
      end

      def clear(options = nil)
        cleanup(options)
      end
      
    end
  end 
end