module Merit
  module Convergence
    # The most generic class name ever?
    class Runner
      attr_reader :first_order, :second_order, :other_orders

      # Creates a Runner. Provide this with a Convergence::Archive with data for
      # for the main country being calculated.
      def initialize(local)
        @local = local

        @interconnects = {}
        @fixed_export  = {}

        @first_order   = nil
        @second_order  = nil
        @other_orders  = {}
      end

      # Public: Returns a Curve combining import/export to another +region+.
      # Positive numbers indicate export to the region (this is additional load
      # in the local country) and negatives show the amount of import.
      #
      # Returns a Curve.
      def interconnect_flow(region)
        exporter = @second_order.participants[:"export_to_#{ region }"]
        importer = @second_order.participants[:"import_from_#{ region }"]

        data = Merit::POINTS.times.map do |point|
          if (amount = importer.load_curve.get(point)) > 0
            -amount
          elsif (amount = exporter.load_curve.get(point)) > 0
            amount
          else
            0.0
          end
        end

        Curve.new(data)
      end

      # Public: Add a two-way interconnect between the local country, and
      # another. The merit order will be calculated twice; once without
      # accounting for export to the other country, and again including said
      # export.
      #
      # other    - A Convergence::Archive containing data for the other country.
      # capacity - The capacity of the interconnect.
      #
      # Returns nothing.
      def add_interconnect(other, capacity)
        if @interconnects.any?
          fail 'You can currently only add one interconnect!'
        end

        @interconnects[other.area] = { archive: other, capacity: capacity }
      end

      # Public: Adds a fixed amount of export to another country, where the
      # amount exported is defined in a load curve.
      #
      # This allows you to add export to another country which has been
      # pre-calculated outside of the Merit Order workflow.
      #
      # region_code - A two-letter code identifying the region which we are
      #               exporting to (e.g. :be, :no, etc).
      # load_curve  - A curve specifying how much electricity is exported in
      #               each hour.
      #
      # For example:
      #
      #   runner = Runner.new(nl_data)
      #   runner.add_export(:be, LoadCurve.new([1, 2, 3, ...]))
      #
      # Returns nothing.
      def add_export(region_code, load_curve)
        @fixed_export[region_code.to_sym] = load_curve
      end

      # Public: Runs the two-step merit order Convergence analysis.
      #
      # Returns the calculated Merit Order.
      def run
        return @second_order if @second_order

        calculate_other_orders!
        first_run!
        analyze_exports!
        second_run!
      end

      # Public: Creates a (calculated) Merit order for the main country, without
      # ANY interconnects.
      #
      # Returns a Merit Order.
      def standalone
        @local.merit_order.calculate(Merit::Convergence::Calculator.new)
      end

      #######
      private
      #######

      def calculate_other_orders!
        @interconnects.each do |region_code, data|
          @other_orders[region_code] = data[:archive].merit_order
            .calculate(Merit::Convergence::Calculator.new)
        end
      end

      # Internal: Performs the first run of the local merit order. Does not
      # include export from interconnects.
      def first_run!
        @first_order = @local.merit_order

        add_import_producers(@first_order)
        add_export_users(@first_order)

        @first_order.calculate(Merit::Convergence::Calculator.new)
      end

      # Internal: After doing the first merit order run, analyze when it is cost
      # effective for foreign regions to import energy from the local one.
      def analyze_exports!
        @interconnects.each do |region_code, data|
          analysis = Merit::Convergence::ExportAnalyzer.new(
            @first_order, @other_orders[region_code], data[:capacity])

          add_export(region_code, analysis.load_curve)
        end
      end

      # Internal: Now that we've analyzed the export loads, calculate the local
      # country again accounting for those loads.
      def second_run!
        @second_order = @local.merit_order

        add_import_producers(@second_order)
        add_export_users(@second_order)

        @second_order.calculate(Merit::Convergence::Calculator.new)
      end

      # Internal: Given a Merit Order for the local country, adds a
      # SupplyInterconnect for each connection to a foreign country.
      def add_import_producers(order)
        @interconnects.each do |region_code, data|
          order.add(Merit::SupplyInterconnect.new(
            key: :"import_from_#{ region_code }",
            cost_curve: @other_orders[region_code].price_curve,
            output_capacity_per_unit: data[:capacity]
          ))
        end
      end

      # Internal: Given a Merit Order for the local country, adds a User which
      # represents the electricity which will be exported to each foreign
      # country.
      def add_export_users(order)
        @fixed_export.each do |region_code, load_curve|
          order.add(Merit::User.create(
            key: :"export_to_#{ region_code }",
            load_curve: load_curve
          ))
        end
      end
    end # Runner
  end # Convergence
end # Merit
