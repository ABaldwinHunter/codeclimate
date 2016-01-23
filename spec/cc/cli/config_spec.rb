require "spec_helper"
require "cc/cli/config"

module CC::CLI
  describe CC::CLI::Config do
    describe "#add_engine" do
      it "enables the passed in engine" do
        config = CC::CLI::Config.new()
        engine_config = {
          "default_ratings_paths" => ["foo"]
        }

        config.add_engine("foo", engine_config)

        engine = YAML.load(config.to_yaml)["engines"]["foo"]
        engine.must_equal({ "enabled" => true })
      end

      it "copies over default configuration" do
        config = CC::CLI::Config.new()
        engine_config = {
          "default_config" => { "awesome" => true },
          "default_ratings_paths" => ["foo"]
        }

        config.add_engine("foo", engine_config)

        engine = YAML.load(config.to_yaml)["engines"]["foo"]
        engine.must_equal({
          "enabled" => true,
          "config" => {
            "awesome" => true
          }
        })
      end
    end

    describe "#add_exclude_paths" do
      it "adds paths" do
        config = CC::CLI::Config.new()
        config.add_exclude_paths(["foo/", "foo.rb"])

        exclude_paths = YAML.load(config.to_yaml)["exclude_paths"]
        exclude_paths.must_equal(["foo/", "foo.rb"])
      end
    end
  end
end
