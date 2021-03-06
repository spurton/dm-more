module DataMapper
  module Adapters
    class DataObjectsAdapter < AbstractAdapter

      def aggregate(query)
        with_connection do |connection|
          statement, bind_values = select_statement(query)
          command                = connection.create_command(statement)
          command.set_types(query.fields.map { |p| p.primitive })

          begin
            reader = command.execute_reader(*bind_values)

            model   = query.model
            results = []

            while(reader.next!)
              row = query.fields.zip(reader.values).map do |field,value|
                if field.respond_to?(:operator)
                  send(field.operator, field.target, value)
                else
                  field.typecast(value)
                end
              end

              results << (query.fields.size > 1 ? row : row[0])
            end

            results
          ensure
            reader.close if reader
          end
        end


      end



      private

      def count(property, value)
        value.to_i
      end

      def min(property, value)
        property.typecast(value)
      end

      def max(property, value)
        property.typecast(value)
      end

      def avg(property, value)
        property.type == Integer ? value.to_f : property.typecast(value)
      end

      def sum(property, value)
        property.typecast(value)
      end

      module SQL
        private
        def included(host)
          host.class_eval do
            alias original_property_to_column_name property_to_column_name
          end
        end

        def property_to_column_name(property, qualify)
          case property
            when Query::Operator
              aggregate_field_statement(property.operator, property.target, qualify)
            when Property, Query::Path
              original_property_to_column_name(property, qualify)
            else
              raise ArgumentError, "+property+ must be a DataMapper::Query::Operator, a DataMapper::Property or a Query::Path, but was a #{property.class} (#{property.inspect})"
          end
        end

        def aggregate_field_statement(aggregate_function, property, qualify)
          column_name = if aggregate_function == :count && property == :all
            '*'
          else
            property_to_column_name(property, qualify)
          end

          function_name = case aggregate_function
            when :count then 'COUNT'
            when :min   then 'MIN'
            when :max   then 'MAX'
            when :avg   then 'AVG'
            when :sum   then 'SUM'
            else raise "Invalid aggregate function: #{aggregate_function.inspect}"
          end

          "#{function_name}(#{column_name})"
        end
      end # module SQL

      include SQL
    end # class DataObjectsAdapter
  end # module Adapters
end # module DataMapper
