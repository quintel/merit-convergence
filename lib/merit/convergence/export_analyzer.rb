module Merit
  module Convergence
    # Given a *calculated* Merit::Order, determines when the country will export
    # energy to another, and how much will be exported.
    class ExportAnalyzer
      # Public: Creates a new ExportAnalyzer.
      #
      # order       - The calculated merit order belonging to the country which
      #               will be exporting.
      # capacity    - The available interconnect capacity. This can be a number
      #               specifying the capacity in each hour, or a Curve if the
      #               capacity varies by hour.
      # other_price - The price curve of the country which will be importing.
      #
      # Returns an ExportAnalyzer.
      def initialize(order, capacity, other_price)
        @order       = order
        @other_price = other_price

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
            available = available_capacity(point)

            if available > @capacity.get(point)
              curve.set(point, @capacity.get(point))
            else
              curve.set(point, available)
            end
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
        @order.price_at(point) < @other_price.get(point)
      end

      # Internal: Returns how much capacity is available to be exported in a
      # given point.
      #
      # Returns a Numeric.
      def available_capacity(point)
        producers_for(point, @other_price.get(point)).reduce(0.0) do |sum, prod|
          sum + (prod.max_load_at(point) - prod.load_curve.get(point))
        end
      end

      # Internal: Returns all producers which are less expensive than the
      # foreign country, and have spare capacity. Sorted by their marginal cost.
      #
      # Returns an array of producers.
      def producers_for(point, price)
        @order.participants.dispatchables.select do |producer|
          (producer.cost_strategy.sortable_cost(point) < price) &&
            (producer.max_load_at(point) > producer.load_curve.get(point))
        end
      end
    end # ExportAnalyzer
  end # Convergence
end # Merit
