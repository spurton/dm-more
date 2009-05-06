# -*- coding: utf-8 -*-

module DataMapper
  module Validate
    module Fixtures
      class Reservation
        #
        # Behaviors
        #

        include ::DataMapper::Resource

        #
        # Attributes
        #

        attr_accessor :person_name_confirmation, :seats_confirmation

        #
        # Properties
        #

        property :id,              Serial
        property :person_name,     String,  :auto_validation => false
        property :number_of_seats, Integer, :auto_validation => false

        #
        # Validations
        #

        validates_is_confirmed :person_name,     :allow_nil => false
        validates_is_confirmed :number_of_seats, :confirm => :seats_confirmation, :message => Proc.new { |model, property|
          "%s requires confirmation for %s" % [model.class.name.split("::").last, property.name]
        }
      end # Reservation
    end # Fixtures
  end # Validate
end # DataMapper
