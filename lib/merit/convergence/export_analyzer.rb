module Merit
  module Convergence
    # Given a *calculated* Merit::Order, determines when the country will export
    # energy to another, and how much will be exported.
    class ExportAnalyzer
      # Public: Creates a new ExportAnalyzer.
      #
      # local    - The calculated merit order belonging to the country which
      #            will be exporting.
      # abroad   - The calculated merit order belonging to the country which
      #            will be importing.
      # capacity - The capacity of the interconnect. This may be a constant
      #            number or a curve if the capacity varies over time.
      #
      # Returns an ExportAnalyzer.
      def initialize(local, abroad, capacity)
        @local  = local
        @abroad = abroad

        unless capacity.is_a?(Merit::Curve)
          capacity = Merit::Curve.new([capacity] * Merit::POINTS)
        end

        @capacity = capacity
      end

      # Public: Runs the analyzer, and returns a load curve specifying the load
      # assigned to the interconnect in each hour of the year.
      #
      # Returns a Merit::Curve.
      def load_curve
        curve = Curve.new([], Merit::POINTS)

        Merit::POINTS.times do |point|
          if cheaper_locally?(point)
            curve.set(point, [
              available_capacity(point),
              foreign_demand(point),
              @capacity.get(point)
            ].min)
          else
            curve.set(point, 0.0)
          end
        end

        curve
      end

      #######
      private
      #######

      # Internal: Determines if the county will export to the other country in
      # the given point. This is the case when energy is cheaper here than it is
      # there.
      #
      # Returns true or false.
      def cheaper_locally?(point)
        @local.price_at(point) < @abroad.price_at(point)
      end

      # Internal: Returns how much capacity is available to be exported in a
      # given point.
      #
      # Returns a Numeric.
      def available_capacity(point)
        local_producers(point, @abroad.price_curve.get(point))
          .reduce(0.0) do |sum, prod|
            sum + (prod.max_load_at(point) - prod.load_curve.get(point))
          end
      end

      # Internal: Returns all producers which are less expensive than the
      # foreign country, and have spare capacity.
      #
      # Returns an array of producers.
      def local_producers(point, price)
        @local.participants.dispatchables.select do |producer|
          (producer.cost_strategy.sortable_cost(point) < price) &&
            (producer.max_load_at(point) > producer.load_curve.get(point))
        end
      end

      # Internal: Determines how much energy the foreign country will want based
      # on how much of its energy is more expensive than local supply.
      #
      # Returns a numeric.
      def foreign_demand(point)
        foreign_producers(point, @local.price_curve.get(point))
          .reduce(0.0) do |sum, prod|
            sum + prod.load_curve.get(point)
          end
      end

      # Internal: Returns all producers in the foreign country which are more
      # expensive than the local country, and have a non-zero load.
      #
      # Returns an array of producers.
      def foreign_producers(point, price)
        @abroad.participants.dispatchables.select do |producer|
          # if point.zero?
            # p [producer, producer.cost_strategy.sortable_cost(point), price]
          # end
          (producer.cost_strategy.sortable_cost(point) > price) &&
            producer.load_curve.get(point) > 0
        end
      end
    end # ExportAnalyzer
  end # Convergence
end # Merit
