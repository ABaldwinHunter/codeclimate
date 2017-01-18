require "spec_helper"

module CC::CLI
  describe Runner do
    before do
      versions_resp = { version: "0.4.1" }
      resp = double(code: "200", body: versions_resp.to_json)
      stub_resp("versions.codeclimate.com", "255.255.255.255", resp)
    end

    describe ".run" do
      it "rescues exceptions and prints a friendlier message" do
        Explode = Class.new(Command) do
          def run
            raise StandardError, "boom"
          end
        end

        _, stderr = capture_io do
          Runner.run(["explode"])
        end

        expect(stderr).to match(/error: \(StandardError\) boom/)
      end
    end

    describe "#command_name" do
      it "parses subclasses" do
        expect(Runner.new(["analyze:this"]).command_name).to eq("Analyze::This")
      end

      it "returns class names" do
        expect(Runner.new(["analyze"]).command_name).to eq("Analyze")
      end
    end
  end
end
