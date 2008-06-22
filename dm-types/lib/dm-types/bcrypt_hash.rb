
require 'bcrypt'

module DataMapper
  module Types
    class BCryptHash < DataMapper::Type
      primitive String
      size 60
      scale BCrypt::Engine::DEFAULT_COST

      def self.load(value, property)
        if value.nil?
          nil
        elsif value.is_a?(String)
          BCrypt::Password.new(value)
        else
          raise ArgumentError.new("+value+ must be nil or a String")
        end
      end

      def self.dump(value, property)
        if value.nil?
          nil
        elsif value.is_a?(String)
          BCrypt::Password.create(value, :cost => scale)
        else
          raise ArgumentError.new("+value+ must be nil or a String")
        end
      end
    end # class Yaml
  end # module Types
end # module DataMapper
