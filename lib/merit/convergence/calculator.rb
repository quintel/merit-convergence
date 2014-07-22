module Merit
  module Convergence
    # A custom merit order calculator which assigns load to cost-function
    # producers in "steps", so that load is preferentially assigned to
    # competitive interconnects.
    class Calculator < Merit::Calculator
      #######
      private
      #######

      # Internal: For a given +point+ in time, calculates the load which should
      # be handled by transient energy producers, and assigns the calculated
      # values to the producer's load curve.
      #
      # This is the "jumping off point" for calculating the merit order, and
      # note that the method is called once per Merit::POINT. Since Calculator
      # computes a value for every point (default 8,760 of them) even tiny
      # changes can have large effects on the time taken to run the calculation.
      # Therefore, always benchmark / profile your changes!
      #
      # order     - The Merit::Order being calculated.
      # point     - The point in time, as an integer. Should be a value between
      #             zero and Merit::POINTS - 1.
      # producers - An object supplying the always_on and transient producers.
      #
      # Returns nothing.
      def compute_point(order, point, producers)
        # Optimisation: This is order-dependent; it requires that always-on
        # producers are before the transient producers, otherwise "remaining"
        # load will not be correct.
        #
        # Since this method is called a lot, being able to handle always-on and
        # transient producers in separate loops allows us to skip calling
        # #always_on? in every iteration. This accounts for a 20% reduction in
        # the calculation runtime.

        if (remaining = demand(order, point)) < 0
          raise SubZeroDemand.new(point, remaining)
        end

        producers.always_on(point).each do |producer|
          remaining -= producer.max_load_at(point)
        end

        # Ignore the possibility for a Resortable to be delivered as the third
        # method argument. We're going to resort the transients anyway.
        transients = order.participants.transients(point)
          .sort_by { |transient| pcost(transient, point) }

        while producer = transients.shift do
          max_load = producer.max_load_at(point)

          # Optimisation: Load points default to zero, skipping to the next
          # iteration is faster then running the comparison / load_curve#set.
          next if max_load.zero?

          current   = producer.load_curve.get(point)
          headroom  = max_load - current
          chunk     = producer.output_capacity_per_unit
          remaining = 0 if remaining < 1e-10

          next if headroom.zero?

          if headroom <= remaining && headroom < chunk
            # Strangely the producer has less than one unit of capacity left. We
            # assign it to the maximum load.
            add_load(producer, point, headroom)
            remaining -= headroom
          elsif remaining > chunk
            # Assign load equal to the size of one plant.
            add_load(producer, point, chunk)
            remaining -= chunk

            # Add the plant back to the collection. Determining the index of the
            # first producer which is more expensive -- and inserting before
            # that producer -- is 2x faster than resorting the list entirely.
            insert_at = transients.index do |other|
              pcost(other, point) >= pcost(producer, point)
            end

            transients.insert(insert_at || transients.length, producer)
          elsif remaining > 0
            # There is less total load remaining to be assigned than the
            # capacity of a new plant.
            add_load(producer, point, remaining)

            # Cost-function producers with at least one unit of capacity
            # available will be the price-setting producer.
            if producer.cost_strategy.price_setting?(point)
              assign_price_setting(order, producer, point)
              break
            end

            # The next producer will be price-setting.
            remaining = 0
          else
            assign_price_setting(order, producer, point)

            # Optimisation: If all of the demand has been accounted for, there
            # is no need to waste time with further iterations and expensive
            # calls to Producer#max_load_at.
            break
          end
        end
      end

      def pcost(producer, point)
        strategy = producer.cost_strategy

        if strategy.respond_to?(:cost_at_load)
          strategy.cost_at_load(producer.load_curve.get(point))
        else
          strategy.sortable_cost(point)
        end
      end

      def add_load(producer, point, value)
        producer.load_curve.set(point, producer.load_curve.get(point) + value)
      end
    end # Calculator
  end # Convergence
end # Merit
