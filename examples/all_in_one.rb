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

# ------------------------------------------------------------------------------

# Create a Runner with data for the local country.
runner = Merit::Convergence::Runner.new(NL_ARCHIVE)

# Add an interconnect with a foreign nation. Import and export loads will be
# calculated depending on the price of each region.
runner.add_interconnect(DE_ARCHIVE, 2449.0)

# Presently the Runner supports only one "real" interconnect. For the moment,
# you may add export loads to other nations if you have those in a Curve.
#
# runner.add_export(:be, Merit::Curve.load_file('/path/to/file'))

# Do the two-step run, and get the final merit order back.
merit_order = runner.run
hour        = 1040
time        = Time.at(hour * 60 * 60).utc.strftime('%d %b @ %H:00')

puts "Before including export to Germany @ #{ time }"
puts "------------------------------------#{ '-' * time.length }"
puts
puts Merit::PointTable.new(runner.first_order).table_for(hour)
puts

# See what the German merit order looks like by uncommenting:
#
# puts "German Merit Order (not including import from NL) @ #{ time }"
# puts "-------------------------------------------------#{ '-' * time.length }"
# puts
# puts Merit::PointTable.new(runner.other_orders[:de]).table_for(hour)
# puts

puts "After including export to Germany @ #{ time }"
puts "------------------------------------#{ '-' * time.length }"
puts
puts Merit::PointTable.new(merit_order).table_for(hour)

# Get the price curve for NL:
#
# merit_order.price_curve

# Get the price curve for DE (the "runner" object which is responsible for
# calculating NL twice to account for import/export retains a copy of the
# calculated DE merit order):
#
# runner.other_orders[:de].price_curve

# Produce a Curve which combines import and export to Germany. Exports are
# positive numbers, imports are negative:
#
# runner.interconnect_flow(:de)
