# frozen_string_literal: true

require "spec_helper"
require "hip/env_file_loader"
require "tmpdir"

RSpec.describe Hip::EnvFileLoader do
  let(:tmpdir) { Dir.mktmpdir }
  let(:base_path) { Pathname.new(tmpdir) }

  after do
    FileUtils.rm_rf(tmpdir) if tmpdir && File.exist?(tmpdir)
  end

  describe ".load" do
    context "with a single env file" do
      let(:env_content) do
        <<~ENV
          # Comment line
          DATABASE_HOST=localhost
          DATABASE_PORT=5432
          DATABASE_NAME=myapp_development
          EMPTY_VALUE=
        ENV
      end

      before do
        File.write(base_path.join(".env"), env_content)
      end

      it "loads environment variables from the file" do
        result = described_class.load(".env", base_path: base_path)

        expect(result).to eq(
          "DATABASE_HOST" => "localhost",
          "DATABASE_PORT" => "5432",
          "DATABASE_NAME" => "myapp_development",
          "EMPTY_VALUE" => ""
        )
      end

      it "skips comments and empty lines" do
        result = described_class.load(".env", base_path: base_path)
        expect(result.keys).not_to include("#")
      end
    end

    context "with multiple env files" do
      before do
        File.write(base_path.join(".env.defaults"), <<~ENV)
          BASE=1
          LOG_LEVEL=warn
        ENV

        File.write(base_path.join(".env"), <<~ENV)
          BASE=2
          SECRET=secret123
        ENV

        File.write(base_path.join(".env.local"), <<~ENV)
          LOG_LEVEL=debug
          ENABLE_CACHE=false
        ENV
      end

      it "merges multiple files with later files overriding earlier" do
        result = described_class.load(
          [".env.defaults", ".env", ".env.local"],
          base_path: base_path
        )

        expect(result).to eq(
          "BASE" => "2",
          "LOG_LEVEL" => "debug",
          "SECRET" => "secret123",
          "ENABLE_CACHE" => "false"
        )
      end
    end

    context "with quoted values" do
      before do
        File.write(base_path.join(".env"), <<~ENV)
          SINGLE_QUOTED='single value'
          DOUBLE_QUOTED="double value"
          WITH_SPACES="value with spaces"
          UNQUOTED=plain_value
        ENV
      end

      it "handles quoted and unquoted values correctly" do
        result = described_class.load(".env", base_path: base_path)

        expect(result).to eq(
          "SINGLE_QUOTED" => "single value",
          "DOUBLE_QUOTED" => "double value",
          "WITH_SPACES" => "value with spaces",
          "UNQUOTED" => "plain_value"
        )
      end
    end

    context "with variable interpolation" do
      before do
        File.write(base_path.join(".env"), <<~ENV)
          DATABASE_HOST=localhost
          DATABASE_PORT=5432
          DATABASE_USER=postgres
          DATABASE_NAME=myapp_dev
          DATABASE_URL=postgres://${DATABASE_USER}@${DATABASE_HOST}:${DATABASE_PORT}/${DATABASE_NAME}
        ENV
      end

      it "interpolates variables when enabled" do
        result = described_class.load(".env", base_path: base_path, interpolate: true)

        expect(result["DATABASE_URL"]).to eq(
          "postgres://postgres@localhost:5432/myapp_dev"
        )
      end

      it "does not interpolate when disabled" do
        result = described_class.load(".env", base_path: base_path, interpolate: false)

        expect(result["DATABASE_URL"]).to eq(
          "postgres://${DATABASE_USER}@${DATABASE_HOST}:${DATABASE_PORT}/${DATABASE_NAME}"
        )
      end
    end

    context "with missing files" do
      context "when required: false" do
        it "skips missing files without error" do
          expect do
            result = described_class.load(
              [{path: ".env.missing", required: false}],
              base_path: base_path
            )
            expect(result).to eq({})
          end.not_to raise_error
        end
      end

      context "when required: true" do
        it "raises error for missing file" do
          expect do
            described_class.load(
              [{path: ".env.required", required: true}],
              base_path: base_path
            )
          end.to raise_error(Hip::Error, /Required environment file not found/)
        end
      end
    end

    context "with hash config" do
      before do
        File.write(base_path.join(".env"), "KEY=value")
      end

      it "handles hash config with files key" do
        result = described_class.load(
          {files: ".env", required: false},
          base_path: base_path
        )

        expect(result).to eq("KEY" => "value")
      end

      it "handles hash config with array of files" do
        File.write(base_path.join(".env.local"), "KEY2=value2")

        result = described_class.load(
          {files: [".env", ".env.local"]},
          base_path: base_path
        )

        expect(result).to eq("KEY" => "value", "KEY2" => "value2")
      end
    end

    context "with escape sequences in double quotes" do
      before do
        File.write(base_path.join(".env"), 'WITH_NEWLINE="line1\nline2"' + "\n" \
                                            'WITH_TAB="col1\tcol2"' + "\n" \
                                            'WITH_QUOTE="say \"hello\""' + "\n")
      end

      it "unescapes sequences in double quotes" do
        result = described_class.load(".env", base_path: base_path)

        expect(result["WITH_NEWLINE"]).to eq("line1\nline2")
        expect(result["WITH_TAB"]).to eq("col1\tcol2")
        expect(result["WITH_QUOTE"]).to eq('say "hello"')
      end
    end

    context "with export prefix" do
      before do
        File.write(base_path.join(".env"), <<~ENV)
          export KEY1=value1
          KEY2=value2
          export KEY3=value3
        ENV
      end

      it "ignores export prefix" do
        result = described_class.load(".env", base_path: base_path)

        expect(result).to eq(
          "KEY1" => "value1",
          "KEY2" => "value2",
          "KEY3" => "value3"
        )
      end
    end

    context "with absolute path" do
      let(:absolute_path) { File.join(tmpdir, "absolute", ".env") }

      before do
        FileUtils.mkdir_p(File.dirname(absolute_path))
        File.write(absolute_path, "KEY=value")
      end

      it "resolves absolute paths correctly" do
        result = described_class.load(absolute_path, base_path: base_path)

        expect(result).to eq("KEY" => "value")
      end
    end

    context "with circular variable references" do
      before do
        File.write(base_path.join(".env"), <<~ENV)
          VAR1=$VAR2
          VAR2=$VAR1
        ENV
      end

      it "handles circular references without infinite loop" do
        expect do
          result = described_class.load(".env", base_path: base_path, interpolate: true)
          expect(result).to be_a(Hash)
        end.not_to raise_error
      end
    end
  end

  describe ".parse_line" do
    it "parses simple KEY=value" do
      key, value = described_class.send(:parse_line, "DATABASE_HOST=localhost")
      expect(key).to eq("DATABASE_HOST")
      expect(value).to eq("localhost")
    end

    it "returns nil for invalid lines" do
      key, value = described_class.send(:parse_line, "invalid line")
      expect(key).to be_nil
      expect(value).to be_nil
    end

    it "handles empty value" do
      key, value = described_class.send(:parse_line, "EMPTY_KEY=")
      expect(key).to eq("EMPTY_KEY")
      expect(value).to eq("")
    end
  end

  describe ".unquote" do
    it "removes single quotes" do
      result = described_class.send(:unquote, "'value'")
      expect(result).to eq("value")
    end

    it "removes double quotes" do
      result = described_class.send(:unquote, '"value"')
      expect(result).to eq("value")
    end

    it "leaves unquoted values as-is" do
      result = described_class.send(:unquote, "value")
      expect(result).to eq("value")
    end
  end
end
