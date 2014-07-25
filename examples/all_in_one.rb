require_relative '../lib/merit/convergence'

# Path to the "load_profiles" directory. In this example, it is assumed that
# "merit-convergence" and "merit" have a common parent directory...
#
#   └ Projects/
#     ├ merit-convergence/
#     │ ├ data/
#     │ ├ examples/
#     │ └ ...
#     └ merit/
#       ├ ...
#       └ load_profiles/
#
PROFILES_DIR = Pathname.new(__FILE__)
  .join('../../../merit/load_profiles').expand_path

# Path to the directory containing data exported from ETEngine.
DATA_DIR = Pathname.new(__FILE__).join('../../data').expand_path

DE_ARCHIVE = Merit::Convergence::Archive.new(
  DATA_DIR.join('DE_2014-07-23_20-11-20'),  # Path to the DE data.
  PROFILES_DIR.join('de')                   # Path to the DE load profiles.
)

NL_ARCHIVE = Merit::Convergence::Archive.new(
  DATA_DIR.join('NL_2014-07-23_20-16-08'),  # Path to the NL data.
  PROFILES_DIR.join('nl')                   # Path to the NL load profiles.
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
# runner.add_export(:be, LoadCurve.new([1.0, 12.1, 11.0, ...]))

# Do the two-step run, and get the final merit order back.
merit_order = runner.run

puts 'Before including export to Germany (@ Feb 11, 18:00)'
puts '----------------------------------------------------'
puts
puts Merit::PointTable.new(runner.first_order).table_for(1002)
puts

puts 'After including export to Germany (@ Feb 11, 18:00)'
puts '---------------------------------------------------'
puts
puts Merit::PointTable.new(merit_order).table_for(1002)
