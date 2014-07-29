require 'pathname'
require 'yaml'

require 'bundler'

Bundler.require(:default)

require_relative 'convergence/archive'
require_relative 'convergence/calculator'
require_relative 'convergence/export_analyzer'
require_relative 'convergence/runner'

module Merit
  module Convergence
    # Public: Given a producer and point, returns the sortable cost of the
    # producer in that point based on whatever demand is assigned to it.
    #
    # This is used to re-sort producers after each "unit" of load is assigned in
    # the Convergence::Calculator, and to assign load fairly to foreign
    # countries which use step-functions in the ExportAnalyzer.
    #
    # Returns a numeric.
    def self.producer_cost(producer, point)
      strategy = producer.cost_strategy

      if strategy.respond_to?(:cost_at_load)
        strategy.cost_at_load(producer.load_curve.get(point))
      else
        strategy.sortable_cost(point)
      end
    end

    # Public: Given a producer, returns the amount of load which can be assigned
    # to it at a given cost before it becomes uncompetitive.
    #
    # Returns a numeric.
    def self.competitive_load(producer, point, limiting_cost)
      strategy = producer.cost_strategy
      max_load = producer.max_load_at(point)

      if strategy.respond_to?(:cost_at_load)
        # We could do this with a formula rather than incrementing the capacity
        # and testing the price, but this way ensures that using non-linear
        # cost functions will still work.
        step = producer.output_capacity_per_unit

        (0..max_load).step(step).each do |capacity|
          if strategy.cost_at_load(capacity + step) > limiting_cost
            return capacity
          end
        end

        # Cost is greater than the highest cost of the producer.
        max_load
      else
        strategy.sortable_cost(point) > limiting_cost ? 0.0 : max_load
      end
    end
  end # Convergence
end # Merit
