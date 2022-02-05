# frozen_string_literal: true
# frozen_string_literal: true

module ERBLint
  # Defines common functionality available to all linters.
  class Linter
    class << self
      attr_accessor :simple_name
      attr_accessor :config_schema

      # When defining a Linter class, define its simple name as well. This
      # assumes that the module hierarchy of every linter starts with
      # `ERBLint::Linters::`, and removes this part of the class name.
      #
      # `ERBLint::Linters::Foo.simple_name`          #=> "Foo"
      # `ERBLint::Linters::Compass::Bar.simple_name` #=> "Compass::Bar"
      def inherited(linter)
        super
        linter.simple_name = if linter.name.start_with?("ERBLint::Linters::")
          name_parts = linter.name.split("::")
          name_parts[2..-1].join("::")
        else
          linter.name
        end

        linter.config_schema = LinterConfig
      end

      def support_autocorrect?
        method_defined?(:autocorrect)
      end
    end

    attr_reader :offenses, :config

    # Must be implemented by the concrete inheriting class.
    def initialize(file_loader, config)
      @file_loader = file_loader
      @config = config
      raise ArgumentError, "expect `config` to be #{self.class.config_schema} instance, "\
        "not #{config.class}" unless config.is_a?(self.class.config_schema)
      @offenses = []
    end

    def enabled?
      @config.enabled?
    end

    def excludes_file?(filename)
      @config.excludes_file?(filename, @file_loader.base_path)
    end

    def run(_processed_source)
      raise NotImplementedError, "must implement ##{__method__}"
    end

    def set_offense_status(processed_source)
      @offenses = @offenses.each do |offense|
        offending_line_ranges = offense.source_range.line_range
        offending_lines =  processed_source.source_buffer.source_lines[offending_line_ranges.first - 1..offending_line_ranges.last - 1].join
        previous_line = processed_source.source_buffer.source_lines[offense.source_range.line_range.first - 2]
        if offending_lines.match(/<%# erblint:disable #{offense.linter.class.simple_name} %>/) || previous_line.match(/<%# erblint:disable #{offense.linter.class.simple_name} %>/)
          offense.disabled = true
        end
      end
    end

    def run_and_set_offense_status(_processed_source)
      run(_processed_source)
      set_offense_status(_processed_source) if @offenses.any?
    end

    def add_offense(source_range, message, context = nil, severity = nil)
      @offenses << Offense.new(self, source_range, message, context, severity)
    end

    def clear_offenses
      @offenses = []
    end
  end
end
