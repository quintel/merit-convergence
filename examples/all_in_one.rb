require_relative '../lib/merit/convergence'

# Path to the directory containing data exported from ETEngine.
DATA_DIR     = Pathname.new(__FILE__).join('../../data').expand_path
PROFILES_DIR = Pathname.new(Merit.root)

DE_ARCHIVE = Merit::Convergence::Archive.new(
  DATA_DIR.join('de'),                   # Path to the DE data.
  PROFILES_DIR.join('load_profiles/de')  # Path to the DE load profiles.
)

NL_ARCHIVE = Merit::Convergence::Archive.new(
  DATA_DIR.join('nl'),                   # Path to the NL data.
  PROFILES_DIR.join('load_profiles/nl')  # Path to the NL load profiles.
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
time        = Time.at(1040 * 60 * 60).utc.strftime('%d %b @ %H:00')

puts "Before including export to Germany @ #{ time }"
puts "------------------------------------#{ '-' * time.length }"
puts
puts Merit::PointTable.new(runner.first_order).table_for(1040)
puts

# See what the German merit order looks like by uncommenting:
#
# puts "German Merit Order (not including import from NL) @ #{ time }"
# puts "-------------------------------------------------#{ '-' * time.length }"
# puts
# puts Merit::PointTable.new(runner.other_orders[:de]).table_for(1040)
# puts

puts "After including export to Germany @ #{ time }"
puts "------------------------------------#{ '-' * time.length }"
puts
puts Merit::PointTable.new(merit_order).table_for(1040)
