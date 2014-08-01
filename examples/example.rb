require_relative '../lib/merit/convergence'

# The merit-convergence directory.
CONVERGENCE_DIR = Pathname.new(__FILE__).join('../..').expand_path

# Path to the directory containing data exported from ETEngine.
DATA_DIR = CONVERGENCE_DIR.join('data')

# Path to the ETSource datasets/ directory. The default value assumes that
# ETSource and Merit::Convergence have a common parent directory.
#
#   └ Projects/
#     ├ etsource/
#     │ ├ datasets/
#     │ └ ...
#     └ merit-convergence/
#       ├ data/
#       ├ examples/
#       └ ...
#
DATASETS_DIR = CONVERGENCE_DIR.join('../etsource/datasets')

DE_ARCHIVE = Merit::Convergence::Archive.new(
  DATA_DIR.join('de'),                   # Path to the DE data.
  DATASETS_DIR.join('de/load_profiles')  # Path to the DE load profiles.
)

NL_ARCHIVE = Merit::Convergence::Archive.new(
  DATA_DIR.join('nl'),                   # Path to the NL data.
  DATASETS_DIR.join('nl/load_profiles')  # Path to the NL load profiles.
)

# Always use the Convergence calculator in this script. Do not forget this in
# other scripts!
Merit::Order.calculator = Merit::Convergence::Calculator.new

# ------------------------------------------------------------------------------

# Germany
# -------
#
# Calculate a Merit Order for Germany so that we can use it's price curve to
# determine when import and export will occur. Price data is already available
# in the data directory (prices.csv), but we recalculate it anyway in case we
# have newer load profiles than ETEngine.

de_order = DE_ARCHIVE.merit_order.calculate

# ------------------------------------------------------------------------------

# Netherlands, First Run
# ----------------------
#
# Calculate load data for the Netherlands, importing from Germany whenever
# energy is cheaper there. This does not yet include export to Germany, since
# that will depend on the NL pricing.

nl_order = NL_ARCHIVE.merit_order

# Add a Supply Interconnect to import from Germany:
nl_order.add(Merit::SupplyInterconnect.new(
  key: :import_from_de,

  # The price of the German merit order will determine the price of the
  # interconnect.
  cost_curve: de_order.price_curve,

  # The maximum capacity of the interconnect.
  output_capacity_per_unit: 2449.0
))

nl_order.calculate

# ------------------------------------------------------------------------------

# Export Analysis
# ---------------
#
# Now we need to determine when Germany is more expensive than the Netherlands
# and, in such cases, how much electricity we will export.
#
# This point-by-point load is available by calling "analysis.load_curve".

analysis = Merit::Convergence::ExportAnalyzer.new(
  nl_order,  # The local country.
  de_order,  # The other country.
  2449.0     # The interconnect capacity.
)

# ------------------------------------------------------------------------------

# Netherlands, Second Run
# -----------------------
#
# Calculate the Netherlands again, this time including export to Germany.

# export_curve = Merit::Curve.new(de_order.price_curve.to_a)
export_user = Merit::User.create(key: :export_to_de, load_curve: analysis.load_curve)

nl_again = NL_ARCHIVE.merit_order

# Again we add import from Germany:
nl_again.add(Merit::SupplyInterconnect.new(
  key: :import_from_de,
  cost_curve: de_order.price_curve,
  output_capacity_per_unit: 2449.0
))

# ... and export to Germany:
nl_again.add(export_user)

# And we're done!
nl_again.calculate

# ------------------------------------------------------------------------------

# We now output tables to compare how NL demand was affected in a particular
# point. This point (1040) was selected because it shows how NL demand increased
# as a result of export to Germany.

puts 'Before including export to Germany @ Feb 12, 08:00'
puts '--------------------------------------------------'
puts
puts Merit::PointTable.new(nl_order).table_for(1040)
puts

puts 'After including export to Germany @ Feb 12, 08:00'
puts '-------------------------------------------------'
puts
puts Merit::PointTable.new(nl_again).table_for(1040)
